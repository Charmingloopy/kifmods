#===============================================================================
# KIF: Elite Redux – places where the game checks a Pokémon's ability directly
#   Battles mostly ask hasActiveAbility? or run a handler, and those already
#   see innates (003, 004). The places below compare the ability itself, so
#   without this file an innate (or a dual fusion's 2nd choice) does nothing
#   there. The main ability always goes first; an innate that is the same as
#   the main ability adds nothing, since none of these effects stack.
#
#   Out of battle (lead Pokémon or party):
#     - Pokemon#hasAbility? counts innates: Pickup, Honey Gather, Flame Body /
#       Magma Armor egg hatching, Compound Eyes held items, Cute Charm,
#       Synchronize, Immunity vs field poison (KIF's walking poison options:
#       Poison Heal / Magic Guard too). Not Battle Bond, Multitype or RKS
#       System: those are about the species' own form (evolution, plates).
#     - Wild encounter rate (Stench, White Smoke, Quick Feet, Snow Cloak in
#       hail, Sand Veil in sandstorm, Swarm, Illuminate, Arena Trap, No Guard),
#       Intimidate / Keen Eye skipping weak wild Pokémon, Static / Magnet Pull
#       types, Hustle / Pressure / Vital Spirit wild levels, Sticky Hold /
#       Suction Cups fishing. These read the ability once per check, so one
#       ability counts at each check: the main one if it has an effect there,
#       otherwise the first innate that does.
#     - Shields Down: Minior out of battle goes back to Meteor form.
#   In battle:
#     - Stance Change (Aegislash), Disguise (Mimikyu), Shields Down (Minior):
#       PIF checks the battler's ability itself; an innate works the same way.
#     - Illusion: the "Go! ..." message names the disguise for an innate too.
#     - KIF's move effectiveness hints: an immunity shown by an innate's
#       pop-up (Volt Absorb, Levitate...) counts, and an innate's pop-up no
#       longer reveals the main ability.
#   Nothing changes while Innates is off.
#===============================================================================
module KIFER
  module AbilitySites
    # Pokemon#hasAbility? leaves these to the main ability (species forms)
    HAS_EXCLUDED = [:BATTLEBOND, :MULTITYPE, :RKSSYSTEM].freeze

    ENCOUNTER_RATE = [:STENCH, :WHITESMOKE, :QUICKFEET, :SNOWCLOAK, :SANDVEIL,
                      :SWARM, :ILLUMINATE, :ARENATRAP, :NOGUARD].freeze
    ENCOUNTER_SKIP = [:INTIMIDATE, :KEENEYE].freeze
    TYPE_PULL      = [:STATIC, :MAGNETPULL].freeze
    MAX_LEVEL      = [:HUSTLE, :PRESSURE, :VITALSPIRIT].freeze
    FISHING        = [:STICKYHOLD, :SUCTIONCUPS].freeze

    # [pokemon, values, sticky]: while set, that Pokémon's ability_id gives
    # these values (sticky: always values[0]; else one per call, then its own)
    @ov = nil

    # Abilities a Pokémon has besides its main one (innates the game has,
    # plus a dual fusion's 2nd choice). [] while Innates is off.
    def self.extras(pkmn)
      return [] if pkmn.nil? || !KIFER.enabled?
      return [] if pkmn.respond_to?(:egg?) && pkmn.egg?
      return KIFER.battle_innates(pkmn).uniq
    rescue StandardError => e
      KIFER.log("ability sites: innates failed: #{e.class}: #{e.message}")
      return []
    end

    def self.has?(pkmn, id)
      return false if pkmn.nil?
      return true if pkmn.ability_id == id
      return extras(pkmn).include?(id)
    end

    # The innate that should act at a check reading one ability from `list`
    # (nil: the main ability acts, or nothing does). `ok` filters further.
    def self.pick(pkmn, list, ok = nil)
      return nil if pkmn.nil? || @ov
      ex = extras(pkmn)
      return nil if ex.empty?
      main = pkmn.ability_id
      return nil if list.include?(main) && (ok.nil? || ok.call(main))
      return ex.find { |a| a != main && list.include?(a) && (ok.nil? || ok.call(a)) }
    rescue StandardError => e
      KIFER.log("ability sites: pick failed: #{e.class}: #{e.message}")
      return nil
    end

    # ability_id of pkmn is `id` for the whole block
    def self.as_ability(pkmn, id)
      return yield if pkmn.nil? || id.nil?
      old = @ov
      @ov = [pkmn, [id], true]
      begin
        return yield
      ensure
        @ov = old
      end
    end

    # The next reads of pkmn's ability_id give `values` in turn, then its own
    def self.as_sequence(pkmn, values)
      return yield if pkmn.nil? || values.nil? || values.empty?
      old = @ov
      @ov = [pkmn, values.dup, false]
      begin
        return yield
      ensure
        @ov = old
      end
    end

    def self.override_for(pkmn)
      ov = @ov
      return nil if ov.nil? || !ov[0].equal?(pkmn)
      return ov[1][0] if ov[2]
      return ov[1].shift
    end

    def self.active?
      return !@ov.nil?
    end

    # Pokemon#hasAbility? for one of its innates: the same check (with
    # anything other mods add to it) as if that innate were its ability
    def self.innate_has?(pkmn, check)
      id = KIFER.ability_id(check)
      return false if HAS_EXCLUDED.include?(id)
      return false if @ov && @ov[0].equal?(pkmn)   # already answering for it
      ex = extras(pkmn)
      return false if ex.empty?
      main = pkmn.ability_id
      ex.each do |a|
        next if a == main
        return true if as_ability(pkmn, a) { pkmn.kifer_as_hasAbility?(check) }
      end
      return false
    end

    def self.weather_category
      return GameData::Weather.get($game_screen.weather_type).category
    rescue StandardError
      return nil
    end

    # Snow Cloak / Sand Veil only change the rate in their weather
    RATE_OK = proc do |a|
      case a
      when :SNOWCLOAK then KIFER::AbilitySites.weather_category == :Hail
      when :SANDVEIL  then KIFER::AbilitySites.weather_category == :Sandstorm
      else true
      end
    end

    #---------------------------------------------------------------------------
    # Battle helpers
    #---------------------------------------------------------------------------
    # The battler's innate `id` is on (and isn't its main ability). Used for
    # the form abilities, which Gastro Acid can't stop.
    def self.battler_innate?(battler, id)
      return false if !battler.respond_to?(:active_innates)
      return false if battler.ability_id == id
      return battler.active_innates.include?(id)
    rescue StandardError
      return false
    end

    # hasActiveAbility? without naming the innate on the next pop-up
    def self.active_now?(battler, id)
      return false if !battler.abilityActive?
      return true if battler.ability_id == id
      return battler.respond_to?(:active_innates) && battler.active_innates.include?(id)
    end

    # KIF's effectiveness hints: innates the battle has shown, per Pokémon
    def self.shown_innates(battle, battler)
      known = battle.instance_variable_get(:@kifer_as_known)
      return [] if !known || !battler || !battler.pokemon
      return known[battler.pokemon.object_id] || []
    end

    def self.splash_innate(battler)
      return nil if !battler || !battler.respond_to?(:innate_ids) || !battler.pokemon
      ids = battler.innate_ids
      return nil if !ids.is_a?(Array) || ids.empty?
      id = KIFER.shown_innate(battler)
      return nil if id.nil? || id == battler.ability_id
      return id
    rescue StandardError
      return nil
    end
  end
