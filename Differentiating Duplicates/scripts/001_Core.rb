#===============================================================================
# Differentiating Duplicates - core: settings, logging, ability hooks
#===============================================================================
module DiffDupes
  CATEGORY      = "Differentiating Duplicates"
  SET_MOVES     = :dd_moves      # 0 = Off, 1 = On
  SET_ABILITIES = :dd_abilities  # 0 = Off, 1 = On
  SET_KIFER     = :dd_kifer      # 0 = KIF:ER wins, 1 = this mod wins

  # Abilities KIF: Elite Redux also changes (its "Ability versions" setting)
  KIFER_CONFLICTS = [:VITALSPIRIT, :SOLIDROCK, :TURBOBLAZE, :TERAVOLT, :KEENEYE,
                     :ILLUMINATE, :WHITESMOKE, :AIRLOCK, :BATTLEARMOR, :MINUS]

  def self.log(msg)
    KIF.log("[DD] #{msg}") if defined?(::KIF) && ::KIF.respond_to?(:log)
  rescue StandardError
  end

  def self.setting(key, default)
    return default unless defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:get)
    v = ::ModSettingsMenu.get(key)
    return default if v.nil?
    return 1 if v == true
    return 0 if v == false
    return v
  rescue StandardError
    return default
  end

  def self.moves_on?
    return setting(SET_MOVES, 1) == 1
  end

  def self.abilities_on?
    return setting(SET_ABILITIES, 1) == 1
  end

  # KIF: Elite Redux is loaded, on, and using its own ability versions
  def self.kifer_versions_on?
    return false unless defined?(::KIFER::LOADED)
    return ::KIFER::ERVersions.on? if defined?(::KIFER::ERVersions) && ::KIFER::ERVersions.respond_to?(:on?)
    return ::KIFER.enabled? && ::KIFER.er_versions?
  rescue StandardError
    return false
  end

  # Moves Elite Redux changes too; KIF-ER codes them its way (KIF-ER chat, 2026-10-18)
  KIFER_MOVE_CONFLICTS = [:DETECT, :MEDITATE, :SHARPEN, :SOFTBOILED, :MILKDRINK]

  # KIF: Elite Redux's "Moves" setting is on (0.5.0+)
  def self.kifer_moves_on?
    return false unless defined?(::KIFER::Moves)
    m = ::KIFER::Moves
    return (m.respond_to?(:wanted?) && m.wanted?) || (m.respond_to?(:applied?) && m.applied?) ? true : false
  rescue StandardError
    return false
  end

  def self.kifer_move?(id)
    return true if KIFER_MOVE_CONFLICTS.include?(id)
    m = ::KIFER::Moves
    # er_known? (KIF-ER 2c26aaf+) ignores yields; ready? would ask our own yield check back
    return m.er_known?(id) ? true : false if m.respond_to?(:er_known?)
    return m.respond_to?(:ready?) && m.ready?(id) ? true : false
  rescue StandardError
    return false
  end

  # Whether this mod's version of a move is used right now. With KIF-ER's
  # Moves on and "KIF:ER wins", Elite Redux's version wins for its moves.
  def self.move_on?(id)
    return false unless moves_on?
    return true unless kifer_moves_on? && kifer_move?(id)
    return setting(SET_KIFER, 0) == 1
  end

  # Every move this mod changes
  MOVES = [:DETECT, :ACIDARMOR, :BARRIER, :MEDITATE, :SHARPEN, :SOFTBOILED, :MILKDRINK,
           :SLACKOFF, :HEALORDER, :MORNINGSUN, :MOONLIGHT, :SPIDERWEB, :BLOCK, :WITHDRAW]

  # KIF-ER's yield check: "This mod wins" keeps PIF's data and code for our moves
  def self.kifer_yield?(id)
    return MOVES.include?(id) && moves_on? && setting(SET_KIFER, 0) == 1
  end

  def self.register_kifer_yield
    return if @kifer_yield_done || !defined?(::KIFER::Moves) || !::KIFER::Moves.respond_to?(:register_yield)
    @kifer_yield_done = true
    ::KIFER::Moves.register_yield(CATEGORY) { |id| DiffDupes.kifer_yield?(id) }
    when_settings_ready do
      next unless ::ModSettingsMenu.respond_to?(:register_on_change)
      [SET_KIFER, SET_MOVES].each { |k| ::ModSettingsMenu.register_on_change(k) { |_v| ::KIFER::Moves.refresh } }
    end
  end

  # Whether this mod's version of an ability is used right now
  def self.ability_on?(id)
    return false unless abilities_on?
    return true unless KIFER_CONFLICTS.include?(id) && kifer_versions_on?
    return setting(SET_KIFER, 0) == 1
  end

  #-----------------------------------------------------------------------------
  # Settings (Options > Modules > Mod Settings)
  #-----------------------------------------------------------------------------
  def self.when_settings_ready(&blk)
    if defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:register_enum)
      blk.call
    else
      $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
      $MOD_SETTINGS_PENDING_REGISTRATIONS << blk
    end
  rescue StandardError => e
    log("Settings not registered: #{e.class}: #{e.message}")
  end

  def self.register_settings
    ::ModSettingsMenu.register_enum(SET_MOVES, "Changed moves", ["Off", "On"], 1,
      "Duplicate moves like Detect and Soft-Boiled get their own twist.", CATEGORY)
    ::ModSettingsMenu.register_enum(SET_ABILITIES, "Changed abilities", ["Off", "On"], 1,
      "Duplicate abilities like Solid Rock and Insomnia get their own twist.", CATEGORY)
  end

  # Only shown when KIF: Elite Redux is installed
  def self.register_kifer_setting
    return if @kifer_setting_done || !defined?(::KIFER::LOADED)
    @kifer_setting_done = true
    when_settings_ready do
      ::ModSettingsMenu.register_enum(SET_KIFER, "KIF:ER conflicts", ["KIF:ER wins", "This mod wins"], 0,
        "Which version is used when KIF: Elite Redux also changes a move or ability.", CATEGORY)
    end
  end

  #-----------------------------------------------------------------------------
  # Ability handler hooks. The handler PIF/KIF has when this mod loads is kept
  # as "pif"; the hooks go in after every mod has loaded, so they sit outside
  # KIF-ER's own wrappers ("cur"). While this mod's version is on, the block
  # runs (it can call pif); otherwise cur runs unchanged.
  #   DiffDupes.ability_hook(:DamageCalcTargetAbility, :SOLIDROCK) { |pif, cur, *args| ... }
  #   with no block: this mod's version is PIF's (cancels KIF-ER's version)
  #-----------------------------------------------------------------------------
  HOOKS = []

  def self.ability_hook(hash_name, id, gate = id, &blk)
    hash = ::BattleHandlers.const_get(hash_name)
    pif = hash[id]
    # Loaded after KIF-ER (any load order works): the handler here may be
    # KIF-ER's wrapper, so PIF's version is reached through it with KIF-ER's
    # Elite Redux versions off for that call
    pif = as_pif_proc(pif) if pif && defined?(::KIFER::LOADED)
    HOOKS << [hash_name, id, gate, pif, blk]
  rescue StandardError => e
    log("Hook #{hash_name}/#{id} skipped: #{e.class}: #{e.message}")
  end

  def self.as_pif_proc(handler)
    return proc { |*args| DiffDupes.as_pif { handler.call(*args) } }
  end

  def self.as_pif
    @as_pif = (@as_pif || 0) + 1
    return yield
  ensure
    @as_pif -= 1
  end

  def self.as_pif?
    return (@as_pif || 0) > 0
  end

  # KIF-ER's ER-version wrappers ask KIFER::ERVersions.on?: false inside as_pif
  def self.patch_kifer_versions
    return if @kifer_patched || !defined?(::KIFER::ERVersions) || !::KIFER::ERVersions.respond_to?(:on?)
    @kifer_patched = true
    ::KIFER::ERVersions.singleton_class.prepend(Module.new do
      def on?(*args)
        return false if ::DiffDupes.as_pif?
        super
      end
    end)
  end

  def self.install_hooks
    return if @hooks_installed
    @hooks_installed = true
    patch_kifer_versions
    HOOKS.each do |hash_name, id, gate, pif, blk|
      hash = ::BattleHandlers.const_get(hash_name)
      cur  = hash[id]
      hash.add(id, proc { |*args|
        if DiffDupes.ability_on?(gate)
          if blk
            blk.call(pif, cur, *args)
          else
            pif ? pif.call(*args) : nil
          end
        else
          cur ? cur.call(*args) : nil
        end
      })
    end
    log("#{HOOKS.length} ability hooks installed")
  end

  def self.after_all_mods
    register_kifer_setting
    register_kifer_yield
    install_hooks
  end
end

DiffDupes.when_settings_ready { DiffDupes.register_settings }

if defined?(::KIF::DataLoad) && ::KIF::DataLoad.respond_to?(:after_load_all)
  ::KIF::DataLoad.after_load_all("Differentiating Duplicates") { DiffDupes.after_all_mods }
else
  DiffDupes.log("KIF::DataLoad missing: hooks installed now (load this mod after KIF-ER)")
  # shortcut: without KIF's after-load hook, KIF-ER may wrap ours; KIF always has it
  DiffDupes.after_all_mods
end

class PokeBattle_Battler
  # Per-Pokemon state for this mod; cleared when a Pokemon enters the field
  attr_accessor :dd_detect, :dd_acid_turn, :dd_withdraw_turn, :dd_web, :dd_block,
                :dd_tangle_turn, :dd_qm_by, :dd_ws_blocked

  def dd_reset
    @dd_detect = false
    @dd_acid_turn = nil
    @dd_withdraw_turn = nil
    @dd_web = false
    @dd_block = false
    @dd_tangle_turn = nil
    @dd_qm_by = nil
    @dd_ws_blocked = false
  end
end
