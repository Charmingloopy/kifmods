#===============================================================================
# KIF: Elite Redux – battlers
#   * Each battler gets its innates when its Pokémon is set up.
#   * hasActiveAbility? is also true for an active innate. KIF's 3-argument
#     form (ability, ignore_fainted, mold_broken) is kept.
#   * Innates are off while the battler's ability is off (Gastro Acid,
#     fainted), the same as its main ability.
#   * abilityName names the innate while one is working, so its splash and
#     messages show the innate's name.
#===============================================================================
class PokeBattle_Battler
  attr_reader :innate_ids

  alias kifer_pbInitPokemon pbInitPokemon unless method_defined?(:kifer_pbInitPokemon)
  def pbInitPokemon(pkmn, idxParty)
    kifer_pbInitPokemon(pkmn, idxParty)
    @kifer_inline = nil
    @kifer_entry_done = nil   # innates whose switch-in effect already ran (004)
    begin
      @innate_ids = KIFER.battle_innates(pkmn)
    rescue StandardError => e
      @innate_ids = []
      KIFER.log("battler innates failed: #{e.class}: #{e.message}")
    end
  end

  # Innates that count right now. A copy of the main ability or of another
  # innate counts too: copies stack (Cody, 2026-10-13).
  INNATES_NONE = [].freeze

  def active_innates
    ids = @innate_ids
    return INNATES_NONE if !ids.is_a?(Array) || ids.empty?
    return KIFER.unsuppressed(self, ids)
  end

  alias kifer_hasActiveAbility? hasActiveAbility? unless method_defined?(:kifer_hasActiveAbility?)
  def hasActiveAbility?(check_ability, ignore_fainted = false, mold_broken = false)
    if kifer_hasActiveAbility?(check_ability, ignore_fainted, mold_broken)
      @kifer_inline = nil
      return true
    end
    return false if mold_broken
    hit = KIFER.innate_match(self, check_ability, ignore_fainted)
    if hit.nil?
      # an ability that contains the asked one counts too (Big Leaves for
      # Chlorophyll, Imposing Wings for Levitate...): KIFER.counts_as
      alt = KIFER.wholes_of(check_ability)
      return false if alt.nil?
      return true if kifer_hasActiveAbility?(alt, ignore_fainted, mold_broken)
      hit = KIFER.innate_match(self, alt, ignore_fainted)
    end
    @kifer_inline = hit if hit
    return !hit.nil?
  end

  alias kifer_abilityName abilityName unless method_defined?(:kifer_abilityName)
  def abilityName
    id = KIFER.shown_innate(self)
    if id
      a = GameData::Ability.try_get(id)
      return a.name if a
    end
    return kifer_abilityName
  end

  def kifer_clear_inline
    @kifer_inline = nil
  end

  def kifer_inline
    return @kifer_inline
  end

  # A new main ability (Mummy, Skill Swap, Role Play...): an innate named by an
  # earlier inline check mustn't name it
  alias kifer_set_battler_ability ability= unless method_defined?(:kifer_set_battler_ability)
  def ability=(value)
    kifer_set_battler_ability(value)
    @kifer_inline = nil
  end

  # PIF's hasWorkingAbility (used by DemICE's AI) is a copy of the original
  # hasActiveAbility?, made before any wrapper; send it through the current one
  def hasWorkingAbility(*args)
    return hasActiveAbility?(*args)
  end
end

module KIFER
  #-----------------------------------------------------------------------------
  # "Counts as": hasActiveAbility?(:PART) is also true for an ability that
  # contains PART (the ER abilities written "A + B"). One table, followed
  # through (a part of a part counts), checked only when the plain check fails.
  #-----------------------------------------------------------------------------
  @part_of = {}
  @wholes = nil

  def self.counts_as(part, *wholes)
    @part_of[part] = (@part_of[part] || []) | wholes
    @wholes = nil
  end

  def self.wholes_of(check)
    t = (@wholes ||= build_wholes)
    return t[check] if check.is_a?(Symbol)
    return t[ability_id(check)] if !check.is_a?(Array)
    ids = nil
    check.each { |c| w = t[ability_id(c)]; (ids ||= []).concat(w) if w }
    return ids
  end

  def self.build_wholes
    t = {}
    @part_of.each_key do |part|
      seen = @part_of[part].dup
      i = 0
      while i < seen.length
        (@part_of[seen[i]] || []).each { |w| seen << w unless seen.include?(w) || w == part }
        i += 1
      end
      t[part] = seen.freeze
    end
    return t.freeze
  end

  @context  = []    # [battler, innate id or nil] while a handler runs
  @suppress = nil   # damage log dry runs: :all, or [battler, innate id]

  def self.suppress(value)
    old = @suppress
    @suppress = value
    begin
      return yield
    ensure
      @suppress = old
    end
  end

  def self.unsuppressed(battler, list)
    return list if @suppress.nil?
    return [] if @suppress == :all
    return list if !@suppress[0].equal?(battler)
    return list.reject { |a| a == @suppress[1] }
  end

  # The innate that matches check_ability, or nil
  def self.innate_match(battler, check_ability, ignore_fainted)
    inn = battler.active_innates
    return nil if inn.empty?
    return nil if !battler.abilityActive?(ignore_fainted)
    if check_ability.is_a?(Array)
      check_ability.each do |a|
        id = KIFER.ability_id(a)
        return id if inn.include?(id)
      end
      return nil
    end
    id = KIFER.ability_id(check_ability)
    return inn.include?(id) ? id : nil
  rescue StandardError => e
    log("innate_match failed: #{e.class}: #{e.message}")
    return nil
  end

  # Runs the block with "battler is using innate id" (nil = its main ability)
  def self.with_context(battler, id)
    @context.push([battler, id])
    battler.kifer_clear_inline if battler.respond_to?(:kifer_clear_inline)
    begin
      return yield
    ensure
      @context.pop
    end
  end

  # The innate to name for this battler right now, or nil
  def self.shown_innate(battler)
    @context.reverse_each do |b, id|
      return id if b.equal?(battler)
    end
    return battler.kifer_inline
  rescue StandardError
    return nil
  end
end

class PokeBattle_Battle
  # Name the right ability on the splash (an earlier innate name could stay on
  # the bar otherwise, since the bar keeps the last name it was given)
  alias kifer_pbShowAbilitySplash pbShowAbilitySplash unless method_defined?(:kifer_pbShowAbilitySplash)
  def pbShowAbilitySplash(battler, delay = false, logTrigger = true, abilityName = nil)
    abilityName = battler.abilityName if abilityName.nil? && battler && battler.respond_to?(:innate_ids) &&
                                         battler.innate_ids.is_a?(Array) && !battler.innate_ids.empty?
    kifer_pbShowAbilitySplash(battler, delay, logTrigger, abilityName)
  end

  alias kifer_pbHideAbilitySplash pbHideAbilitySplash unless method_defined?(:kifer_pbHideAbilitySplash)
  def pbHideAbilitySplash(battler)
    kifer_pbHideAbilitySplash(battler)
    battler.kifer_clear_inline if battler.respond_to?(:kifer_clear_inline)
  end
end
