#===============================================================================
# KIF: Elite Redux – KIF randomizer
#   When the randomizer's "Abilities" is on (Random / Flavour / Bound), the
#   ER abilities are rolled too. A new row under it on the Pokémon data page
#   picks what is rolled (Cody, 2026-10-13):
#     Choice  – each species' 3 choice abilities
#     Innates – each species' 3 innates
#     Both
#   Rolls use the randomizer's own seed, ability pool (its mode, bans and
#   "No self-harm") and families: an evolution family with the same types
#   gets the same rolls, like the randomizer's own abilities.
#   Kept with the randomizer's species changes (data[:species][s][:kifer_er]),
#   so they are saved with the game, re-rolled with it and cleared with it.
#   The randomizer's own files are not changed.
#   PIF's own ability slots (the randomizer's rolls) never get an ER-only
#   ability: those would be saved in the game and break it without the mod.
#===============================================================================
module KIFER
  RAND_KEY   = :kifer_abilities           # 0 = Choice, 1 = Innates, 2 = Both
  RAND_MODES = [:choice, :innates, :both]

  def self.rand_ready?
    return defined?(KIF::Rand) && KIF::Rand.respond_to?(:randomize_data) &&
           KIF::Rand.respond_to?(:ability_pool) && KIF::Rand.respond_to?(:family_info)
  end

  # The species' ER entry with the randomizer's rolls in it (nil table = none)
  def self.rand_entry(species_id, base)
    g = $PokemonGlobal
    return base unless g && g.respond_to?(:kif_rand)
    sp = g.kif_rand[:species] rescue nil
    return base unless sp.is_a?(Hash)
    ch = sp[species_id]
    r = ch.is_a?(Hash) ? ch[:kifer_er] : nil
    return base unless r.is_a?(Hash)
    out = base ? base.dup : { :choices => [], :innates => [] }
    out[:choices] = r[:choices] if r[:choices]
    out[:innates] = r[:innates] if r[:innates]
    return out
  end

  # Rolls for every species with ER data. Returns { species => {choices:, innates:} }
  def self.rand_roll(changes)
    rk = KIF::Rand
    mode = RAND_MODES[rk.dget(RAND_KEY)] || :choice
    types = {}
    changes.each { |s, f| types[s] = f if f.is_a?(Hash) && f.key?(:@type1) }
    out = {}
    @er_pool = true                                 # ER rows may roll ER-only abilities
    rk.with_seed(:kifer_er) do
      fams = rk.family_info.group_by { |_s, info| info[0] }
      fams.keys.sort_by { |b| GameData::Species.get(b).id_number }.each do |base|
        members = fams[base].map(&:first).sort_by { |s| rk.family_info[s][1] * 10000 + GameData::Species.get(s).id_number }
        rolled = {}
        members.each do |s|
          next unless SPECIES_DATA[s]
          my = rk.new_types_of(s, types).compact.uniq
          key = my.sort
          unless rolled[key]
            pool = rk.ability_pool(my)
            ch = pool.sample(3)
            inn = (pool - ch).sample(3)
            inn += pool.sample(3 - inn.length) if inn.length < 3
            rolled[key] = { :choices => ch, :innates => inn }
          end
          r = {}
          r[:choices] = rolled[key][:choices].dup if mode != :innates
          r[:innates] = rolled[key][:innates].dup if mode != :choice
          out[s] = r
        end
      end
    end
    return out
  ensure
    @er_pool = false
  end

  class << self
    attr_reader :er_pool
  end
end

if KIFER.rand_ready?
  module KIF
    module Rand
      unless DATA_KEYS.include?(KIFER::RAND_KEY)
        DATA_SETTINGS << [KIFER::RAND_KEY, :enum, 3]
        DATA_KEYS << KIFER::RAND_KEY
      end

      class << self
        alias kifer_randomize_data randomize_data unless method_defined?(:kifer_randomize_data)
        def randomize_data(*args)
          ch = kifer_randomize_data(*args)
          begin
            if ch.is_a?(Hash) && dget(:abilities) > 0
              KIFER.rand_roll(ch).each { |s, r| (ch[s] ||= {})[:kifer_er] = r }
            end
          rescue StandardError => e
            KIFER.log("randomizer: ER abilities not rolled: #{e.class}: #{e.message}")
          end
          return ch
        end

        # PIF's slots: no ER-only abilities
        alias kifer_ability_pool ability_pool unless method_defined?(:kifer_ability_pool)
        def ability_pool(*args)
          pool = kifer_ability_pool(*args)
          return pool if KIFER.er_pool || !defined?(KIFER::ER_ONLY)
          return pool - KIFER::ER_ONLY
        end

        # The new row on the Pokémon data page, under "Abilities"
        alias kifer_open_page open_page unless method_defined?(:kifer_open_page)
        def open_page(title, desc, color, &builder)
          if builder && KIFER.enabled? && title == _INTL("Randomizer: Pokémon data")
            orig = builder
            builder = proc do
              rows = orig.call
              begin
                at = rows.index { |r| r.instance_variable_get(:@kif_key) == :abilities }
                row = enum(KIFER::RAND_KEY, _INTL("ER abilities"),
                           [_INTL("Choice"), _INTL("Innates"), _INTL("Both")],
                           [_INTL("Randomize each Pokémon's 3 choice abilities."),
                            _INTL("Randomize each Pokémon's 3 innates."),
                            _INTL("Randomize choice abilities and innates.")])
                rows.insert(at ? at + 1 : rows.length, row)
              rescue StandardError => e
                KIFER.log("randomizer: row not added: #{e.class}: #{e.message}")
              end
              rows
            end
          end
          return kifer_open_page(title, desc, color, &builder)
        end

        # The randomizer log lists the ER rolls after the Pokémon data
        if method_defined?(:sec_pokemon_data)
          alias kifer_sec_pokemon_data sec_pokemon_data unless method_defined?(:kifer_sec_pokemon_data)
          def sec_pokemon_data(*args)
            lines = kifer_sec_pokemon_data(*args)
            begin
              sp = data[:species] || {}
              name = proc { |a| KIFER.ability_name(a) }
              sp.keys.select { |s| sp[s].is_a?(Hash) && sp[s][:kifer_er] }
                .sort_by { |s| GameData::Species.get(s).id_number }.each do |s|
                r = sp[s][:kifer_er]
                g = GameData::Species.get(s)
                bits = []
                bits << "ER choices: " + r[:choices].map(&name).join(", ") if r[:choices]
                bits << "innates: " + r[:innates].map(&name).join(", ") if r[:innates]
                lines << sprintf("#%03d %s: %s", g.id_number, g.real_name, bits.join(" | "))
              end
            rescue StandardError => e
              KIFER.log("randomizer log: #{e.class}: #{e.message}")
            end
            return lines
          end
        end
      end
    end
  end

  module KIFER
    class << self
      alias kifer_plain_entry entry unless method_defined?(:kifer_plain_entry)
      def entry(species_id)
        return rand_entry(species_id, kifer_plain_entry(species_id))
      end
    end
  end
