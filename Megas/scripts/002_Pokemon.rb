#===============================================================================
# A Pokémon's Mega state.
#   The saved species never changes (Charizard stays :CHARIZARD). While Mega,
#   @megas_form holds the Mega's id and @megas_base the species it was set for;
#   both are plain Symbols, so a save still loads without this mod.
#   PIF's own Mega and Primal methods are form based (forms do nothing in
#   PIF), so they are replaced here. A Primal uses the same state; it is not
#   a Mega (mega? false, primal? true).
#===============================================================================
module Megas
  class << self
    attr_accessor :primal_now   # true while the Mega button triggers a Manual Primal
  end

  # The Mega (kind :mega) or Primal (:primal) this Pokémon could turn into now
  # (held stone or orb), or nil.
  def self.available(pkmn, kind = :mega)
    return nil if pkmn.egg?
    return fusion_available(pkmn, kind) if pkmn.isFusion?   # 010_Fusions.rb
    item = pkmn.instance_variable_get(:@item)
    DATA.each do |id, m|
      next if m[:base] != pkmn.species || (m[:primal] ? :primal : :mega) != kind
      next if !usable?(m)
      return id if m[:stone] ? m[:stone] == item : pkmn.hasMove?(m[:move])
    end
    return nil
  end

  # Permanent mode: who in this party is Mega (all holders, or the first one
  # with One per party); everyone else, Primals too, turns back. Once per
  # battle: everyone turns back. Run at battle start and end, on the Summary
  # and when the setting changes.
  # One per party is sticky (Cody, 2026-10-20): the current Mega keeps the
  # slot until it faints, leaves the party or loses its stone; then the next
  # able holder in party order gets it at the next check. Fainted Pokémon are
  # never Mega, so a revived former Mega comes back normal. Pokémon in the PC
  # are never Mega.
  def self.sync(party)
    return if !party
    sync_boxes
    able = party.select { |pk| pk && !pk.egg? && pk.hp > 0 && available(pk, :mega) }
    holders = permanent? ? able : []
    holders = [holders.find(&:mega?) || holders.first].compact if one_per_party?
    party.each do |pk|
      next if !pk
      want = holders.any? { |h| h.equal?(pk) } ? available(pk, :mega) : nil
      next if current(pk) == want
      pk.makeUnmega if current(pk)
      pk.makeMega if want
    end
  end

  # Can this Mega be used now? An Elite Redux Mega needs KIF:ER on and one of
  # its ER abilities coded; any other Mega needs its own ability in the game.
  def self.usable?(m)
    return er? && m[:er][:choices].any? { |a| GameData::Ability.exists?(a) } if m[:er_only]
    return GameData::Ability.exists?(m[:ability])
  end

  def self.sync_boxes
    st = $PokemonStorage
    return if !st || !st.respond_to?(:boxes) || !st.boxes
    st.boxes.each do |box|
      next if !box || !box.respond_to?(:pokemon) || !box.pokemon
      box.pokemon.each { |pk| pk.makeUnmega if pk.is_a?(Pokemon) && current(pk) }
    end
  end

  # The Mega this Pokémon is right now, or nil. An Elite Redux Mega stops
  # counting when KIF:ER is turned off.
  def self.current(pkmn)
    id = pkmn.instance_variable_get(:@megas_form)
    swap_picks(pkmn) if !@saving && pkmn.instance_variable_get(:@megas_pick_saved)   # first look after loading
    return nil if !id || pkmn.instance_variable_get(:@megas_base) != pkmn.species
    list = id.is_a?(Array) ? id.compact : [id]   # a fusion: [head Mega, body Mega], nil for a normal half
    return nil if list.empty? || list.any? { |i| !DATA[i] || (DATA[i][:er_only] && !er?) }
    return id
  end

  # KIF:ER on: Megas use their Elite Redux kit (types, stats, abilities)
  def self.er?
    return defined?(::KIFER) && KIFER.respond_to?(:enabled?) && KIFER.enabled? ? true : false
  end

  @species_cache = {}

  # The base species' data with the Mega's types, stats and ability.
  # Rebuilt when the base data changes (randomizer, data reload). KIF's
  # species token changes when learnsets or evolutions change in place
  # (KIF-ER's Moves setting, the randomizer) without touching the stats.
  def self.species_data(id, base_sd)
    er = er? ? DATA[id][:er] : nil
    key = [base_sd.object_id, base_sd.base_stats.hash, !er.nil?, (defined?(KIF::Perf) ? KIF::Perf.token : nil)]
    hit = @species_cache[id]
    return hit[1] if hit && hit[0] == key
    m = DATA[id]
    sd = base_sd.clone
    stats = base_sd.base_stats.dup
    if er
      er[:stats].each { |stat, v| stats[stat] = v if stat != :HP }   # HP never changes mid-battle
    else
      m[:delta].each { |stat, d| stats[stat] = [stats[stat] + d, 1].max }
    end
    types = er ? er[:types] : m[:types]
    sd.instance_variable_set(:@base_stats, stats)
    sd.instance_variable_set(:@type1, types[0])
    sd.instance_variable_set(:@type2, types[1] || types[0])
    sd.instance_variable_set(:@abilities, [m[:ability]])
    sd.instance_variable_set(:@hidden_abilities, [])
    sd.instance_variable_set(:@mega_stone, m[:stone])   # PIF's unlosableItem? reads this while Mega
    sd.instance_variable_set(:@real_form_name, m[:name])
    @species_cache[id] = [key, sd]
    return sd
  end
end

