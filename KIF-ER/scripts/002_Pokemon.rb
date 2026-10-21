#===============================================================================
# KIF: Elite Redux – which innates a Pokémon has
#   Non-fusion: its species' 3 innates.
#   Fusion: 3 of its head's and body's 6, picked at random the first time and
#   kept on the Pokémon (@kifer_picked). Kept through
#   evolution; picked again once a pick isn't in the fusion's 6 any more.
#   Plain Ruby data, so saves load without the mod.
#   Triple fusions get none.
#===============================================================================
class Pokemon
  # Innates this Pokémon has (Symbols), whether or not the game implements them yet
  def innates
    return [] unless KIFER.enabled?
    return KIFER.pokemon_innates(self)
  rescue StandardError => e
    KIFER.log("innates failed for #{@species.inspect}: #{e.class}: #{e.message}")
    return []
  end

  # Replace a fusion's 3 picked innates (Summary screen, phase 2)
  def kifer_pick=(list)
    @kifer_picked = list.is_a?(Array) ? list.map { |a| a.to_sym }.first(3) : nil
  end
end

module KIFER
  #-----------------------------------------------------------------------------
  # Kits from other mods: a mod can give a Pokémon another ER kit (Megas: a
  # Mega's choices and innates). The first provider that answers a Hash wins:
  #   KIFER.register_kit("Megas") { |pkmn| mega?(pkmn) ? { :choices => [...], :innates => [...] } : nil }
  # After a mid-battle form change, KIFER.refresh_battler(battler) re-reads
  # the battler's innates.
  #-----------------------------------------------------------------------------
  @kit_providers = []

  def self.register_kit(owner, &block)
    @kit_providers.reject! { |o, _| o == owner }
    @kit_providers << [owner, block] if block
    return nil
  end

  def self.unregister_kit(owner)
    @kit_providers.reject! { |o, _| o == owner }
    return nil
  end

  def self.kit_for(pkmn)
    return nil if @kit_providers.empty? || !pkmn.is_a?(Pokemon)
    @kit_providers.each do |owner, block|
      begin
        k = block.call(pkmn)
        return k if k.is_a?(Hash)
      rescue StandardError => e
        log("kit from #{owner} failed: #{e.class}: #{e.message}")
      end
    end
    return nil
  end

  def self.refresh_battler(battler)
    return if !battler || !battler.pokemon
    battler.instance_variable_set(:@innate_ids, battle_innates(battler.pokemon))
  end

  def self.pokemon_innates(pkmn)
    return [] if pkmn.respond_to?(:egg?) && pkmn.egg?
    return [] if pkmn.respond_to?(:isTripleFusion?) && pkmn.isTripleFusion?
    kit = kit_for(pkmn)
    return kit[:innates].dup if kit && kit[:innates].is_a?(Array)
    return species_innates(pkmn.species) unless pkmn.isFusion?
    head = pkmn.get_head_species
    body = pkmn.get_body_species
    pool = fusion_pool(head.id, body.id)
    picked = pkmn.instance_variable_get(:@kifer_picked)
    fresh = picked.is_a?(Array) && !picked.empty? && KIFER.sub_multiset?(picked, pool)
    unless fresh
      idxs = (0...pool.length).to_a.sample([3, pool.length].min).sort
      picked = idxs.map { |i| pool[i] }                   # keep head-then-body order
      pkmn.instance_variable_set(:@kifer_picked, picked)
    end
    return picked.dup
  end

  # Every item of `part` is in `whole`, counting copies
  def self.sub_multiset?(part, whole)
    left = whole.dup
    part.each do |a|
      i = left.index(a)
      return false unless i
      left.delete_at(i)
    end
    return true
  end

  # Innates that work in battle (the game has the ability)
  def self.battle_innates(pkmn)
    return [] unless enabled?
    return pkmn.innates.select { |a| GameData::Ability.exists?(a) }
  end
end
