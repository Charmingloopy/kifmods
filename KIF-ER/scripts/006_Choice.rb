#===============================================================================
# KIF: Elite Redux – choice abilities
#   Each species has 3 ER choice abilities; a fusion picks from its head's 3
#   plus its body's 3. The Pokémon's ability is the picked one.
#   Starting pick = PIF's own pick (Cody, 2026-10-13):
#     non-fusion: PIF ability slot 1 / 2 / hidden -> ER choice 1 / 2 / 3
#     fusion:     slot 1 (PIF: body's ability) -> body's choice 1,
#                 slot 2 (PIF: head's ability) -> head's choice 1,
#                 hidden -> body's choice 3
#   Saved on the Pokémon only once the player picks: @kifer_choice (Integer
#   index into the list), @kifer_choice_id (the picked Symbol),
#   @kifer_choice_fused (true/false: which list).
#   An ability set from outside (trainer data, KIF Endgame teams, events:
#   Pokemon#ability=) wins over the ER choice: @kifer_forced = true, and
#   PIF's own ability (@ability, then the ability slot) is used. The player's
#   Pokémon never keep it (Cody, 2026-10-18): it is cleared for wild Pokémon
#   and when one is caught, and the player picking a choice clears it.
#   Ability Capsule / Secret Capsule (Innates on): switch between the ER
#   choices, like the Summary does; never a plain PIF ability.
#   An evolution keeps the pick; becoming / stopping being a fusion goes back
#   to the starting pick.
#   A pick the mod hasn't coded yet falls back to PIF's ability (Cody).
#===============================================================================
module KIFER
  # [ability Symbols] the Pokémon can choose from (fusions: head 3 + body 3)
  def self.choice_list(pkmn)
    return [] if pkmn.respond_to?(:egg?) && pkmn.egg?
    return [] if pkmn.respond_to?(:isTripleFusion?) && pkmn.isTripleFusion?
    kit = kit_for(pkmn)   # another mod's kit (Megas), 002
    return kit[:choices].dup if kit && kit[:choices].is_a?(Array)
    if pkmn.isFusion?
      return choices_of(pkmn.get_head_species.id) + choices_of(pkmn.get_body_species.id)
    end
    return choices_of(pkmn.species)
  end

  def self.choices_of(species_id)
    e = entry(species_id)
    return e ? e[:choices].dup : []
  end

  def self.default_choice(pkmn, list)
    idx = pkmn.ability_index rescue 0
    if pkmn.isFusion?
      head = choices_of(pkmn.get_head_species.id).length
      return head if idx == 0                 # body's choice 1
      return 0 if idx == 1                    # head's choice 1
      return [head + 2, list.length - 1].min  # body's choice 3
    end
    return [[idx, 0].max, list.length - 1].min
  end

  # Index of the picked choice. Until the player picks one, it follows PIF's
  # own ability slot (so PIF changing the slot - Ability Capsule, fusing -
  # still counts). A pick is kept while the Pokémon stays fused / unfused.
  def self.choice_index(pkmn)
    list = choice_list(pkmn)
    return nil if list.empty?
    fused = pkmn.isFusion? ? true : false
    if pkmn.instance_variable_get(:@kifer_choice_fused) == fused
      idx = pick_in(list, pkmn.instance_variable_get(:@kifer_choice),
                    pkmn.instance_variable_get(:@kifer_choice_id))
      return idx if idx
    end
    return default_choice(pkmn, list)
  end

  # Where a saved pick is in the list now. The saved ability beats the index:
  # a DNA Reverser or a new fusion partner moves the list around. Not in the
  # list any more -> nil (start pick). Older saves (no ability) use the index.
  def self.pick_in(list, idx, id, avoid = nil)
    return nil unless idx.is_a?(Integer)
    return idx if idx >= 0 && idx < list.length && idx != avoid && (id.nil? || list[idx] == id)
    return nil if id.nil?
    return (0...list.length).find { |i| list[i] == id && i != avoid }
  end

  # Is PIF's own ability shown instead of the ER choice? (see the top)
  def self.forced?(pkmn)
    return pkmn.instance_variable_get(:@kifer_forced) == true
  end

  def self.set_choice(pkmn, idx)
    pkmn.instance_variable_set(:@kifer_choice, idx)
    pkmn.instance_variable_set(:@kifer_choice_id, idx.is_a?(Integer) ? choice_list(pkmn)[idx] : nil)
    pkmn.instance_variable_set(:@kifer_forced, nil)
    pkmn.instance_variable_set(:@kifer_choice_fused, pkmn.isFusion? ? true : false)
  end

  # The picked choice (Symbol), coded or not
  def self.chosen_ability(pkmn)
    idx = choice_index(pkmn)
    return nil if idx.nil?
    return choice_list(pkmn)[idx]
  end

  def self.coded?(id)
    return GameData::Ability.exists?(id)
  end

  # Display name / texts for any ER ability (coded or not)
  def self.ability_name(id)
    a = GameData::Ability.try_get(id)
    return a.name if a && AbilityTexts.api?   # KIF's ability text: ER's, or another mod's version
    t = ABILITY_TEXT[id]
    return t[:name] if t
    return a ? a.name : id.to_s
  end

  def self.ability_full_text(id)
    other = AbilityTexts.other_description(id)
    return other if other                      # another mod's version won
    t = ABILITY_TEXT[id]
    return t[:full] if t
    a = GameData::Ability.try_get(id)
    return a ? a.description : ""
  end

  class << self
    # true while PIF's fusion screen runs: ability_id gives PIF's own ability
    # there, so PIF never saves an ER ability in @ability (011_FusionPick.rb)
    attr_accessor :raw_ability
  end
