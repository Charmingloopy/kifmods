#===============================================================================
# KIF: Elite Redux – Elite Redux's fear, and the abilities that cause it
#   Mechanics follow Elite Redux 2.65 (its in-game texts and changelog; fear is
#   newer than the public C source).
#
#   Fear (ER 2.1+): "traps the target for 2 turns and they take 50% more
#   damage. If forced out by moves like Whirlwind, the target loses Fear."
#     * A volatile effect, not a major status: it sits on the battler next to
#       burn/poison etc. and ends when it leaves the field (any switch, Roar,
#       Whirlwind, Dragon Tail, Baton Pass, U-turn, fainting).
#     * Lasts 2 turns: the turn it starts and the next one, counted down at the
#       end of each turn (ER's timer for "2 turns", as for Throat Chop).
#     * Can't switch out or flee while afraid. As with every other trap, Ghost
#       types and Shed Shell still get out, and Run Away / Smoke Ball still run.
#     * Attacks hit it for x1.5 (not its own confusion hits).
#     * No type or ability is immune to it in ER's texts. A Pokemon that is
#       already afraid can't be made afraid again until it ends.
#     * Shown by messages only (PIF shows no volatile effects on the data box).
#   Uses the "New battle effects" setting (Off = these abilities don't cause fear;
#   fear already on a Pokemon runs out as normal).
#
#   Spectralize – Normal moves become Ghost. Ghost-type user: its Ghost moves
#                 have a 10% fear chance. Otherwise: Ghost moves get STAB
#   Fearmonger  – on entry: Intimidate and Scare (foes' Attack and Sp. Atk -1);
#                 its contact moves have a 10% fear chance
#   Grass Flute – its sound moves inflict fear on hit
#
#   Other files can use KIFER::Fear.inflict(target, user, ability) to cause
#   fear and KIFER::Fear.afraid?(battler) to check it.
#===============================================================================
KIFER.feature(:fear, "Fear",
  "The Pokemon can't switch out and takes 1.5x damage for 2 turns.")

KIFER.er_code(:SPECTRALIZE, :FEARMONGER, :GRASSFLUTE)

module KIFER
  module Fear
    TURNS = 2

    def self.afraid?(battler)
      return false if !battler || battler.fainted?
      return battler.kifer_fear > 0
    end

    # Fear can start: setting on, target in battle, not afraid already
    def self.can_fear?(target)
      return false if !KIFER.feature_on?(:fear)
      return false if !target || target.fainted?
      return false if target.kifer_fear > 0
      return true
    end

    # Makes target afraid. With an ability, its splash is shown on user.
    def self.inflict(target, user = nil, ability = nil)
      return false if !can_fear?(target)
      battle = target.battle
      battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability)) if user && ability
      target.kifer_fear = TURNS
      battle.pbDisplay(_INTL("{1} became afraid!", target.pbThis))
      battle.pbHideAbilitySplash(user) if user && ability
      return true
    end

    # A chance effect of its attack (Shield Dust stops it)
    def self.on_hit(user, target, ability, chance)
      return false if target.fainted? || user.equal?(target)
      return false if target.hasActiveAbility?(:SHIELDDUST) && !user.battle.moldBreaker
      return false if !can_fear?(target)
      return false if chance < 100 && user.battle.pbRandom(100) >= chance
      return inflict(target, user, ability)
    end

    # Trapping exceptions every trap has (Shed Shell, Ghost type)
    def self.escapes?(battler, battle)
      if battler.abilityActive? &&
         BattleHandlers.triggerCertainSwitchingUserAbility(battler.ability, battler, battle)
        return true
      end
      if battler.itemActive? &&
         BattleHandlers.triggerCertainSwitchingUserItem(battler.item, battler, battle)
        return true
      end
      return true if Settings::MORE_TYPE_EFFECTS && battler.pbHasType?(:GHOST)
      return false
    end
  end
end

