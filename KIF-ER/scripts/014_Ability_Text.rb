#===============================================================================
# KIF: Elite Redux – ability names and descriptions through KIF's ability text
# API (KIF::AbilityText, KIF 0.21.59+). Registering ER's texts there, instead
# of only answering them ourselves, lets another mod (Differentiating
# Duplicates) show its own text when the player picks its version: the
# highest priority wins. On older KIF nothing here runs and the mod's own
# GameData::Ability aliases (008, 050) give ER's texts as before.
#
#   - ER-only abilities: ER name and short text, always.
#   - PIF abilities: ER's name while the mod is on; ER's
#     short text for the abilities 050 changes, while Ability versions is
#     Elite Redux.
#===============================================================================
module KIFER
  module AbilityTexts
    OWNER    = "KIF: Elite Redux"
    PRIORITY = 10   # another mod's version wins with a higher one
    @ours = {}      # ability id => the description registered by this mod

    module_function

    def api?
      return defined?(::KIF::AbilityText) ? true : false
    end

    def sync
      return unless api? && defined?(GameData::Ability::DATA) && !GameData::Ability::DATA.empty?
      ::KIF::AbilityText.unregister(OWNER)
      @ours = {}
      on    = KIFER.enabled? || (defined?(KIFER::ERVersions) && KIFER::ERVersions.on?)
      vers  = defined?(KIFER::ERVersions) && KIFER::ERVersions.on?
      KIFER::ABILITY_TEXT.each do |id, t|
        a = GameData::Ability.try_get(id)
        next if !a
        if a.instance_variable_get(:@kifer_er)
          reg(id, t[:name], t[:short])
        elsif on
          name = t[:name]   # also when it matches PIF's: a lower-priority mod mustn't win it
          desc = (vers && KIFER::ERVersions::CHANGED.include?(id) && t[:short] && !t[:short].empty?) ? t[:short] : nil
          reg(id, name, desc) if name || desc
        end
      end
    rescue StandardError => e
      KIFER.log("ability texts: #{e.class}: #{e.message}")
    end

    def reg(id, name, desc)
      ::KIF::AbilityText.register(OWNER, id, name: name, description: desc, priority: PRIORITY)
      @ours[id] = desc
    end

    # another mod's description won for this ability (nil when ours or none)
    def other_description(id)
      return nil unless api?
      d = ::KIF::AbilityText.description(id)
      return (d.nil? || d == @ours[id]) ? nil : d
    end
  end
end

if defined?(KIF::DataLoad)
  KIF::DataLoad.after_load_all("KIF-ER: ability texts") { KIFER::AbilityTexts.sync }
end
if defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:register_on_change)
  [KIFER::SETTING_ON, KIFER::SETTING_VERSION].each do |k|
    ::ModSettingsMenu.register_on_change(k) { |_v| KIFER::AbilityTexts.sync }
  end
end