end

#===============================================================================
# Pokémon
#===============================================================================
class Pokemon
  alias kifer_as_ability_id ability_id unless method_defined?(:kifer_as_ability_id)
  def ability_id
    if KIFER::AbilitySites.active?
      v = KIFER::AbilitySites.override_for(self)
      return v if v
    end
    return kifer_as_ability_id
  end

  alias kifer_as_hasAbility? hasAbility? unless method_defined?(:kifer_as_hasAbility?)
  def hasAbility?(check_ability = nil)
    return true if kifer_as_hasAbility?(check_ability)
    return false if check_ability.nil? || !KIFER.enabled?
    return KIFER::AbilitySites.innate_has?(self, check_ability)
  end

  # Shields Down out of battle reads the stored ability (@ability)
  alias kifer_as_checkHPRelatedFormChange checkHPRelatedFormChange unless method_defined?(:kifer_as_checkHPRelatedFormChange)
  def checkHPRelatedFormChange(*args)
    swap = false
    if @ability != :SHIELDSDOWN && KIFER.enabled?
      swap = KIFER::AbilitySites.extras(self).include?(:SHIELDSDOWN)
    end
    return kifer_as_checkHPRelatedFormChange(*args) if !swap
    old = @ability
    @ability = :SHIELDSDOWN
    begin
      return kifer_as_checkHPRelatedFormChange(*args)
    ensure
      @ability = old if @ability == :SHIELDSDOWN
    end
  end
end

