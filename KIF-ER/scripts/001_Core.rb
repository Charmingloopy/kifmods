#===============================================================================
# KIF: Elite Redux – core: settings, logging, data lookups
#===============================================================================
module KIFER
  CATEGORY        = "KIF: Elite Redux"
  SETTING_ON      = :kifer_enabled       # 0 = Off, 1 = On
  SETTING_VERSION = :kifer_er_versions   # 0 = Elite Redux, 1 = PIF (050_ER_PIF_Versions.rb)
  SETTING_DMGLOG  = :kifer_damage_log    # 0 = Off, 1 = On (writes to KIF_log.txt)

  def self.log(msg)
    KIF.log("[KIF-ER] #{msg}") if defined?(::KIF) && ::KIF.respond_to?(:log)
  rescue StandardError
  end

  #-----------------------------------------------------------------------------
  # Settings (Options > Modules > Mod Settings)
  #-----------------------------------------------------------------------------
  def self.register_settings
    ::ModSettingsMenu.register_enum(SETTING_ON, "Innates", ["Off", "On"], 1,
      "Innates (3 extra abilities) and Elite Redux choice abilities.", CATEGORY)
    ::ModSettingsMenu.register_enum(SETTING_VERSION, "Ability versions", ["Elite Redux", "PIF"], 0,
      "Which version of an ability's effect is used when both games have it.", CATEGORY)
    ::ModSettingsMenu.register_enum(SETTING_DMGLOG, "Damage log", ["Off", "On"], 0,
      "For testing: writes each hit's damage with and without innates to KIF_log.txt.", CATEGORY)
  end

  # New battle mechanics the abilities need (fog, frostbite, fear...). One
  # setting turns them all on or off (Cody, 2026-10-13: "just one toggle";
  # one setting per mechanic later if players ask). Off = abilities that
  # would cause them don't.
  #   KIFER.feature(:fog, "Fog", "...")  -> records the mechanic
  #   KIFER.feature_on?(:fog)            -> true/false
  FEATURES = {}
  SETTING_FEATURES = :kifer_new_features

  def self.feature_key(_id = nil)
    return SETTING_FEATURES
  end

  def self.register_feature_setting
    return if @feature_setting_done
    reg = proc do
      ::ModSettingsMenu.register_enum(SETTING_FEATURES, "New battle effects", ["Off", "On"], 1,
        "Elite Redux battle mechanics like fog, frostbite and fear.", CATEGORY)
    end
    if defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:register_enum)
      reg.call
    else
      $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
      $MOD_SETTINGS_PENDING_REGISTRATIONS << reg
    end
    @feature_setting_done = true
  rescue StandardError => e
    log("New battle effects setting not registered: #{e.class}: #{e.message}")
  end

  def self.feature(id, name, desc)
    FEATURES[id] = [name, desc]
    register_feature_setting
  end

  # Each part has its own setting; Innates (enabled?) is innates and choice
  # abilities only (Cody, 2026-10-19: KIF:ER is a conversion mod)
  def self.feature_on?(_id = nil)
    v = setting(SETTING_FEATURES, 1)
    return v == 1 || v == true
  end

  def self.setting(key, default)
    return default unless defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:get)
    v = ::ModSettingsMenu.get(key)
    return v.nil? ? default : v
  rescue StandardError
    return default
  end

  def self.enabled?
    v = setting(SETTING_ON, 1)
    return v == 1 || v == true
  end

  def self.damage_log?
    return setting(SETTING_DMGLOG, 0) == 1
  end

  def self.er_versions?
    return setting(SETTING_VERSION, 0) == 0
  end

  #-----------------------------------------------------------------------------
  # Data
  #-----------------------------------------------------------------------------
  def self.entry(species_id)
    return SPECIES_DATA[species_id]
  end

  # Innates a non-fusion species has (Symbols, ER order)
  def self.species_innates(species_id)
    e = entry(species_id)
    return e ? e[:innates].dup : []
  end

  # The 6 innates a fusion picks its 3 from (head's 3, then body's 3). An
  # innate both have is in twice: copies of the same ability stack (Cody,
  # 2026-10-13: two Thick Fats = 1/4 damage, three = 1/8)
  def self.fusion_pool(head_id, body_id)
    return species_innates(head_id) + species_innates(body_id)
  end
end

begin
  if defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:register_enum)
    KIFER.register_settings
  else
    # The settings API isn't there yet (another settings mod loads later)
    $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
    $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { KIFER.register_settings }
  end
rescue StandardError => e
  KIFER.log("Settings not registered: #{e.class}: #{e.message}")
end