#-------------------------------------------------------------------------------
# Fear on the battler: cleared when a Pokemon comes in, counted down at the end
# of each turn
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  attr_writer :kifer_fear

  def kifer_fear
    return @kifer_fear || 0
  end

  alias kifer_fear_pbInitEffects pbInitEffects unless method_defined?(:kifer_fear_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_fear_pbInitEffects(batonPass)
    @kifer_fear = 0
  end
end

class PokeBattle_Battle
  alias kifer_fear_pbEndOfRoundPhase pbEndOfRoundPhase unless method_defined?(:kifer_fear_pbEndOfRoundPhase)
  def pbEndOfRoundPhase
    kifer_fear_pbEndOfRoundPhase
    return if @decision > 0
    eachBattler do |b|
      next if b.kifer_fear <= 0
      b.kifer_fear -= 1
      pbDisplay(_INTL("{1} is no longer afraid.", b.pbThis)) if b.kifer_fear == 0
    end
  end

  # Afraid: can't switch out
  alias kifer_fear_pbCanSwitch? pbCanSwitch? unless method_defined?(:kifer_fear_pbCanSwitch?)
  def pbCanSwitch?(idxBattler, idxParty = -1, partyScene = nil)
    return false if !kifer_fear_pbCanSwitch?(idxBattler, idxParty, partyScene)
    battler = @battlers[idxBattler]
    return true if @kifer_fear_forced   # Roar, Whirlwind, Red Card... force it out anyway
    if KIFER::Fear.afraid?(battler) && !KIFER::Fear.escapes?(battler, self)
      partyScene.pbDisplay(_INTL("{1} is too afraid to switch out!", battler.pbThis)) if partyScene
      return false
    end
    return true
  end

  # PIF asks pbCanSwitch? before a forced (random) switch too; fear doesn't
  # stop that one. The Pokemon coming in starts with no fear (pbInitEffects).
  alias kifer_fear_pbGetReplacementPokemonIndex pbGetReplacementPokemonIndex unless method_defined?(:kifer_fear_pbGetReplacementPokemonIndex)
  def pbGetReplacementPokemonIndex(idxBattler, random = false)
    return kifer_fear_pbGetReplacementPokemonIndex(idxBattler, random) if !random
    old = @kifer_fear_forced
    @kifer_fear_forced = true
    begin
      return kifer_fear_pbGetReplacementPokemonIndex(idxBattler, random)
    ensure
      @kifer_fear_forced = old
    end
  end

  # Afraid: can't flee (Run Away and Smoke Ball still work)
  alias kifer_fear_pbCanRun? pbCanRun? unless method_defined?(:kifer_fear_pbCanRun?)
  def pbCanRun?(idxBattler)
    return false if !kifer_fear_pbCanRun?(idxBattler)
    battler = @battlers[idxBattler]
    return true if !KIFER::Fear.afraid?(battler)
    return true if Settings::MORE_TYPE_EFFECTS && battler.pbHasType?(:GHOST)
    return true if battler.abilityActive? && BattleHandlers.triggerRunFromBattleAbility(battler.ability, battler)
    return true if battler.itemActive? && BattleHandlers.triggerRunFromBattleItem(battler.item, battler)
    return false
  end

  alias kifer_fear_pbRun pbRun unless method_defined?(:kifer_fear_pbRun)
  def pbRun(idxBattler, duringBattle = false)
    battler = @battlers[idxBattler]
    if !duringBattle && !trainerBattle? && @canRun && battler && !battler.opposes? &&
       KIFER::Fear.afraid?(battler) && !($DEBUG && Input.press?(Input::CTRL)) &&
       !(Settings::MORE_TYPE_EFFECTS && battler.pbHasType?(:GHOST)) &&
       !(battler.abilityActive? && BattleHandlers.triggerRunFromBattleAbility(battler.ability, battler)) &&
       !(battler.itemActive? && BattleHandlers.triggerRunFromBattleItem(battler.item, battler))
      pbDisplayPaused(_INTL("You can't escape!"))
      return 0
    end
    return kifer_fear_pbRun(idxBattler, duringBattle)
  end
end

# Afraid: attacks hit it for x1.5
class PokeBattle_Move
  alias kifer_fear_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_fear_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    kifer_fear_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    return if defined?(PokeBattle_Confusion) && is_a?(PokeBattle_Confusion)
    multipliers[:final_damage_multiplier] *= 1.5 if KIFER::Fear.afraid?(target)
  end
end

#-------------------------------------------------------------------------------
# Spectralize – Normal moves become Ghost. A Ghost-type user's Ghost moves have
# a 10% chance to cause fear; any other user gets STAB on Ghost moves.
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.add(:SPECTRALIZE,
  proc { |ability, user, move, type|
    next type if type != :NORMAL || !GameData::Type.exists?(:GHOST)
    next :GHOST
  }
)

BattleHandlers::DamageCalcUserAbility.add(:SPECTRALIZE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :GHOST || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

BattleHandlers::UserAbilityOnHit.add(:SPECTRALIZE,
  proc { |ability, user, target, move, battle|
    next if move.calcType != :GHOST || !user.pbHasType?(:GHOST)
    KIFER::Fear.on_hit(user, target, ability, 10)
  }
)

#-------------------------------------------------------------------------------
# Fearmonger – on entry: Intimidate and Scare on the foes next to it (Attack
# and Sp. Atk -1; whatever blocks Intimidate or Scare blocks that part). Its
# contact moves have a 10% chance to cause fear.
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:FEARMONGER,
  proc { |ability, battler, battle|
    name = KIFER.ability_name(ability)
    battle.pbShowAbilitySplash(battler, false, true, name)
    battle.eachOtherSideBattler(battler.index) do |b|
      next if !b.near?(battler)
      b.pbLowerAttackStatStageIntimidate(battler)
      b.pbItemOnIntimidatedCheck
    end
    battle.eachOtherSideBattler(battler.index) do |b|
      next if !b.near?(battler) || b.fainted?
      if b.effects[PBEffects::Substitute] > 0
        battle.pbDisplay(_INTL("{1} is protected by its substitute!", b.pbThis))
        next
      end
      # Passed as Scare, so abilities that react to Scare do here too (ER
      # runs this part as Scare)
      b.pbLowerStatStageByAbility(:SPECIAL_ATTACK, 1, battler, false, false, KIFER.ability_name(:SCARE))
    end
    battle.pbHideAbilitySplash(battler)
  }
)

BattleHandlers::UserAbilityOnHit.add(:FEARMONGER,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    KIFER::Fear.on_hit(user, target, ability, 10)
  }
)

#-------------------------------------------------------------------------------
# Grass Flute – its sound moves cause fear on hit
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:GRASSFLUTE,
  proc { |ability, user, target, move, battle|
    next if !move.soundMove?
    KIFER::Fear.on_hit(user, target, ability, 100)
  }
)