class Pokemon
  alias megas_species_data species_data unless method_defined?(:megas_species_data)
  def species_data
    id = Megas.current(self)
    return megas_species_data if !id
    return Megas.fusion_species_data(id, megas_species_data) if id.is_a?(Array)
    return Megas.species_data(id, megas_species_data)
  end

  # The Mega's ability; the Pokémon's own ability (@ability) is left alone
  alias megas_ability_id ability_id unless method_defined?(:megas_ability_id)
  def ability_id
    id = Megas.current(self)
    return megas_ability_id if !id
    return Megas.fusion_ability(self, id) if id.is_a?(Array)
    m = Megas::DATA[id]
    if Megas.er? && m[:er]
      er = KIFER.chosen_ability(self) rescue nil   # picked from the Mega's ER choices (006_KIFER.rb)
      return er if er && GameData::Ability.exists?(er)
      # an Elite Redux Mega whose pick isn't coded yet: its first coded choice
      return m[:er][:choices].find { |a| GameData::Ability.exists?(a) } if m[:er_only]
    end
    return m[:ability]
  end

  def hasMegaForm?
    return false if Megas.current(self)
    return true if Megas.available(self, :mega)
    return Megas.manual_primal? && !Megas.available(self, :primal).nil?   # Manual Primal: the Mega button
  end

  def mega?
    id = Megas.current(self)
    return !id.nil? && Megas.ids(id).any? { |i| !Megas::DATA[i][:primal] }
  end

  def hasPrimalForm?
    return false if Megas.current(self)
    return false if Megas.manual_primal? && !Megas.primal_now   # Manual: only from the Mega button
    return !Megas.available(self, :primal).nil?
  end

  def primal?
    id = Megas.current(self)
    return !id.nil? && Megas.ids(id).any? { |i| Megas::DATA[i][:primal] == true }
  end

  # KIF-ER's saved ability pick: a pick made from the Mega's list must not
  # replace the base Pokémon's, so it is kept here while Mega and put back after
  MEGAS_KIFER_PICK = [:@kifer_choice, :@kifer_choice_id, :@kifer_choice_fused] unless defined?(MEGAS_KIFER_PICK)

  def makeMega;   megas_become(Megas.available(self, :mega));   end
  def makePrimal; megas_become(Megas.available(self, :primal)); end
  def makeUnprimal; makeUnmega if primal?; end

  def megas_become(id)
    return if !id
    @megas_kifer_pick = MEGAS_KIFER_PICK.map { |v| instance_variable_get(v) }
    @megas_form = id
    @megas_base = @species
    calc_stats
  end

  def makeUnmega
    return if !@megas_form
    remove_instance_variable(:@megas_form)
    remove_instance_variable(:@megas_base) if instance_variable_defined?(:@megas_base)
    if instance_variable_defined?(:@megas_kifer_pick)
      MEGAS_KIFER_PICK.zip(remove_instance_variable(:@megas_kifer_pick) || []).each do |v, x|
        if !x.nil? then instance_variable_set(v, x)
        elsif instance_variable_defined?(v) then remove_instance_variable(v)
        end
      end
    end
    calc_stats
  end

  def megaName
    id = Megas.current(self) || Megas.available(self, :mega)
    return _INTL("Mega {1}", speciesName) if !id || id.is_a?(Array)
    return Megas::DATA[id][:name]
  end

  def megaMessage
    id = Megas.current(self) || Megas.available(self, :mega)
    return id && Megas.ids(id).any? { |i| Megas::DATA[i][:move] } ? 1 : 0   # 1 = Rayquaza's "fervent wish" message
  end
end

#===============================================================================
# Saves keep the base Pokémon's KIF-ER ability pick where KIF-ER looks for it,
# so a game without this mod (removed, or Off in the Mods list) still has the
# player's pick. A Mega's own pick waits in @megas_kifer_pick meanwhile, and
# Megas.current swaps the two back the first time it sees the Pokémon after
# loading (@megas_pick_saved). In memory nothing changes.
#===============================================================================
module Megas
  def self.swap_picks(pk)
    names = Pokemon::MEGAS_KIFER_PICK
    now = names.map { |v| pk.instance_variable_get(v) }
    parked = pk.instance_variable_get(:@megas_kifer_pick) || []
    names.each_with_index do |v, i|
      if !parked[i].nil?
        pk.instance_variable_set(v, parked[i])
      elsif pk.instance_variable_defined?(v)
        pk.remove_instance_variable(v)
      end
    end
    pk.instance_variable_set(:@megas_kifer_pick, now)
    if pk.instance_variable_get(:@megas_pick_saved)
      pk.remove_instance_variable(:@megas_pick_saved)
    else
      pk.instance_variable_set(:@megas_pick_saved, true)
    end
  end

  # Every Pokémon a save holds that is Mega right now (party and boxes)
  # shortcut: Day Care Pokémon are left out; a Mega can't be left there in battle-only mode, upgrade if Permanent Megas are put in the Day Care
  def self.saved_megas
    mons = $Trainer ? $Trainer.party.dup : []
    if $PokemonStorage && $PokemonStorage.respond_to?(:maxBoxes)
      $PokemonStorage.maxBoxes.times { |b| $PokemonStorage.maxPokemon(b).times { |i| mons << $PokemonStorage[b, i] } }
    end
    return mons.compact.select { |pk| pk.instance_variable_get(:@megas_form) && pk.instance_variable_defined?(:@megas_kifer_pick) }
  end

  def self.with_base_picks
    done = []
    @saving = true
    saved_megas.each { |pk| swap_picks(pk); done << pk }
    return yield
  ensure
    (done || []).each { |pk| swap_picks(pk) }
    @saving = false
  end
end

module Game
  class << self
    alias megas_save save unless method_defined?(:megas_save)
    def save(*args, **kw)
      return Megas.with_base_picks { megas_save(*args, **kw) }
    end
  end
end
