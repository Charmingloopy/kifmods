#===============================================================================
# KIF: Elite Redux – Elite Redux moves and learnsets (phase 1)
#   Setting "Moves" (Off/On, default On). While Innates and Moves are On:
#   * PIF moves whose ER effect is PIF's ("ready" in data/er_moves.rb) use ER's
#     power, type, category, accuracy, PP, effect chance, target, priority,
#     flags and long description. A move whose ER effect isn't coded yet keeps
#     every PIF value (all or nothing per move).
#   * Species learn ER's level-up moves, and ER's tutor list decides what TMs
#     and tutors can teach. PIF egg moves stay. ER moves PIF lacks are left
#     out for now. Fusions combine head + body as usual.
#   * Change moves (party menu) also offers the species' ER tutor moves.
#   * Getting an HM also gives its field tool (ER lists drop many HMs, Cody
#     2026-10-18: "it's just an HM Slave"). A save with HMs gets them on load.
#   All in memory: the game data objects are changed in place and PIF's values
#   are put back when the setting (or Innates) goes Off. Nothing new is saved.
#   The KIF randomizer re-rolls its move changes from the lists in use.
#===============================================================================
module KIFER
  SETTING_MOVES = :kifer_moves   # 0 = Off, 1 = On

  module Moves
    FIELDS = { :power => :@base_damage, :type => :@type, :category => :@category,
               :accuracy => :@accuracy, :pp => :@total_pp, :chance => :@effect_chance,
               :target => :@target, :priority => :@priority, :flags => :@flags,
               :function_code => :@function_code }
    # move an HM (or TM) teaches => the PIF field tool that does its job
    # (012_Overworld/004_Overworld_FieldMoves.rb checks these items)
    HM_TOOLS = { :CUT => :MACHETE, :SURF => :SURFBOARD, :STRENGTH => :LEVER,
                 :WATERFALL => :JETPACK, :DIVE => :SCUBAGEAR, :ROCKCLIMB => :CLIMBINGGEAR,
                 :ROCKSMASH => :PICKAXE, :FLY => :TELEPORTER, :TELEPORT => :TELEPORTER,
                 :FLASH => :LANTERN }
    LEARN_FIELDS = [:@moves, :@tutor_moves]

    @applied = false   # ER values are in the game data now
    @data = nil        # the move data the PIF copies below belong to
    @pif_moves = {}    # move id => PIF values
    @pif_learn = {}    # species id => PIF [@moves, @tutor_moves] (the objects)
    @er_learn = nil    # species id => ER [@moves, @tutor_moves], PIF moves only
    @receiving = 0
    @queued = []

    def self.applied?; return @applied; end

    def self.wanted?
      return KIFER.setting(SETTING_MOVES, 1) == 1
    end

    # Moves whose ER effect the mod has coded (any file): ready even when the
    # data says not, with optional value overrides (e.g. :function_code)
    CODED = {}
    def self.coded(*ids, **over)
      ids.each do |id|
        CODED[id] = over
        set_move(id, true) if @applied   # files loading after the swap still take effect
      end
    end

    def self.ready?(id)
      return er_known?(id) && !yields?(id)
    end

    # KIF-ER has an ER version of this move (whether or not another mod's wins)
    def self.er_known?(id)
      e = KIFER::MOVES[id]
      return false unless e
      return e[:ready] || CODED.key?(id)
    end

    #---------------------------------------------------------------------------
    # Another mod's version of a move: while a provider answers true for a move,
    # KIF-ER keeps PIF's data and code for it (DD's "This mod wins").
    #   KIFER::Moves.register_yield("My Mod") { |id| my_version_wins?(id) }
    # When the answer can change (a setting), call KIFER::Moves.refresh after.
    #---------------------------------------------------------------------------
    @yield_providers = []

    def self.register_yield(owner, &block)
      @yield_providers.reject! { |o, _| o == owner }
      @yield_providers << [owner, block] if block
      refresh
      return nil
    end

    def self.unregister_yield(owner)
      @yield_providers.reject! { |o, _| o == owner }
      refresh
      return nil
    end

    def self.yields?(id)
      return false if @yield_providers.empty?
      @yield_providers.each do |owner, block|
        begin
          return true if block.call(id)
        rescue StandardError => e
          KIFER.log("Moves: yield check from #{owner} failed: #{e.class}: #{e.message}")
        end
      end
      return false
    end

    def self.refresh
      set_moves(true) if @applied
      KIFER::MoveTexts.sync if defined?(KIFER::MoveTexts)
    end

    # ER values for a move, with the coded overrides on top
    def self.er_values(id)
      e = KIFER::MOVES[id]
      o = CODED[id]
      return (o.nil? || o.empty?) ? e : e.merge(o)
    end

    def self.register_setting
      ::ModSettingsMenu.register_enum(SETTING_MOVES, "Moves", ["Off", "On"], 1,
        "Elite Redux move power, accuracy, PP and learnsets.", CATEGORY)
      if ::ModSettingsMenu.respond_to?(:register_on_change)
        [SETTING_MOVES, SETTING_ON].each { |k| ::ModSettingsMenu.register_on_change(k) { |_v| KIFER::Moves.sync } }
      end
    end

    # Puts the game data in the state the settings ask for. Cheap when nothing
    # changed; also called at battle start and before Change moves, in case a
    # settings menu doesn't report changes.
    def self.sync
      return unless defined?(GameData::Move::DATA) && !GameData::Move::DATA.empty?
      KIFER::NewMoves.register if defined?(KIFER::NewMoves)   # before the learnsets are built
      fresh = !GameData::Move::DATA.equal?(@data)
      want = wanted?
      return if !fresh && want == @applied
      if fresh   # data (re)loaded: the objects hold PIF's values
        @data = GameData::Move::DATA
        @pif_moves = {}
        @pif_learn = {}
        @er_learn = nil
        @applied = false
        unless want
          KIFER::MoveTexts.sync if defined?(KIFER::MoveTexts)   # 065
          return
        end
      end
      set_moves(want)
      @applied = want
      set_learnsets(want)
      give_tools if want
      KIFER::MoveTexts.sync if defined?(KIFER::MoveTexts)   # 065
    rescue StandardError => e
      KIFER.log("Moves: data swap failed: #{e.class}: #{e.message}")
    end

    def self.set_moves(on)
      KIFER::MOVES.each_key { |id| set_move(id, on) }
    end

    def self.set_move(id, on)
      return unless er_known?(id)
      on = false if on && yields?(id)   # another mod's version: PIF's data
      e = er_values(id)
      m = GameData::Move::DATA[id] or return
      @pif_moves[id] ||= FIELDS.map { |_k, iv| m.instance_variable_get(iv) }
      if on
        FIELDS.each { |k, iv| m.instance_variable_set(iv, e[k]) if e.key?(k) }   # data has no :function_code; only coded overrides set it
      else
        FIELDS.each_with_index { |(_k, iv), i| m.instance_variable_set(iv, @pif_moves[id][i]) }
      end
    end

    PP_FIELD = FIELDS.keys.index(:pp)

    # A move's maximum PP without the mod (nil: same as now)
    def self.pif_total_pp(move)
      return nil unless @applied || move.instance_variable_get(:@kifer_id)   # 064's moves: also with Moves Off
      id = move.instance_variable_get(:@id)   # an ER-only move's PIF stand-in (064)
      v = @pif_moves[id] ? @pif_moves[id][PP_FIELD] : (move.instance_variable_get(:@kifer_id) && GameData::Move.try_get(id)&.total_pp)
      return nil unless v.is_a?(Integer)
      return v + v * move.ppup / 5
    end

    # Saves keep PP at most PIF's maximum, so a save loads right without the
    # mod; the ER number is put back once the save is written
    def self.with_pif_pp
      lowered = []
      # 064's ER moves are capped with Moves Off too; PIF moves only change while applied
      mons = []
      mons.concat($Trainer.party) if $Trainer && $Trainer.respond_to?(:party)
      if $PokemonStorage && $PokemonStorage.respond_to?(:maxBoxes)
        $PokemonStorage.maxBoxes.times do |b|
          $PokemonStorage.maxPokemon(b).times { |i| mons << $PokemonStorage[b, i] }
        end
      end
      # shortcut: Day Care Pokemon keep the ER number, upgrade if it ever matters
      mons.compact.each do |pk|
        pk.moves.each do |m|
          t = pif_total_pp(m)
          raw = m.instance_variable_get(:@pp)
          next unless t && raw.is_a?(Integer) && raw > t
          lowered << [m, raw]
          m.instance_variable_set(:@pp, t)
        end
      end
      return yield
    ensure
      lowered.each { |m, raw| m.instance_variable_set(:@pp, raw) }
    end

    def self.er_learnsets
      @er_learn ||= begin
        known = KIFER::MOVES
        # ER-only moves: the ones in the game (064)
        ok = proc { |m| known.key?(m) || (GameData::Move::DATA.key?(m) && KIFER::ER_ONLY_MOVES.key?(m)) }
        h = {}
        KIFER::LEARNSETS.each do |sp, (lv, tu)|
          h[sp] = [lv.select { |_l, m| ok.call(m) }, tu.select { |m| ok.call(m) }]
        end
        h
      end
    end

    def self.rand_on?
      return defined?(KIF::Rand) && KIF::Rand.respond_to?(:apply_data) && KIF::Rand.instance_variable_get(:@orig)
    end

    # The KIF randomizer keeps its own copy of the species data: take its
    # changes off, swap the lists, let it copy the new ones and re-apply
    def self.set_learnsets(on)
      rand = rand_on?
      KIF::Rand.apply_data({}) if rand
      er = er_learnsets
      KIFER::LEARNSETS.each_key do |id|
        sp = GameData::Species::DATA[id] or next
        @pif_learn[id] ||= LEARN_FIELDS.map { |f| sp.instance_variable_get(f) }
        vals = on ? er[id] : @pif_learn[id]
        LEARN_FIELDS.each_with_index { |f, i| sp.instance_variable_set(f, vals[i]) }
      end
      if rand
        KIF::Rand.instance_variable_set(:@orig, nil)
        KIF::Rand.originals   # copied here: inside apply_data the copy would lose its record of what it wrote
        g = $PokemonGlobal
        if g && g.respond_to?(:kif_rand) && g.kif_rand[:species] &&
           (!defined?(KIF::Modules) || KIF::Modules.active?("C-RAND-01_Randomizer"))
          KIF::Rand.apply_data
        end
      end
      KIF::Perf.bump_token if defined?(KIF::Perf)   # cached fusion species rebuild
    end

    # The randomizer's saved move changes were rolled from the lists in use
    # then; roll them again (same seed) from the lists in use now
    def self.rand_changes
      rk = KIF::Rand
      sp = (rk.data[:species] rescue nil)
      return nil unless sp.is_a?(Hash)
      keys = [:@moves, :@egg_moves, :@tutor_moves]
      return nil unless sp.any? { |_s, f| f.is_a?(Hash) && keys.any? { |k| f.key?(k) } }
      key = [sp.object_id, sp.length, rk.originals.object_id, @applied]
      return @rand_cache[1] if @rand_cache && @rand_cache[0] == key
      types = {}
      sp.each { |s, f| types[s] = f if f.is_a?(Hash) && f.key?(:@type1) }
      fresh = rk.with_seed(:moves) { rk.roll_moves(types) }
      out = {}
      sp.each do |s, f|
        next out[s] = f unless f.is_a?(Hash) && fresh[s]
        f2 = f.dup
        keys.each { |k| f2[k] = fresh[s][k] if f.key?(k) && fresh[s].key?(k) }
        out[s] = f2
      end
      @rand_cache = [key, out]
      return out
    end

    # Change moves: the ER tutor moves of the species (head + body)
    def self.tutor_moves_for(pkmn)
      return [] unless @applied && pkmn && !pkmn.egg? && !pkmn.shadowPokemon?
      return Array(pkmn.species_data.tutor_moves).uniq.select { |m| GameData::Move.exists?(m) }
    end

    #---------------------------------------------------------------------------
    # HMs give their field tool
    #---------------------------------------------------------------------------
    def self.tool_for(item)
      it = GameData::Item.try_get(item)
      return nil unless it && it.is_machine?
      tool = HM_TOOLS[it.move]
      return (tool && GameData::Item.exists?(tool)) ? tool : nil
    end

    # Returns the tool given, or nil
    def self.give_tool(bag, item)
      return nil unless @applied && bag
      tool = tool_for(item)
      return nil unless tool && bag.pbQuantity(tool) <= 0
      return nil unless bag.kifer_mv_pbStoreItem(tool, 1)
      return tool
    end

    def self.hm_received(bag, item)
      tool = give_tool(bag, item) or return
      @queued << tool
      flush if @receiving == 0
    end

    def self.flush
      list = @queued
      @queued = []
      list.each { |t| pbMessage(_INTL("You also got the {1}!", GameData::Item.get(t).name)) }
    end

    # pbItemBall / pbReceiveItem: the tool's message comes after the HM's
    def self.receiving
      @receiving += 1
      begin
        return yield
      ensure
        @receiving -= 1
        flush if @receiving == 0 && !@queued.empty?
      end
    end

    # A save that already has HMs: tools without a message
    def self.give_tools
      bag = $PokemonBag
      return unless @applied && bag && bag.respond_to?(:pbQuantity)
      GameData::Item.each do |it|
        next unless it.is_machine? && HM_TOOLS.key?(it.move) && bag.pbQuantity(it.id) > 0
        give_tool(bag, it.id)
      end
    rescue StandardError => e
      KIFER.log("Moves: field tools not given: #{e.class}: #{e.message}")
    end
  end
