#===============================================================================
# KIF: Elite Redux – rows on KIF's Battle Info "Abilities" page (KIF 0.21.47+)
#   KIF::BattleInfo.register_abilities(:kif_er) lists each battler's innates
#   (and a dual fusion's Ability 2) under its main ability.
#   - Your own Pokémon: always shown.
#   - A foe's innate: "???" until the battle shows its pop-up (the notes
#     037_Ability_Sites.rb keeps for KIF's effectiveness hints).
#   - "Worked this battle": its handler changed something, showed a message or
#     a pop-up (004_Triggers.rb notes it; not while the battle AI is only
#     estimating).
#   On older KIF without Battle Info nothing here runs.
#===============================================================================
module KIFER
  module BattleInfo
    def self.own?(battler)
      return KIF::BattleInfo.own?(battler) if KIF::BattleInfo.respond_to?(:own?)
      return !battler.opposes?
    end

    def self.rows(battle, battler)
      return [] if !KIFER.enabled? || !battler || !battler.pokemon
      ids = battler.respond_to?(:innate_ids) ? battler.innate_ids : nil
      return [] if !ids.is_a?(Array) || ids.empty?
      mine = own?(battler)
      shown = KIFER::AbilitySites.respond_to?(:shown_innates) ? KIFER::AbilitySites.shown_innates(battle, battler) : []
      c2 = (KIFER.dual?(battler.pokemon) ? KIFER.chosen_ability2(battler.pokemon) : nil) rescue nil
      ids.each_with_index.map do |id, i|
        seen = shown.include?(id)
        { :label  => (i == 0 && c2 && id == c2) ? "ABILITY 2" : "INNATE",
          :ability => id,
          :known  => mine || seen,
          :worked => seen || KIFER.worked?(battle, battler, id) }
      end
    end

    # KIF names the main ability with battler.abilityName; an innate's name
    # left over from an earlier check must not show there
    def self.without_inline(battler)
      saved = battler.respond_to?(:kifer_inline) ? battler.kifer_inline : nil
      battler.kifer_clear_inline if saved
      return yield
    ensure
      battler.instance_variable_set(:@kifer_inline, saved) if saved
    end
  end
end

if defined?(KIF::BattleInfo) && KIF::BattleInfo.respond_to?(:register_abilities)
  KIF::BattleInfo.register_abilities(:kif_er) do |battle, battler|
    KIFER::BattleInfo.rows(battle, battler)
  end

  if KIF::BattleInfo.respond_to?(:ability_entries)
    class << KIF::BattleInfo
      alias kifer_bi_ability_entries ability_entries unless method_defined?(:kifer_bi_ability_entries)
      def ability_entries(battle, battler)
        return KIFER::BattleInfo.without_inline(battler) { kifer_bi_ability_entries(battle, battler) }
      end
    end
  end

  # Messages shown while an innate's handler runs mean it worked
  class PokeBattle_Battle
    [:pbDisplay, :pbDisplayPaused, :pbDisplayBrief, :pbShowAbilitySplash].each do |m|
      next unless method_defined?(m)
      orig = :"kifer_bi_#{m}"
      next if method_defined?(orig)
      alias_method orig, m
      define_method(m) do |*args, &blk|
        @kifer_msgs = @kifer_msgs.to_i + 1
        send(orig, *args, &blk)
      end
    end
  end

  # The battle AI calls the same handlers to estimate: not "worked"
  class PokeBattle_AI
    [:pbDefaultChooseEnemyCommand, :pbDefaultChooseNewEnemy, :pbChooseMoves,
     :pbEnemyShouldWithdraw?, :pbChooseBestNewEnemy].each do |m|
      next unless method_defined?(m)
      orig = :"kifer_bi_#{m.to_s.sub('?', '_q')}"
      next if method_defined?(orig)
      alias_method orig, m
      define_method(m) do |*args, &blk|
        KIFER.while_ai { send(orig, *args, &blk) }
      end
    end
  end
end

# An innate's name noted by an inline check must not outlive the turn
class PokeBattle_Battle
  alias kifer_bi_pbCommandPhase pbCommandPhase unless method_defined?(:kifer_bi_pbCommandPhase)
  def pbCommandPhase
    eachBattler { |b| b.kifer_clear_inline if b.respond_to?(:kifer_clear_inline) }
    kifer_bi_pbCommandPhase
  end
end