#===============================================================================
# Wild encounters and fishing (lead Pokémon)
#===============================================================================
class PokemonEncounters
  alias kifer_as_encounter_triggered? encounter_triggered? unless method_defined?(:kifer_as_encounter_triggered?)
  def encounter_triggered?(*args)
    lead = ($Trainer.first_pokemon rescue nil)
    a = KIFER::AbilitySites.pick(lead, KIFER::AbilitySites::ENCOUNTER_RATE, KIFER::AbilitySites::RATE_OK)
    return kifer_as_encounter_triggered?(*args) if !a
    return KIFER::AbilitySites.as_sequence(lead, [a]) { kifer_as_encounter_triggered?(*args) }
  end

  alias kifer_as_allow_encounter? allow_encounter? unless method_defined?(:kifer_as_allow_encounter?)
  def allow_encounter?(*args)
    lead = ($Trainer.first_pokemon rescue nil)
    a = KIFER::AbilitySites.pick(lead, KIFER::AbilitySites::ENCOUNTER_SKIP)
    return kifer_as_allow_encounter?(*args) if !a
    return KIFER::AbilitySites.as_sequence(lead, [a]) { kifer_as_allow_encounter?(*args) }
  end

  # Two reads: Static / Magnet Pull first, then Hustle / Pressure / Vital Spirit
  alias kifer_as_choose_wild_pokemon choose_wild_pokemon unless method_defined?(:kifer_as_choose_wild_pokemon)
  def choose_wild_pokemon(*args)
    lead = ($Trainer.first_pokemon rescue nil)
    pull  = KIFER::AbilitySites.pick(lead, KIFER::AbilitySites::TYPE_PULL)
    level = KIFER::AbilitySites.pick(lead, KIFER::AbilitySites::MAX_LEVEL)
    return kifer_as_choose_wild_pokemon(*args) if !pull && !level
    main = lead.ability_id
    return KIFER::AbilitySites.as_sequence(lead, [pull || main, level || main]) do
      kifer_as_choose_wild_pokemon(*args)
    end
  end
end

# Fishing: one read, before the rod is cast
unless Object.private_method_defined?(:kifer_as_pbFishing) || Object.method_defined?(:kifer_as_pbFishing)
  alias kifer_as_pbFishing pbFishing
end

def pbFishing(*args)
  lead = ($Trainer.first_pokemon rescue nil)
  a = KIFER::AbilitySites.pick(lead, KIFER::AbilitySites::FISHING)
  return kifer_as_pbFishing(*args) if !a
  return KIFER::AbilitySites.as_sequence(lead, [a]) { kifer_as_pbFishing(*args) }
end

#===============================================================================
# Battle
#===============================================================================
class PokeBattle_Battler
  # Shields Down (Minior): PIF checks @ability_id when HP changes
  alias kifer_as_checkHPRelatedFormChange checkHPRelatedFormChange unless method_defined?(:kifer_as_checkHPRelatedFormChange)
  def checkHPRelatedFormChange(*args)
    ids = @innate_ids
    if @ability_id == :SHIELDSDOWN || !ids.is_a?(Array) || !ids.include?(:SHIELDSDOWN) ||
       !KIFER::AbilitySites.battler_innate?(self, :SHIELDSDOWN)
      return kifer_as_checkHPRelatedFormChange(*args)
    end
    old = @ability_id
    @ability_id = :SHIELDSDOWN
    begin
      return kifer_as_checkHPRelatedFormChange(*args)
    ensure
      @ability_id = old if @ability_id == :SHIELDSDOWN
    end
  end

  # Stance Change (Aegislash): PIF's pbUseMove (and KIF's copy of it) checks
  # self.ability right after paying PP and then works out the move's type.
  # For an innate, the change happens at that same type check.
  alias kifer_as_pbUseMove pbUseMove unless method_defined?(:kifer_as_pbUseMove)
  def pbUseMove(choice, *args)
    old = @kifer_as_stance
    @kifer_as_stance = KIFER::AbilitySites.battler_innate?(self, :STANCECHANGE) ? choice : nil
    begin
      return kifer_as_pbUseMove(choice, *args)
    ensure
      @kifer_as_stance = old
    end
  end

  def kifer_as_stance_check(move)
    ch = @kifer_as_stance
    return if !ch.is_a?(Array) || !ch[2].equal?(move)
    @kifer_as_stance = nil
    if move.damagingMove?
      stanceChangeEffect(pbFindUser(ch, move), true)
    elsif move.id == :KINGSSHIELD
      stanceChangeEffect(pbFindUser(ch, move), false)
    end
  end
end