end

class Pokemon
  alias kifer_ability_id ability_id unless method_defined?(:kifer_ability_id)
  def ability_id
    # Older saves: PIF's fusion screen stored an ER-only ability; forget it so
    # PIF picks its own from the ability slot again (ER_ONLY's test, from the data)
    @ability = nil if @ability && KIFER::ABILITY_TEXT[@ability] && KIFER::ABILITY_TEXT[@ability][:pif] == false
    if KIFER.enabled? && !KIFER.raw_ability && !@kifer_forced
      begin
        id = KIFER.chosen_ability(self)
        return id if id && KIFER.coded?(id)
      rescue StandardError => e
        KIFER.log("choice ability failed for #{@species.inspect}: #{e.class}: #{e.message}")
      end
    end
    return kifer_ability_id
  end

  alias kifer_set_ability ability= unless method_defined?(:kifer_set_ability)
  def ability=(value)
    kifer_set_ability(value)
    # PIF's fusion screen (raw_ability) and ER-only abilities don't count
    t = value && KIFER::ABILITY_TEXT[@ability]
    ok = KIFER.enabled? && value && GameData::Ability.exists?(value) && !KIFER.raw_ability && !(t && t[:pif] == false)
    @kifer_forced = ok ? true : nil
  end
end

# Ability Capsule / Secret Capsule while Innates is on: pick another ER choice.
# Innates off (or no ER choices, e.g. a triple fusion): KIF's own capsule.
module KIFER
  def self.use_capsule(pkmn, scene)
    list = choice_list(pkmn)
    cur  = choice_index(pkmn)
    two  = respond_to?(:choice2_index) ? choice2_index(pkmn) : nil
    head_n = pkmn.isFusion? ? choices_of(pkmn.get_head_species.id).length : 0
    opts = (0...list.length).select { |i| (i != cur || forced?(pkmn)) && i != two && coded?(list[i]) }
    if opts.empty?
      scene.pbDisplay(_INTL("It won't have any effect."))
      return false
    end
    names = opts.map do |i|
      n = ability_name(list[i])
      pkmn.isFusion? ? n + (i < head_n ? _INTL(" (head)") : _INTL(" (body)")) : n
    end
    cmd = scene.pbShowCommands(_INTL("Change {1}'s Ability to which one?", pkmn.name), names + [_INTL("Cancel")])
    return false if cmd.nil? || cmd < 0 || cmd >= opts.length
    store_choice2(pkmn, two) if two && respond_to?(:store_choice2)   # Ability 2 stays put
    set_choice(pkmn, opts[cmd])
    scene.pbHardRefresh if scene.respond_to?(:pbHardRefresh)
    scene.pbDisplay(_INTL("{1}'s Ability changed to {2}!", pkmn.name, ability_name(list[opts[cmd]])))
    return true
  end
end

[:ABILITYCAPSULE, :SECRETCAPSULE].each do |item|
  next unless GameData::Item.exists?(item)
  old = ItemHandlers::UseOnPokemon[item]
  ItemHandlers::UseOnPokemon.add(item, proc { |itm, pkmn, scene|
    if KIFER.enabled? && !pkmn.egg? && !KIFER.choice_list(pkmn).empty?
      next KIFER.use_capsule(pkmn, scene)
    end
    next old ? old.call(itm, pkmn, scene) : false
  })
end

# The player's Pokémon never keep a set ability: wild ones (hidden-ability
# maps) and caught ones (static overworld Pokémon) go back to the ER choice.
Events.onWildPokemonCreate += proc { |_sender, e|
  e[0].instance_variable_set(:@kifer_forced, nil) if e[0].is_a?(Pokemon)
}

module PokeBattle_BattleCommon
  alias kifer_pbStorePokemon pbStorePokemon unless method_defined?(:kifer_pbStorePokemon)
  def pbStorePokemon(pkmn)
    pkmn.instance_variable_set(:@kifer_forced, nil) if pkmn.is_a?(Pokemon)
    return kifer_pbStorePokemon(pkmn)
  end
end
