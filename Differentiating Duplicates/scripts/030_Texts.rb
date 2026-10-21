#===============================================================================
# Differentiating Duplicates - ability and move descriptions
# (KIF::AbilityText KIF 0.21.59+, KIF::MoveText KIF 0.21.63+)
# Registered while the matching setting is On. Priority follows whose version
# runs: 20 (above KIF-ER's 10) while this mod's version is used, 5 (below it)
# while KIF: Elite Redux's is ("KIF:ER conflicts" = KIF:ER wins).
#===============================================================================
module DiffDupes
  module Texts
    OWNER = "Differentiating Duplicates"
    WIN   = 20
    LOSE  = 5

    def self.sync(api_name, data, texts, on, gate)
      return unless defined?(::KIF) && ::KIF.const_defined?(api_name)
      api = ::KIF.const_get(api_name)
      return unless api.respond_to?(:register)
      api.unregister(OWNER)
      return unless on
      texts.each do |id, text|
        next unless data.exists?(id)
        api.register(OWNER, id, description: text, priority: -> { gate.call(id) ? WIN : LOSE })
      end
    rescue StandardError => e
      DiffDupes.log("#{api_name} texts not registered: #{e.class}: #{e.message}")
    end
  end

  module AbilityText
    OWNER = Texts::OWNER
    TEXTS = {
      :VITALSPIRIT    => "Can't sleep. Sleep moves raise its Speed instead.",
      :INSOMNIA       => "Can't sleep. Sleep moves raise its Sp. Atk instead.",
      :SOLIDROCK      => "Weakens super-effective hits. 4x hits do only 2x.",
      :TURBOBLAZE     => "Ignores Abilities. Fire moves do 10% more damage.",
      :TERAVOLT       => "Ignores Abilities. Electric moves do 10% more damage.",
      :KEENEYE        => "Accuracy can't drop. Psychic moves can hit Dark types.",
      :ILLUMINATE     => "Every light move on the field does 20% more damage.",
      :PUREPOWER      => "Raises the Pokémon's Attack. It can't be confused.",
      :WHITESMOKE     => "Stops stat drops. A foe that tries loses accuracy.",
      :AIRLOCK        => "Eliminates weather effects and ends any Tailwind.",
      :BATTLEARMOR    => "Stops crits and contact damage like Rough Skin.",
      :TANGLINGHAIR   => "Contact slows the attacker and traps it next turn.",
      :MINUS          => "Ups Speed if another Pokémon has Plus or Minus.",
      :QUEENLYMAJESTY => "Blocks foes' priority moves and lowers their Attack.",
      :IRONBARBS      => "Steel-type barbs hurt attackers that touch it."
    }

    def self.sync
      Texts.sync(:AbilityText, GameData::Ability, TEXTS, DiffDupes.abilities_on?, ->(id) { DiffDupes.ability_on?(id) })
    end
  end

  # Cody's approved drafts (2026-10-19)
  module MoveText
    TEXTS = {
      :DETECT     => "Lets the user dodge attacks that turn. Moves that can't miss still hit.",
      :ACIDARMOR  => "Sharply raises Defense. Foes that touch the user this turn may be poisoned.",
      :BARRIER    => "Sharply raises the Defense of the user or an ally.",
      :MEDITATE   => "The user meditates to raise its Attack and Sp. Def stats.",
      :SHARPEN    => "Raises Attack and makes critical hits more likely.",
      :SOFTBOILED => "Restores half the max HP of the user or an ally.",
      :MILKDRINK  => "Restores half the max HP of the user or an ally.",
      :SLACKOFF   => "Restores half the user's max HP and shakes off drowsiness.",
      :HEALORDER  => "Restores half the user's max HP and a quarter of its allies'.",
      :MORNINGSUN => "Restores HP. Heals more by day when there's no weather.",
      :MOONLIGHT  => "Restores HP. Heals more at night when there's no weather.",
      :SPIDERWEB  => "Traps the target. The web stays even after the user leaves.",
      :BLOCK      => "Traps the target. It can't escape with U-turn or Baton Pass either.",
      :WITHDRAW   => "Raises Defense. The user can't take critical hits that turn."
    }

    def self.sync
      Texts.sync(:MoveText, GameData::Move, TEXTS, DiffDupes.moves_on?, ->(id) { DiffDupes.move_on?(id) })
    end
  end
end

# Every data load (KIF re-installs its text wrappers then) and when a setting changes
if defined?(::KIF::DataLoad)
  ::KIF::DataLoad.after_load_all("Differentiating Duplicates: texts") do
    DiffDupes::AbilityText.sync
    DiffDupes::MoveText.sync
  end
end
DiffDupes.when_settings_ready do
  if ::ModSettingsMenu.respond_to?(:register_on_change)
    ::ModSettingsMenu.register_on_change(DiffDupes::SET_ABILITIES) { |_v| DiffDupes::AbilityText.sync }
    ::ModSettingsMenu.register_on_change(DiffDupes::SET_MOVES) { |_v| DiffDupes::MoveText.sync }
  end
end
