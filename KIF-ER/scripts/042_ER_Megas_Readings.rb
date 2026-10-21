#===============================================================================
# KIF: Elite Redux – Megas abilities coded from Cody's readings (2026-10-20,
# Nextdex texts). After 031 (frostbite) and 033 so their hooks exist.
#   Backup Power  – revives at 25% HP on the spot, once per battle, when it
#                   faints in Electric Terrain
#   Cryostasis    – Cryomancy; while it is frostbitten, its moves have a 10%
#                   flinch chance (as Stench; Serene Grace doubles it)
#   Drakelp Head  – the first hit it takes after switching in does x0.65, then
#                   the attacker's Attack drops by 1
#   Flame Coat    – end of each turn: non-Fire foes lose 1/8 of their max HP
#   Polarity      – while it is on the field, every Pokemon on its side
#                   (itself too) gets x1.3 on its own highest stat
#   Rejection     – on switch-in, Quash on every foe that still has a move to
#                   use this round (they move last); nothing otherwise
#   Talon Trap    – a foe that hits it with contact gets trapped as Snap Trap
#                   (Wrap's turns and damage): 50%, 100% on that foe's first
#                   turn out
#===============================================================================
KIFER.er_code(:BACKUPPOWER, :CRYOSTASIS, :DRAKELPHEAD, :FLAMECOAT,
              :POLARITY, :REJECTION, :TALONTRAP)
KIFER.counts_as(:CRYOMANCY, :CRYOSTASIS)

module KIFER
  module MegaReadings
    def self.polarity?(b, stat)
      return false if !b || b.fainted?
      return false if !b.hasActiveAbility?(:POLARITY) &&
                      !b.battle.battlers.any? { |a| a && !a.fainted? && a.index != b.index && !a.opposes?(b.index) && a.hasActiveAbility?(:POLARITY) }
      return KIFER::BatchD.highest_stat(b) == stat
    end

    def self.cryostasis_chance(move, user, target)
      return 0 if !user.hasActiveAbility?(:CRYOSTASIS) || !user.frostbitten? || move.flinchingMove?
      return 0 if target.hasActiveAbility?(:SHIELDDUST) && !user.battle.moldBreaker
      ret = 10
      ret *= 2 if user.hasActiveAbility?(:SERENEGRACE) || user.pbOwnSide.effects[PBEffects::Rainbow] > 0
      return ret
    end

    def self.backup_power?(b)
      return false unless b.battle.field.terrain == :Electric && b.hasActiveAbility?(:BACKUPPOWER, true)
      used = (b.battle.instance_variable_get(:@kifer_mrd_backup) || [])
      return !used.any? { |p| p.equal?(b.pokemon) }
    end
  end
end

class PokeBattle_Battler
  alias kifer_mrd_pbFaint pbFaint unless method_defined?(:kifer_mrd_pbFaint)
  def pbFaint(showMessage = true)
    if fainted? && !@fainted && KIFER::MegaReadings.backup_power?(self)
      used = (@battle.instance_variable_get(:@kifer_mrd_backup) || [])
      @battle.instance_variable_set(:@kifer_mrd_backup, used + [@pokemon])
      self.hp = [@totalhp / 4, 1].max
      if !fainted?   # PIF's "no reviving" option keeps it at 0
        @battle.pbShowAbilitySplash(self, false, true, KIFER.ability_name(:BACKUPPOWER))
        @battle.pbDisplay(_INTL("{1} was revived by its backup power!", pbThis))
        @battle.pbHideAbilitySplash(self)
        return
      end
    end
    return kifer_mrd_pbFaint(showMessage)
  end

  # Polarity: own highest stat x1.3 (Speed here; Attack / Defense in the move)
  alias kifer_mrd_pbSpeed pbSpeed unless method_defined?(:kifer_mrd_pbSpeed)
  def pbSpeed
    ret = kifer_mrd_pbSpeed
    ret = (ret * 1.3).round if KIFER::MegaReadings.polarity?(self, :SPEED)
    return ret
  end

  alias kifer_mrd_pbInitEffects pbInitEffects unless method_defined?(:kifer_mrd_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_mrd_pbInitEffects(batonPass)
    @kifer_mrd_drakelp = false
  end
end

BattleHandlers::DamageCalcTargetAbility.add(:DRAKELPHEAD,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.65 if !target.instance_variable_get(:@kifer_mrd_drakelp)
  }
)