end

#-------------------------------------------------------------------------------
# One-time save repair (saves from before 0.3.5): ER-only abilities that
# KIF's randomizer put in PIF's own slots get a fresh roll from the fixed pool,
# and Pokémon whose stored ability (@ability) is ER-only forget it, so the save
# still works without the mod. ER rows (:kifer_er) are left alone.
#-------------------------------------------------------------------------------
module KIFER
  REPAIR_FLAG = :@kifer_rand_repair   # in $PokemonGlobal: 1 = done

  def self.repair_save
    g = $PokemonGlobal
    return unless g && defined?(ER_ONLY) && !g.instance_variable_get(REPAIR_FLAG)
    n = repair_rand_slots + repair_stored_abilities
    g.instance_variable_set(REPAIR_FLAG, 1)
    log("save repair: #{n} ER-only abilities taken out of PIF's slots") if n > 0
  end

  def self.repair_rand_slots
    sp = ($PokemonGlobal.kif_rand[:species] rescue nil)
    return 0 unless sp.is_a?(Hash) && rand_ready?
    fields = [:@abilities, :@hidden_abilities]
    bad = sp.keys.select { |s| sp[s].is_a?(Hash) && fields.any? { |f| sp[s][f].is_a?(Array) && sp[s][f].any? { |a| ER_ONLY.include?(a) } } }
    return 0 if bad.empty?
    rk = KIF::Rand
    types = {}
    sp.each { |s, f| types[s] = f if f.is_a?(Hash) && f.key?(:@type1) }
    # What a new roll gives now (same seed, fixed pool): the replacements
    fresh = rk.with_seed(:abilities) { rk.roll_abilities(types) } rescue {}
    n = 0
    bad.each do |s|
      fields.each do |f|
        list = sp[s][f]
        next unless list.is_a?(Array)
        list.each_index do |i|
          next unless ER_ONLY.include?(list[i])
          new = (fresh[s] && fresh[s][f] || [])[i]
          new ||= (rk.orig(s, f) || [])[i] rescue nil
          new = nil if new && ER_ONLY.include?(new)
          list[i] = new
          n += 1
        end
        list.compact!
      end
    end
    # the randomizer module off: its data stays out of the game data
    rk.apply_data if !defined?(KIF::Modules) || KIF::Modules.active?("C-RAND-01_Randomizer")
    return n
  end

  def self.repair_stored_abilities
    list = []
    list.concat($Trainer.party) if $Trainer && $Trainer.party
    if $PokemonGlobal.respond_to?(:daycare) && $PokemonGlobal.daycare.is_a?(Array)
      $PokemonGlobal.daycare.each { |slot| list << slot[0] if slot.is_a?(Array) }
    end
    if $PokemonStorage
      $PokemonStorage.maxBoxes.times do |b|
        $PokemonStorage.maxPokemon(b).times { |i| list << $PokemonStorage[b, i] }
      end rescue nil
    end
    n = 0
    list.each do |pk|
      next unless pk.is_a?(Pokemon) && ER_ONLY.include?(pk.instance_variable_get(:@ability))
      pk.instance_variable_set(:@ability, nil)   # PIF picks its own from ability_index again
      n += 1
    end
    return n
  end
end

if defined?(Game) && Game.respond_to?(:load)
  module Game
    class << self
      alias kifer_load load unless method_defined?(:kifer_load)
      def load(*args)
        ret = kifer_load(*args)
        begin
          KIFER.repair_save
        rescue StandardError => e
          KIFER.log("save repair failed: #{e.class}: #{e.message}")
        end
        return ret
      end
    end
  end
end