end

# ER long texts while Moves is On (ready moves only)
module GameData
  class Move
    alias kifer_mv_description description unless method_defined?(:kifer_mv_description)
    def description
      if KIFER::Moves.applied?
        e = KIFER::MOVES[@id]
        return e[:desc] if e && KIFER::Moves.ready?(id) && !e[:desc].empty?
      end
      return kifer_mv_description
    end
  end
end

class PokeBattle_Battle
  alias kifer_mv_initialize initialize unless method_defined?(:kifer_mv_initialize)
  def initialize(*args)
    KIFER::Moves.sync
    kifer_mv_initialize(*args)
  end
end

class PokemonBag
  alias kifer_mv_pbStoreItem pbStoreItem unless method_defined?(:kifer_mv_pbStoreItem)
  def pbStoreItem(item, qty = 1)
    ret = kifer_mv_pbStoreItem(item, qty)
    KIFER::Moves.hm_received(self, item) if ret
    return ret
  end
end

class Object
  alias kifer_mv_pbItemBall pbItemBall unless method_defined?(:kifer_mv_pbItemBall) || private_method_defined?(:kifer_mv_pbItemBall)
  def pbItemBall(*args)
    return KIFER::Moves.receiving { kifer_mv_pbItemBall(*args) }
  end

  alias kifer_mv_pbReceiveItem pbReceiveItem unless method_defined?(:kifer_mv_pbReceiveItem) || private_method_defined?(:kifer_mv_pbReceiveItem)
  def pbReceiveItem(*args)
    return KIFER::Moves.receiving { kifer_mv_pbReceiveItem(*args) }
  end
