#===============================================================================
# KIF: Elite Redux – Elite Redux's fog weather, and the abilities that need it
#   Mechanics follow Elite Redux 2.65. Its public C source has no fog, so the
#   2.65 in-game texts (Low Visibility describes fog itself) and ER's wiki are
#   used.
#
#   Fog (a battle weather, :Fog):
#     - lasts 8 turns, 12 if the Pokemon that set it holds a Smoke Ball
#     - end of each turn: stat boosts of Pokemon that aren't Ghost or Psychic
#       drop by 1 (each raised stat)
#     - Ghost and Psychic Pokemon take 20% less damage from moves
#     - Weather Ball becomes a Ghost move (power doubles as in any weather)
#     - Synthesis, Moonlight and Morning Sun heal 1/4 instead of 1/2 (PIF
#       already does this for any weather other than sun)
#     - every Curse is the Ghost-type Curse
#     - Ominous Wind does double damage
#     - Harvest doesn't work
#     - a type added by Trick-or-Treat doesn't count for the Ghost effects
#     - like other weathers: a new weather replaces it, primal weathers block
#       it, Cloud Nine and Air Lock cancel its effects
#     - looks: no common animation; EBDX already draws its own fog overlay
#       for this weather
#     - only starts while the "New battle effects" setting is On
#
#   Low Visibility  – on entry: sets fog
#   Smokey Maneuvers – in fog: moves aimed at it have 25% less accuracy
#   Echolocation    – in fog: its moves never miss and do 20% more damage
#   Ectoplasm       – in fog: its higher attacking stat x1.5 (raw stats; a tie
#                     is Sp. Atk)
#   Ethereal Rush   – in fog: Speed x1.5
#   Rest in Peace   – in fog: heals 1/8 of its max HP at the end of each turn
#   Surprise!       – in fog: when a foe is about to use a priority move, it
#                     hits that foe with a 40 power Astonish first and makes
#                     it flinch
#   Shallow Grave   – fainting in fog (or on the turn fog ends): revives at
#                     1/4 HP when its side sends out its next Pokemon. Once
#                     per battle.
#
#   Not coded yet: none.
#   Not added (ER has them, PIF doesn't): Eerie Fog, Eerie Spell, Vexing
#   Void, Spectral Flame, Revival Blessing, Castform's fog form.
#===============================================================================
KIFER.feature(:fog, "Fog", "Elite Redux's fog weather (Low Visibility and similar abilities).")
KIFER.er_code(:LOWVISIBILITY, :SMOKEYMANEUVERS, :ECHOLOCATION, :ECTOPLASM,
                :ETHEREALRUSH, :RESTINPEACE, :SURPRISE, :SHALLOWGRAVE)

if defined?(GameData::BattleWeather) && !GameData::BattleWeather.exists?(:Fog)
  GameData::BattleWeather.register({
    :id   => :Fog,
    :name => _INTL("Fog")
  })
end