class PokeBattle_Move
  alias kifer_as_pbCalcType pbCalcType unless method_defined?(:kifer_as_pbCalcType)
  def pbCalcType(user)
    if user.is_a?(PokeBattle_Battler) && user.instance_variable_get(:@kifer_as_stance)
      user.kifer_as_stance_check(self)
    end
    return kifer_as_pbCalcType(user)
  end

  # Disguise (Mimikyu): PIF checks target.ability
  alias kifer_as_pbCheckDamageAbsorption pbCheckDamageAbsorption unless method_defined?(:kifer_as_pbCheckDamageAbsorption)
  def pbCheckDamageAbsorption(user, target)
    target.instance_variable_set(:@kifer_as_disguise, false) if target
    ret = kifer_as_pbCheckDamageAbsorption(user, target)
    ds = target && target.damageState
    if ds && !ds.substitute && !ds.disguise && !@battle.moldBreaker &&
       target.isFusionOf(:MIMIKYU) && target.form == 0 &&
       KIFER::AbilitySites.battler_innate?(target, :DISGUISE)
      ds.disguise = true
      target.instance_variable_set(:@kifer_as_disguise, true)
    end
    return ret
  end

  # ...and its pop-up names Disguise
  alias kifer_as_pbEndureKOMessage pbEndureKOMessage unless method_defined?(:kifer_as_pbEndureKOMessage)
  def pbEndureKOMessage(target)
    if target && target.instance_variable_get(:@kifer_as_disguise) && target.damageState.disguise
      target.instance_variable_set(:@kifer_as_disguise, false)
      return KIFER.with_context(target, :DISGUISE) { kifer_as_pbEndureKOMessage(target) }
    end
    return kifer_as_pbEndureKOMessage(target)
  end
end

class PokeBattle_Battle
  # Illusion: the "Go! ..." message for the Pokémon being sent out
  alias kifer_as_pbMessagesOnReplace pbMessagesOnReplace unless method_defined?(:kifer_as_pbMessagesOnReplace)
  def pbMessagesOnReplace(idxBattler, idxParty)
    pkmn = (pbParty(idxBattler)[idxParty] rescue nil)
    a = KIFER::AbilitySites.pick(pkmn, [:ILLUSION])
    return kifer_as_pbMessagesOnReplace(idxBattler, idxParty) if !a
    return KIFER::AbilitySites.as_sequence(pkmn, [a]) { kifer_as_pbMessagesOnReplace(idxBattler, idxParty) }
  end

  # KIF's effectiveness hints remember the ability a pop-up shows. An
  # innate's pop-up is remembered as that innate, not the main ability.
  alias kifer_as_pbShowAbilitySplash pbShowAbilitySplash unless method_defined?(:kifer_as_pbShowAbilitySplash)
  def pbShowAbilitySplash(battler, *args)
    shown = KIFER::AbilitySites.splash_innate(battler)
    return kifer_as_pbShowAbilitySplash(battler, *args) if !shown
    key = battler.pokemon.object_id
    known = @cody_known_abilities
    had = known.is_a?(Hash) && known.key?(key)
    old = had ? known[key] : nil
    ret = kifer_as_pbShowAbilitySplash(battler, *args)
    begin
      known = @cody_known_abilities
      if known.is_a?(Hash)
        if had
          known[key] = old
        else
          known.delete(key)
        end
      end
      @kifer_as_known ||= {}
      list = (@kifer_as_known[key] ||= [])
      list << shown if !list.include?(shown)
    rescue StandardError => e
      KIFER.log("ability sites: splash note failed: #{e.class}: #{e.message}")
    end
    return ret
  end
end

if defined?(KIF::MoveEffect) && KIF::MoveEffect.respond_to?(:revealed?) &&
   KIF::MoveEffect.respond_to?(:known_immunity?)
  class << KIF::MoveEffect
    alias kifer_as_revealed? revealed? unless method_defined?(:kifer_as_revealed?)
    def revealed?(battle, target, ability)
      return true if kifer_as_revealed?(battle, target, ability)
      return false if !KIFER.enabled?
      return KIFER::AbilitySites.shown_innates(battle, target).include?(ability) &&
             KIFER::AbilitySites.active_now?(target, ability)
    end

    alias kifer_as_known_immunity? known_immunity? unless method_defined?(:kifer_as_known_immunity?)
    def known_immunity?(move, type, user, target, val)
      return true if kifer_as_known_immunity?(move, type, user, target, val)
      return false if !KIFER.enabled? || ::Effectiveness.ineffective?(val) || user.hasMoldBreaker?
      KIFER::AbilitySites.shown_innates(target.battle, target).each do |ab|
        next if !KIFER::AbilitySites.active_now?(target, ab)
        return true if self::TYPE_IMMUNE[ab] == type
        return true if ab == :SOUNDPROOF && move.soundMove?
        return true if ab == :BULLETPROOF && move.bombMove?
        return true if ab == :WONDERGUARD && !::Effectiveness.super_effective?(val)
      end
      return false
    end
  end
end
