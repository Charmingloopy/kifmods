#===============================================================================
# Settings (Options > Modules > Mod Settings > Megas). Cody's design:
#   Mega mode:       Once per battle (default) / Permanent
#   Permanent limit: One per party / No limit (only used in Permanent)
#   Primal trigger:  Auto (on switch-in) / Manual (the Mega button)
# Trainers follow the same rules as the player.
#===============================================================================
module Megas
  CATEGORY       = "Megas"             unless defined?(CATEGORY)
  SETTING_MODE   = :megas_mode         unless defined?(SETTING_MODE)     # 0 Once per battle, 1 Permanent
  SETTING_LIMIT  = :megas_perm_limit   unless defined?(SETTING_LIMIT)    # 0 One per party, 1 No limit
  SETTING_PRIMAL = :megas_primal       unless defined?(SETTING_PRIMAL)   # 0 Auto, 1 Manual

  def self.setting(key)
    v = ::ModSettingsMenu.get(key) if defined?(::ModSettingsMenu)
    return v.is_a?(Integer) ? v : 0
  rescue StandardError
    return 0
  end

  def self.permanent?;     setting(SETTING_MODE) == 1;   end
  def self.one_per_party?; setting(SETTING_LIMIT) == 0;  end
  def self.manual_primal?; setting(SETTING_PRIMAL) == 1; end

  def self.register_settings
    resync = proc { |_v| Megas.sync($Trainer.party) if $Trainer }   # Mega-ness of the party follows the mode
    enum = lambda do |key, name, values, desc, on_change = nil|
      ::ModSettingsMenu.register(key, :name => name, :type => :enum, :values => values, :default => 0,
                                      :description => desc, :category => CATEGORY, :on_change => on_change)
    end
    enum.call(SETTING_MODE, "Mega mode", ["Once per battle", "Permanent"],
      "Once per battle: Mega Evolve with the Mega button. Permanent: always Mega while holding its stone.", resync)
    enum.call(SETTING_LIMIT, "Permanent limit", ["One per party", "No limit"],
      "Permanent mode: how many Pokemon in a party can be Mega at once.", resync)
    enum.call(SETTING_PRIMAL, "Primal trigger", ["Auto", "Manual"],
      "Auto: Kyogre and Groudon revert when sent out. Manual: use the Mega button.")
  end
end

if defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:register)
  Megas.register_settings
else
  $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
  $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { Megas.register_settings }
end