BattleHandlers::TargetAbilityOnHit.add(:DRAKELPHEAD,
  proc { |ability, user, target, move, battle|
    next if target.instance_variable_get(:@kifer_mrd_drakelp)
    target.instance_variable_set(:@kifer_mrd_drakelp, true)
    next if user.fainted? || !user.pbCanLowerStatStage?(:ATTACK, target)
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    user.pbLowerStatStage(:ATTACK, 1, target)
    battle.pbHideAbilitySplash(target)
  }
)

BattleHandlers::EOREffectAbility.add(:FLAMECOAT,
  proc { |ability, battler, battle|
    battle.eachOtherSideBattler(battler.index) do |b|
      next if b.fainted? || b.pbHasType?(:FIRE) || !b.takesIndirectDamage?
      battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
      oldHP = b.hp
      b.pbReduceHP([b.totalhp / 8, 1].max)
      battle.pbDisplay(_INTL("{1} is hurt by the flame coat!", b.pbThis))
      battle.pbHideAbilitySplash(battler)
      b.pbItemHPHealCheck
      b.pbAbilitiesOnDamageTaken(oldHP)
      b.pbFaint if b.fainted?
    end
  }
)

class PokeBattle_Move
  # Cryostasis: King's Rock / Stench don't stack with it (PIF: one source)
  alias kifer_mrd_pbFlinchChance pbFlinchChance unless method_defined?(:kifer_mrd_pbFlinchChance)
  def pbFlinchChance(user, target)
    ret = kifer_mrd_pbFlinchChance(user, target)
    return [ret, KIFER::MegaReadings.cryostasis_chance(self, user, target)].max
  end

  # Polarity: Attack / Sp. Atk for the user's side, Defense / Sp. Def for the
  # target's. shortcut: goes by the move's category, so Psyshock / Body Press /
  # Foul Play use the usual stat for this check; fine unless Cody sees it
  alias kifer_mrd_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_mrd_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    kifer_mrd_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    phys = physicalMove?(type)
    multipliers[:attack_multiplier] *= 1.3 if KIFER::MegaReadings.polarity?(user, phys ? :ATTACK : :SPECIAL_ATTACK)
    if !@battle.moldBreaker && KIFER::MegaReadings.polarity?(target, phys ? :DEFENSE : :SPECIAL_DEFENSE)
      multipliers[:defense_multiplier] *= 1.3
    end
  end
end

# Rejection: Quash (PIF's Quash order) on every foe still waiting to move
BattleHandlers::AbilityOnSwitchIn.add(:REJECTION,
  proc { |ability, battler, battle|
    foes = []
    battle.eachOtherSideBattler(battler.index) do |b|
      next if b.fainted? || b.movedThisRound?
      ch = battle.choices[b.index]
      next if !ch || ch[0] != :UseMove
      foes << b
    end
    next if foes.empty?
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    foes.each do |b|
      top = battle.battlers.map { |x| x ? x.effects[PBEffects::Quash] : 0 }.max
      b.effects[PBEffects::Quash] = top + 1
      battle.pbDisplay(_INTL("{1}'s move was postponed!", b.pbThis))
    end
    battle.pbHideAbilitySplash(battler)
  }
)

# Talon Trap: a foe touching it is caught as by Snap Trap
BattleHandlers::TargetAbilityOnHit.add(:TALONTRAP,
  proc { |ability, user, target, move, battle|
    next if user.fainted? || user.index == target.index || !move.pbContactMove?(user)
    next if user.effects[PBEffects::Trapping] > 0
    next if user.turnCount > 1 && battle.pbRandom(2) != 0   # first turn out: 100%
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    if target.hasActiveItem?(:GRIPCLAW)
      user.effects[PBEffects::Trapping] = (Settings::MECHANICS_GENERATION >= 5) ? 8 : 6
    else
      user.effects[PBEffects::Trapping] = 5 + battle.pbRandom(2)
    end
    user.effects[PBEffects::TrappingMove] = GameData::Move.exists?(:SNAPTRAP) ? :SNAPTRAP : :WRAP
    user.effects[PBEffects::TrappingUser] = target.index
    battle.pbDisplay(_INTL("{1} got caught in a snap trap!", user.pbThis))
    battle.pbHideAbilitySplash(target)
  }
)

