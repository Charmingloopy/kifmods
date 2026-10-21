#===============================================================================
# Mega fusions (Cody, 2026-10-20: option C, the overlay; no new species).
#   * The fusion holds one stone: the half it fits Mega Evolves. If the
#     player's bag has a stone for the other half, that half goes Mega too
#     (Mega Charizard x Mega Blastoise). Trainers never do Mega + Mega.
#   * A stone that fits both halves (Charizard x Charizard): both halves Mega
#     with a second copy in the bag; otherwise the half the DNA Splicer asked
#     for when fusing (@megas_fusion_half, :head by default).
#   * The fused data is PIF's own FusedSpecies with the Mega half (or halves)
#     swapped in, so PIF's fusion rules (dominant stats, types) apply.
#   * The self-fusion boost only for matching Megas (X x X, never X x Y).
#   * No Mega fusion sprites exist: the normal fusion sprite gets a Mega
#     badge and an aura (Cody: badge + aura).
# State: @megas_form = [head Mega id or nil, body Mega id or nil].
#===============================================================================
module Megas
  def self.ids(form)
    return form.is_a?(Array) ? form.compact : [form]
  end

  def self.fusion_halves(pkmn)
    base = pkmn.megas_species_data
    return [] if !base.respond_to?(:head_pokemon) || !base.head_pokemon
    return [base.head_pokemon.id, base.body_pokemon.id]
  end

  def self.player_owns?(pkmn)
    return $Trainer && $Trainer.party.any? { |p| p.equal?(pkmn) }
  end

  def self.in_bag?(item)
    return $PokemonBag && $PokemonBag.respond_to?(:pbQuantity) && $PokemonBag.pbQuantity(item) > 0
  end

  # [head id, body id] this fusion could turn into now, or nil
  def self.fusion_available(pkmn, kind = :mega)
    return nil if pkmn.respond_to?(:isTripleFusion?) && pkmn.isTripleFusion?
    base = pkmn.megas_species_data
    return nil if !base.respond_to?(:head_pokemon) || !base.head_pokemon || !base.body_pokemon
    halves = [base.head_pokemon.id, base.body_pokemon.id]
    item = pkmn.instance_variable_get(:@item)
    kinds = lambda { |m| (m[:primal] ? :primal : :mega) == kind && usable?(m) }
    held = halves.map do |sp|
      DATA.find { |_i, m| m[:base] == sp && kinds.call(m) && (m[:stone] ? m[:stone] == item : pkmn.hasMove?(m[:move])) }
    end
    return nil if !held[0] && !held[1]
    i = if held[0] && held[1] then (pkmn.instance_variable_get(:@megas_fusion_half) == :body ? 1 : 0)
        else (held[0] ? 0 : 1) end
    ids = [nil, nil]
    ids[i] = held[i][0]
    if kind == :mega && player_owns?(pkmn)
      other = halves[1 - i]
      found = DATA.select { |_i, m| m[:base] == other && kinds.call(m) && m[:stone] && in_bag?(m[:stone]) }
      found = found.sort_by { |_i, m| m[:stone] == item ? 0 : 1 }   # the same stone first (X x X)
      ids[1 - i] = found[0][0] if found[0]
    end
    return ids
  end

  @fusion_cache = {}

  # PIF's FusedSpecies for this fusion with the Mega half (or halves) in
  def self.fusion_species_data(ids, base)
    er = er?
    key = [base.object_id, base.base_stats.hash, er, (defined?(KIF::Perf) ? KIF::Perf.token : nil)]
    hit = @fusion_cache[ids]
    return hit[1] if hit && hit[0] == key
    sd = base.clone
    head = ids[0] ? species_data(ids[0], base.head_pokemon) : base.head_pokemon
    body = ids[1] ? species_data(ids[1], base.body_pokemon) : base.body_pokemon
    sd.instance_variable_set(:@head_pokemon, head)
    sd.instance_variable_set(:@body_pokemon, body)
    sd.instance_variable_set(:@type1, sd.send(:calculate_type1))
    sd.instance_variable_set(:@type2, sd.send(:calculate_type2))
    sd.instance_variable_set(:@base_stats, sd.send(:calculate_base_stats))
    sd.instance_variable_set(:@abilities, sd.send(:calculate_abilities))
    sd.instance_variable_set(:@hidden_abilities, sd.send(:calculate_hidden_abilities))
    sd.instance_variable_set(:@real_name, _INTL("Mega {1}", base.real_name))
    sd.instance_variable_set(:@mega_stone, ids.compact.map { |i| DATA[i][:stone] }.compact.first)
    @fusion_cache[ids] = [key, sd]
    return sd
  end

  # The Mega half's ability (both Mega: PIF's ability slot picks: 1 = head,
  # otherwise body). KIF:ER on: the Pokémon's ER pick when it's coded.
  def self.fusion_ability(pkmn, ids)
    if er?
      er = KIFER.chosen_ability(pkmn) rescue nil
      return er if er && GameData::Ability.exists?(er)
    end
    head = ids[0] && DATA[ids[0]]
    body = ids[1] && DATA[ids[1]]
    pick = lambda { |m| m && (m[:er_only] ? m[:er][:choices].find { |a| GameData::Ability.exists?(a) } : m[:ability]) }
    first, second = pkmn.ability_index == 1 ? [head, body] : [body, head]
    return pick.call(first) || pick.call(second)
  end

  # Mega badge and aura on a fusion's normal sprite (no Mega fusion sprites
  # exist). Drawn on a private copy, in sprite pixels (the bitmap's own scale).
  AURA_INNER = 0x78C8FFFF unless defined?(AURA_INNER)   # light blue
  AURA_OUTER = 0x7846C8FF unless defined?(AURA_OUTER)   # purple

  def self.decorate!(anim)
    if defined?(KIF::Shiny) && KIF::Shiny.respond_to?(:privatize)
      KIF::Shiny.privatize(anim)
    else
      anim.bitmap = anim.bitmap.clone
    end
    bmp = anim.bitmap
    return anim if !bmp.respond_to?(:raw_data)
    w = bmp.width
    h = bmp.height
    s = (w % 96 == 0 && w >= 96) ? w / 96 : 1   # PIF draws 96px sprites at 3x
    cw = w / s
    ch = h / s
    px = bmp.raw_data.unpack("N*")
    solid = Array.new(cw * ch) { |k| (px[(k / cw) * s * w + (k % cw) * s] & 0xFF) != 0 }
    grow = lambda do |mask|
      out = mask.dup
      mask.each_index do |k|
        next if !mask[k]
        x = k % cw
        y = k / cw
        out[k - 1] = true if x > 0
        out[k + 1] = true if x < cw - 1
        out[k - cw] = true if y > 0
        out[k + cw] = true if y < ch - 1
      end
      out
    end
    ring1 = grow.call(solid)
    ring2 = grow.call(ring1)
    paint = lambda do |k, color|
      x0 = (k % cw) * s
      y0 = (k / cw) * s
      s.times { |dy| s.times { |dx| i = (y0 + dy) * w + x0 + dx; px[i] = color if (px[i] & 0xFF) == 0 } }
    end
    ring2.each_index do |k|
      next if solid[k] || !ring2[k]
      paint.call(k, ring1[k] ? AURA_INNER : AURA_OUTER)
    end
    badge = (Bitmap.new("Graphics/Pictures/Battle/icon_mega") rescue nil)
    if badge && badge.respond_to?(:raw_data)
      bpx = badge.raw_data.unpack("N*")
      bw = badge.width
      bpx.each_with_index do |c, k|
        next if (c & 0xFF) == 0
        s.times { |dy| s.times { |dx| x = 2 * s + (k % bw) * s + dx; y = 2 * s + (k / bw) * s + dy; px[y * w + x] = c if x < w && y < h } }
      end
      badge.dispose
    end
    bmp.raw_data = px.pack("N*")
    return anim
  end