end

if defined?(KIF::MoveLearning) && KIF::MoveLearning.respond_to?(:change_moves_list)
  module KIF
    module MoveLearning
      class << self
        alias kifer_mv_change_moves_list change_moves_list unless method_defined?(:kifer_mv_change_moves_list)
        def change_moves_list(pkmn)
          KIFER::Moves.sync
          list = kifer_mv_change_moves_list(pkmn)
          extra = KIFER::Moves.tutor_moves_for(pkmn)
          return list if extra.empty?
          known = pkmn.moves.map { |m| m.id }
          return list | (extra - known)
        end
      end
    end
  end
end

if defined?(KIF::Rand) && KIF::Rand.respond_to?(:apply_data)
  module KIF
    module Rand
      class << self
        alias kifer_mv_apply_data apply_data unless method_defined?(:kifer_mv_apply_data)
        def apply_data(changes = nil)
          changes = (KIFER::Moves.rand_changes rescue nil) if changes.nil?
          return kifer_mv_apply_data(changes)
        end
      end
    end
  end
end

if defined?(Game) && Game.respond_to?(:save)
  module Game
    class << self
      alias kifer_mv_save save unless method_defined?(:kifer_mv_save)
      def save(*args, **kw)
        return KIFER::Moves.with_pif_pp { kifer_mv_save(*args, **kw) }
      end
    end
  end
end

if defined?(Game) && Game.respond_to?(:load)
  module Game
    class << self
      alias kifer_mv_load load unless method_defined?(:kifer_mv_load)
      def load(*args)
        ret = kifer_mv_load(*args)
        KIFER::Moves.sync
        KIFER::Moves.give_tools
        return ret
      end
    end
  end
end

begin
  if defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:register_enum)
    KIFER::Moves.register_setting
  else
    $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
    $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { KIFER::Moves.register_setting }
  end
rescue StandardError => e
  KIFER.log("Moves setting not registered: #{e.class}: #{e.message}")
end

KIF::DataLoad.after_load_all("KIF-ER: Elite Redux moves") { KIFER::Moves.sync } if defined?(KIF::DataLoad)
KIFER::Moves.sync

#-------------------------------------------------------------------------------
# ER can give a move fewer PP than PIF: a move known from before shows (and
# uses) at most its current maximum.
#-------------------------------------------------------------------------------
class Pokemon
  class Move
    alias kifer_raw_pp pp unless method_defined?(:kifer_raw_pp)
    def pp
      v = kifer_raw_pp
      return v unless v.is_a?(Integer)
      t = total_pp
      return v > t ? t : v
    rescue StandardError
      return kifer_raw_pp
    end
  end
end
