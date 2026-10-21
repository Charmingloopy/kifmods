#===============================================================================
# KIF: Elite Redux – dual abilities (Cody, 2026-10-13)
#   When another mod gives a fusion a 2nd ability (Kanto Reloaded's Double
#   Abilities, Ghost's Master/Unstable/Ultra/Chaos Splicers, or PIF's double
#   abilities switch), that fusion gets:
#     * 2 choice abilities, both picked from its head's 3 + body's 3
#     * all 6 innates (head's 3 + body's 3), no picking; copies stack
#   The 2nd choice is also what ability2 / ability2_id give back, so the other
#   mods show it. In battle the mod runs it like an innate; Kanto Reloaded's
#   own 2nd-ability handling is switched off for that battler so it doesn't
#   run twice.
#   Saved on the Pokémon only once the player picks: @kifer_choice2 (Integer
#   index into the choice list), @kifer_choice2_id (the picked Symbol).
#===============================================================================
module KIFER
  # Does this Pokémon have a 2nd ability from another mod right now?
  def self.dual?(pkmn)
    return false unless enabled? && pkmn
    return false unless pkmn.respond_to?(:isFusion?) && pkmn.isFusion?
    return false if pkmn.respond_to?(:isTripleFusion?) && pkmn.isTripleFusion?
    return false if pkmn.respond_to?(:egg?) && pkmn.egg?
    return true if pkmn.instance_variable_get(:@master_splicer_fused)            # Ghost's splicers
    return true if defined?(KIF::ModCompat) && KIF::ModCompat.respond_to?(:double_abilities?) &&
                   KIF::ModCompat.double_abilities?                              # PIF switch
    if defined?(KantoReloaded::DoubleAbilities)
      kr = KantoReloaded::DoubleAbilities
      return true if kr.respond_to?(:enabled?) && kr.enabled? &&
                     !(kr.respond_to?(:family_pokemon?) && kr.family_pokemon?(pkmn))
    end
    return false
  rescue StandardError
    return false
  end

  # Index of the 2nd choice (never the same slot as the 1st; the same
  # ability from the other parent is fine - copies stack)
  def self.choice2_index(pkmn)
    return nil unless dual?(pkmn)
    list = choice_list(pkmn)
    c1 = choice_index(pkmn)
    return nil if list.length < 2 || c1.nil?
    ok = proc { |i| i.is_a?(Integer) && i >= 0 && i < list.length && i != c1 }
    idx = pick_in(list, pkmn.instance_variable_get(:@kifer_choice2),
                  pkmn.instance_variable_get(:@kifer_choice2_id), c1)
    return idx if ok.call(idx)
    # start: the other parent's 1st choice, then anything different
    head = choices_of(pkmn.get_head_species.id).length
    start = c1 < head ? head : 0
    ([start] + (0...list.length).to_a).each { |i| return i if ok.call(i) }
    return nil
  end

  def self.chosen_ability2(pkmn)
    idx = choice2_index(pkmn)
    return idx ? choice_list(pkmn)[idx] : nil
  end

  # Picking one slot to the other's ability swaps the two
  def self.set_choice2(pkmn, idx)
    if idx == choice_index(pkmn)
      old2 = choice2_index(pkmn)
      set_choice(pkmn, old2) if old2
    end
    store_choice2(pkmn, idx)
  end

  def self.store_choice2(pkmn, idx)
    pkmn.instance_variable_set(:@kifer_choice2, idx)
    pkmn.instance_variable_set(:@kifer_choice2_id, idx.is_a?(Integer) ? choice_list(pkmn)[idx] : nil)
  end

  class << self
    alias kifer_single_set_choice set_choice unless method_defined?(:kifer_single_set_choice)
    def set_choice(pkmn, idx)
      if dual?(pkmn) && idx == choice2_index(pkmn)
        old1 = choice_index(pkmn)
        kifer_single_set_choice(pkmn, idx)
        store_choice2(pkmn, old1)
        return
      end
      kifer_single_set_choice(pkmn, idx)
    end

    # Dual fusions keep all of their head's and body's innates
    alias kifer_single_pokemon_innates pokemon_innates unless method_defined?(:kifer_single_pokemon_innates)
    def pokemon_innates(pkmn)
      if dual?(pkmn)
        return fusion_pool(pkmn.get_head_species.id, pkmn.get_body_species.id)
      end
      return kifer_single_pokemon_innates(pkmn)
    end

    # In battle the 2nd choice runs with the innates
    alias kifer_single_battle_innates battle_innates unless method_defined?(:kifer_single_battle_innates)
    def battle_innates(pkmn)
      list = kifer_single_battle_innates(pkmn)
      c2 = chosen_ability2(pkmn)
      return list unless c2 && coded?(c2)
      return [c2] + list
    end
  end
end

class Pokemon
  if method_defined?(:ability2_id)
    alias kifer_ability2_id ability2_id unless method_defined?(:kifer_ability2_id)
    def ability2_id
      if KIFER.enabled?
        begin
          id = KIFER.chosen_ability2(self)
          return id if id && KIFER.coded?(id)
        rescue StandardError => e
          KIFER.log("2nd choice failed for #{@species.inspect}: #{e.class}: #{e.message}")
        end
      end
      return kifer_ability2_id
    end
  end

  if method_defined?(:ability2)
    alias kifer_ability2 ability2 unless method_defined?(:kifer_ability2)
    def ability2
      if KIFER.enabled?
        id = (KIFER.chosen_ability2(self) rescue nil)
        return GameData::Ability.try_get(id) if id && KIFER.coded?(id)
      end
      return kifer_ability2
    end
  end
end

class PokeBattle_Battler
  # Set in pbInitEffects (PIF runs it after pbInitPokemon): Kanto Reloaded's
  # pbInitPokemon hook re-attaches itself on top and clears this flag after
  # any inner hook set it
  alias kifer_dual_pbInitEffects pbInitEffects unless method_defined?(:kifer_dual_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_dual_pbInitEffects(batonPass)
    if defined?(KantoReloaded::DoubleAbilities) && @pokemon && KIFER.dual?(@pokemon)
      @kr_double_abilities_disabled = true   # the mod runs the 2nd ability
    end
  end
end