end

# The DNA Splicer asks which half goes Mega when one stone fits both halves
alias megas_pbFuse pbFuse unless Object.method_defined?(:megas_pbFuse) || Object.private_method_defined?(:megas_pbFuse)
def pbFuse(pokemon_body, pokemon_head, *args)
  both = pokemon_body.species == pokemon_head.species &&
         Megas::DATA.any? { |_i, m| m[:base] == pokemon_body.species && m[:stone] }
  ret = megas_pbFuse(pokemon_body, pokemon_head, *args)
  if ret && both
    cmd = pbMessage(_INTL("A Mega Stone fits both halves. When {1} holds one, which half should Mega Evolve?", pokemon_body.name),
                    [_INTL("Head"), _INTL("Body")], 1)
    pokemon_body.instance_variable_set(:@megas_fusion_half, cmd == 1 ? :body : :head)
  end
  return ret
end

class Pokemon
  # Self-fusion boost (KIF option): only while both halves are the same Mega
  if method_defined?(:kif_self_fusion_factor)
    alias megas_kif_self_fusion_factor kif_self_fusion_factor unless method_defined?(:megas_kif_self_fusion_factor)
    def kif_self_fusion_factor
      id = Megas.current(self)
      return nil if id.is_a?(Array) && (id[0].nil? || id[0] != id[1])
      return megas_kif_self_fusion_factor
    end
  end
end