module KIFER
  module Fog
    TURNS            = 8
    TURNS_SMOKE_BALL = 12
    PRIMAL           = [:HarshSun, :HeavyRain, :StrongWinds]

    @surprising = false
    @starts     = 0   # times fog was set (for the log and the test kit)

    def self.starts
      return @starts
    end

    def self.active?(battle)
      return battle.pbWeather == :Fog
    end

    # Ghost or Psychic by its own types (not a type added by Trick-or-Treat)
    def self.spectral?(battler)
      t = battler.pbTypes(false)
      return t.include?(:GHOST) || t.include?(:PSYCHIC)
    end

    # Fog is on, or ended this turn (Shallow Grave)
    def self.this_turn?(battle)
      return true if active?(battle)
      return battle.kifer_fog_ended == battle.turnCount
    end

    def self.duration(user)
      return TURNS_SMOKE_BALL if user && user.itemActive? && user.item == :SMOKEBALL
      return TURNS
    end

    # An ability sets fog (Low Visibility)
    def self.start(battler, battle, ability)
      return false unless KIFER.feature_on?(:fog)
      return false if PRIMAL.include?(battle.field.weather)
      return false if battle.field.weather == :Fog
      battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
      battle.pbStartWeather(battler, :Fog, true)   # hides the splash
      return true
    end

    def self.started
      @starts += 1
    end

    # End of turn: raised stats of non-Ghost/Psychic Pokemon drop by 1
    def self.drain_boosts(battle, priority)
      priority.each do |b|
        next if b.fainted? || spectral?(b)
        raised = b.stages.keys.select { |s| b.stages[s] > 0 }
        next if raised.empty?
        raised.each { |s| b.stages[s] -= 1 }
        battle.pbCommonAnimation("StatDown", b)
        battle.pbDisplay(_INTL("The fog weakened {1}'s stat boosts!", b.pbThis(true)))
      end
    end

    #---------------------------------------------------------------------------
    # Shallow Grave
    #---------------------------------------------------------------------------
    def self.mark_grave(battler)
      battle = battler.battle
      return unless this_turn?(battle)
      found = battler.hasActiveAbility?(:SHALLOWGRAVE, true)
      battler.kifer_clear_inline if battler.respond_to?(:kifer_clear_inline)
      return unless found
      pkmn = battler.pokemon
      return if !pkmn || battle.kifer_fog_used_graves.any? { |p| p.equal?(pkmn) }
      battle.kifer_fog_used_graves << pkmn
      battle.kifer_fog_graves << pkmn
    end

    # After its side sends a Pokemon out
    def self.raise_graves(battle, idxBattler)
      graves = battle.kifer_fog_graves
      return if graves.empty?
      party = battle.pbParty(idxBattler)
      graves.dup.each do |pkmn|
        next unless party.any? { |p| p.equal?(pkmn) }
        graves.delete(pkmn)
        next unless pkmn.fainted?
        pkmn.hp = [pkmn.totalhp / 4, 1].max
        next if pkmn.fainted?   # PIF's "no reviving" option keeps it fainted
        pkmn.status = :NONE
        battle.pbDisplay(_INTL("{1} rose from its shallow grave!", pkmn.name))
      end
    end

    #---------------------------------------------------------------------------
    # Surprise!
    #---------------------------------------------------------------------------
    def self.surprise(attacker, choice)
      return if @surprising
      battle = attacker.battle
      return unless active?(battle)
      return if choice[0] != :UseMove || !choice[2]
      pri = choice[4]
      return unless pri.is_a?(Numeric) && pri > 0
      foes = []
      battle.eachOtherSideBattler(attacker.index) { |b| foes << b }
      foes.each do |b|
        break if attacker.fainted? || battle.decision > 0
        next if b.fainted?
        next unless b.hasActiveAbility?(:SURPRISE)
        oldOutrage = b.effects[PBEffects::Outrage]
        @surprising = true
        begin
          # 40 power (the text); splash, last-move values and priority by 025
          KIFER::BatchF.use_extra_move(b, :ASTONISH, attacker.index, 40, :SURPRISE)
        ensure
          @surprising = false
          b.effects[PBEffects::Outrage] = oldOutrage
        end
        ds = attacker.damageState
        if !attacker.fainted? && !ds.unaffected && !ds.missed && !ds.substitute && ds.hpLost.to_i > 0
          attacker.pbFlinch(b)
        end
        battle.pbJudge
      end
    end
  end
end

#-------------------------------------------------------------------------------
# The weather itself
#-------------------------------------------------------------------------------
class PokeBattle_Battle
  attr_writer :kifer_fog_ended

  def kifer_fog_ended
    return @kifer_fog_ended
  end

  def kifer_fog_graves
    return @kifer_fog_graves ||= []
  end

  def kifer_fog_used_graves
    return @kifer_fog_used_graves ||= []
  end

  alias kifer_fog_pbStartWeather pbStartWeather unless method_defined?(:kifer_fog_pbStartWeather)
  def pbStartWeather(user, newWeather, fixedDuration = false, showAnim = true)
    return kifer_fog_pbStartWeather(user, newWeather, fixedDuration, showAnim) if newWeather != :Fog
    return if @field.weather == :Fog
    kifer_fog_pbStartWeather(user, newWeather, fixedDuration, showAnim)
    return if @field.weather != :Fog
    @field.weatherDuration = KIFER::Fog.duration(user) if fixedDuration
    KIFER::Fog.started
    pbDisplay(_INTL("A deep fog rolled in!"))
  end

  alias kifer_fog_pbEORWeather pbEORWeather unless method_defined?(:kifer_fog_pbEORWeather)
  def pbEORWeather(priority)
    if @field.weather == :Fog && @field.weatherDuration == 1
      pbDisplay(_INTL("The fog lifted."))
      @kifer_fog_ended = @turnCount
    end
    kifer_fog_pbEORWeather(priority)
    KIFER::Fog.drain_boosts(self, priority) if KIFER::Fog.active?(self)
  end

  # Shallow Grave
  alias kifer_fog_pbRecallAndReplace pbRecallAndReplace unless method_defined?(:kifer_fog_pbRecallAndReplace)
  def pbRecallAndReplace(idxBattler, idxParty, randomReplacement = false, batonPass = false)
    kifer_fog_pbRecallAndReplace(idxBattler, idxParty, randomReplacement, batonPass)
    KIFER::Fog.raise_graves(self, idxBattler)
  end
end

class PokeBattle_Battler
  # Shallow Grave
  alias kifer_fog_pbFaint pbFaint unless method_defined?(:kifer_fog_pbFaint)
  def pbFaint(showMessage = true)
    if fainted? && !@fainted
      begin
        KIFER::Fog.mark_grave(self)
      rescue StandardError => e
        KIFER.log("Shallow Grave failed: #{e.class}: #{e.message}")
      end
    end
    kifer_fog_pbFaint(showMessage)
  end

  # Surprise!
  alias kifer_fog_pbProcessTurn pbProcessTurn unless method_defined?(:kifer_fog_pbProcessTurn)
  def pbProcessTurn(choice, tryFlee = true)
    KIFER::Fog.surprise(self, choice) if !fainted? && choice[0] == :UseMove
    return false if fainted? || @battle.decision > 0
    return kifer_fog_pbProcessTurn(choice, tryFlee)
  end
end

class PokeBattle_Move
  # Ghost and Psychic Pokemon take 20% less damage; Ominous Wind x2
  alias kifer_fog_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_fog_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    kifer_fog_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    if KIFER::Fog.active?(@battle)
      multipliers[:base_damage_multiplier] *= 2 if @id == :OMINOUSWIND
      multipliers[:final_damage_multiplier] *= 0.8 if KIFER::Fog.spectral?(target)
    end
  end
end

# Weather Ball is a Ghost move in fog
class PokeBattle_Move_087
  alias kifer_fog_pbBaseType pbBaseType unless method_defined?(:kifer_fog_pbBaseType)
  def pbBaseType(user)
    return :GHOST if KIFER::Fog.active?(@battle) && GameData::Type.exists?(:GHOST)
    return kifer_fog_pbBaseType(user)
  end
end

# Curse is always the Ghost-type Curse in fog
class PokeBattle_Move_10D
  def kifer_fog_ghost_curse?(user)
    return KIFER::Fog.active?(@battle) && !user.pbHasType?(:GHOST)
  end

  alias kifer_fog_pbTarget pbTarget unless method_defined?(:kifer_fog_pbTarget)
  def pbTarget(user)
    return GameData::Target.get(:NearFoe) if kifer_fog_ghost_curse?(user)
    return kifer_fog_pbTarget(user)
  end

  alias kifer_fog_pbMoveFailed? pbMoveFailed? unless method_defined?(:kifer_fog_pbMoveFailed?)
  def pbMoveFailed?(user, targets)
    return false if kifer_fog_ghost_curse?(user)
    return kifer_fog_pbMoveFailed?(user, targets)
  end

  alias kifer_fog_pbFailsAgainstTarget? pbFailsAgainstTarget? unless method_defined?(:kifer_fog_pbFailsAgainstTarget?)
  def pbFailsAgainstTarget?(user, target)
    if kifer_fog_ghost_curse?(user) && target.effects[PBEffects::Curse]
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return kifer_fog_pbFailsAgainstTarget?(user, target)
  end

  alias kifer_fog_pbEffectGeneral pbEffectGeneral unless method_defined?(:kifer_fog_pbEffectGeneral)
  def pbEffectGeneral(user)
    return if kifer_fog_ghost_curse?(user)
    kifer_fog_pbEffectGeneral(user)
  end

  alias kifer_fog_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_fog_pbEffectAgainstTarget)
  def pbEffectAgainstTarget(user, target)
    if kifer_fog_ghost_curse?(user)
      @battle.pbDisplay(_INTL("{1} cut its own HP and laid a curse on {2}!", user.pbThis, target.pbThis(true)))
      target.effects[PBEffects::Curse] = true
      user.pbReduceHP(user.totalhp / 2, false)
      user.pbItemHPHealCheck
      return
    end
    kifer_fog_pbEffectAgainstTarget(user, target)
  end
end

# Harvest doesn't work in fog
module KIFER
  module Fog
    HARVEST = BattleHandlers::EORGainItemAbility[:HARVEST] unless const_defined?(:HARVEST)
  end
end
if KIFER::Fog::HARVEST
  BattleHandlers::EORGainItemAbility.add(:HARVEST,
    proc { |ability, battler, battle|
      next if KIFER::Fog.active?(battle)
      KIFER::Fog::HARVEST.call(ability, battler, battle)
    }
  )
end

#-------------------------------------------------------------------------------
# Low Visibility – on entry: sets fog
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:LOWVISIBILITY,
  proc { |ability, battler, battle|
    KIFER::Fog.start(battler, battle, ability)
  }
)

#-------------------------------------------------------------------------------
# Smokey Maneuvers – in fog: moves aimed at it have 25% less accuracy
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcTargetAbility.add(:SMOKEYMANEUVERS,
  proc { |ability, mods, user, target, move, type|
    mods[:accuracy_multiplier] *= 0.75 if KIFER::Fog.active?(target.battle)
  }
)

#-------------------------------------------------------------------------------
# Echolocation – in fog: never misses, and its moves do 20% more damage
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcUserAbility.add(:ECHOLOCATION,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0 if KIFER::Fog.active?(user.battle)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:ECHOLOCATION,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 1.2 if KIFER::Fog.active?(user.battle)
  }
)

#-------------------------------------------------------------------------------
# Ectoplasm – in fog: its higher attacking stat x1.5
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:ECTOPLASM,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next unless KIFER::Fog.active?(user.battle)
    stat = (user.attack > user.spatk) ? :ATTACK : :SPECIAL_ATTACK
    if (stat == :ATTACK && move.physicalMove?(type)) ||
       (stat == :SPECIAL_ATTACK && move.specialMove?(type))
      mults[:attack_multiplier] *= 1.5
    end
  }
)

#-------------------------------------------------------------------------------
# Ethereal Rush – in fog: Speed x1.5
#-------------------------------------------------------------------------------
BattleHandlers::SpeedCalcAbility.add(:ETHEREALRUSH,
  proc { |ability, battler, mult|
    next mult * 1.5 if KIFER::Fog.active?(battler.battle)
  }
)

#-------------------------------------------------------------------------------
# Rest in Peace – in fog: heals 1/8 of its max HP at the end of each turn
#-------------------------------------------------------------------------------
BattleHandlers::EORWeatherAbility.add(:RESTINPEACE,
  proc { |ability, weather, battler, battle|
    next unless weather == :Fog
    next if !battler.canHeal?
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.pbRecoverHP(battler.totalhp / 8)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)
