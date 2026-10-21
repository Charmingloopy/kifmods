#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch K)
#   Mechanics follow Elite Redux's newest in-game texts.
#   "A + B" abilities use A's and B's code. Parts that other files check
#   inline (hasActiveAbility?) count for the whole ability here (PART_OF).
#
#   Good as Gold      – status moves aimed at it fail (not its own, not ones
#                       that hit every Pokemon on the field, like Perish Song)
#   Hardened Sheath   – its horn and drill moves raise its Attack by 1 after
#                       they hit (Mighty Horn's move list, 027)
#   Haste Makes Waste – Stall + Analytic: x0.7 damage taken before it moves;
#                       x1.3 when the target has already moved
#   Hungry Maws       – Strong Jaw (biting moves x1.3) + Jaws of Carnage
#   Hunter's Horn     – horn and drill moves x1.3; a KO heals 1/4 HP
#   Hydra             – Multi-Headed + Hubris
#   Hydro Circuit     – Electric moves x1.5; Water moves heal 1/4 of the
#                       damage they dealt
#   Immovable Object  – Impenetrable + Sturdy
#   Infernal Rage     – Fire moves x1.35, then recoil of 5% of the damage
#                       dealt (at least 1, never below 1 HP)
#   Intrepid Sword    – on entry: Attack +1
#   Jumpscare         – first entry in a battle: a 40 power Astonish at +3
#                       priority on a foe next to it, which flinches it
#   Know Your Place   – its contact hits make the target move last for 5
#                       turns (this one counts); no refresh while it lasts
#   Lucha Libre       – Dazzling + Defiant
#   Magma Eater       – Predator + Molten Down
#   Malediction       – its hits: 20% bleed, 10% curse (Ghost-type Curse)
#   Malodor           – hit by contact: the attacker's ability and innates
#                       are suppressed until it switches out (as Gastro Acid)
#   Marine Apex       – x1.5 damage to Water types + Infiltrator
#   Megabite          – biting moves use its Sp. Atk (still the target's
#                       Defense) and x1.3
#   Metallic Jaws     – Metallic + Primal Maw
#   Mucus Membrane    – takes x0.7 damage from attacks + Gooey
#   Mystic Blades     – Keen Edge moves become special while it uses them,
#                       and x1.3
#   No Turning Back   – the first time in a battle it drops below half HP:
#                       all stats +1 and it can't switch out or flee (Shed
#                       Shell, Eject Button and Ghost types still can)
#   Ominous Shroud    – Phantom + Shadow Shield
#   Overcast          – Low Visibility + Frosty Presence (Mist on entry)
#   Overclock         – Ground Shock + Overcharge
#   Parry             – takes x0.8 damage; hit by contact: a 20 power Mach
#                       Punch back once the attack is over
#   Peaceful Slumber  – Sweet Dreams + Self Sufficient
#   Permanence        – foes can't heal while it is in battle
#   Phobia            – 30% chance to cause Fear on contact, both ways
#   Power Outage      – its Electric moves x2 until it has used one; then it
#                       loses its Electric type until it switches out
#   Primal Maw        – biting moves hit twice, the 2nd hit at 40% (no flinch
#                       on the 2nd hit)
#   Purgatory         – Ghost moves x1.3, x1.8 at 1/3 HP or less
#   Queen's Mourning  – a stat drop on it or its ally (not a self drop):
#                       its Sp. Atk and Sp. Def +1 (each stat lowered counts)
#   Reaper's Embarce  – Tough Claws + Foul Energy (Dark moves x1.2, x1.5 at
#                       1/3 HP or less)
#
# Not coded yet:
#   Hollow Ice Zone   – needs the Ice Statue status, which the mod doesn't have
#   (Polarity: 042)
#===============================================================================
KIFER.er_code(:GOODASGOLD, :HARDENEDSHEATH, :HASTEMAKESWASTE, :HUNGRYMAWS, :HUNTERSHORN,
              :HYDRA, :HYDROCIRCUIT, :IMMOVABLEOBJECT, :INFERNALRAGE, :INTREPIDSWORD,
              :JUMPSCARE, :KNOWYOURPLACE, :LUCHALIBRE, :MAGMAEATER, :MALEDICTION,
              :MALODOR, :MARINEAPEX, :MEGABITE, :METALLICJAWS, :MUCUSMEMBRANE,
              :MYSTICBLADES, :NOTURNINGBACK, :OMINOUSSHROUD, :OVERCAST, :OVERCLOCK,
              :PARRY, :PEACEFULSLUMBER, :PERMANENCE, :PHOBIA, :POWEROUTAGE,
              :PRIMALMAW, :PURGATORY, :QUEENSMOURNING, :REAPERSEMBARCE)

module KIFER
  module BatchK
    # Abilities checked inline elsewhere, and the batch K abilities that have them
    PART_OF = {
      :MOLTENDOWN   => [:MAGMAEATER],
      :GROUNDSHOCK  => [:OVERCLOCK],
      :OVERCHARGE   => [:OVERCLOCK],
      :MULTIHEADED  => [:HYDRA],
      :IMPENETRABLE => [:IMMOVABLEOBJECT],
      :STURDY       => [:IMMOVABLEOBJECT],
      :INFILTRATOR  => [:MARINEAPEX],
      :SWEETDREAMS  => [:PEACEFULSLUMBER],
      :PRIMALMAW    => [:METALLICJAWS]
    }.freeze

    # Runs every listed ability's handler of hash for the one ability
    def self.both(hash, id, *parts)
      hash.add(id, proc { |*args|
        parts.each { |p| h = hash[p]; h.call(*args) if h }
        nil
      })
    end

    # true if this Pokemon already used its once-per-battle key; marks it used
    def self.once?(battle, key, battler)
      used = battle.instance_variable_get(:@kifer_k_once)
      used = battle.instance_variable_set(:@kifer_k_once, {}) if !used
      k = [key, battler.idxOwnSide, battler.pokemonIndex]
      return true if used[k]
      used[k] = true
      return false
    end

    # Damage its move dealt to the Pokemon it hit (not itself)
    def self.dealt(user, targets)
      dmg = 0
      targets.each { |b| dmg += b.damageState.totalHPLost if b.index != user.index && KIFER::BatchF.hit?(b) }
      return dmg
    end

    def self.heal(battler, amt, ability)
      return if amt <= 0 || !battler.canHeal?
      battle = battler.battle
      battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
      battler.pbRecoverHP([amt, 1].max)
      battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    end

    # Permanence: a foe on the field has it
    def self.no_heal?(battler)
      battle = battler.battle
      return false if !battle || !KIFER.on_field?(battle, :PERMANENCE)
      battle.eachOtherSideBattler(battler.index) { |b| return true if b.hasActiveAbility?(:PERMANENCE) }
      return false
    end

    def self.mystic_blades?(user, move)
      return move.physicalMove? && KIFER::SLICING_MOVES.include?(move.id) &&
             user.hasActiveAbility?(:MYSTICBLADES)
    end

    # Know Your Place: afflicted Pokemon move last this round (PIF's Quash)
    def self.mark_last(battle)
      battle.eachBattler do |b|
        next if b.kifer_k_kyp <= 0 || b.effects[PBEffects::Quash] > 0
        b.effects[PBEffects::Quash] = 1
      end
    end

    # Queen's Mourning: target's stat was lowered by user
    def self.mourn(target, user)
      return if !user || user.index == target.index
      battle = target.battle
      holders = [target]
      target.eachAlly { |b| holders << b }
      holders.each do |b|
        next if b.fainted? || !b.hasActiveAbility?(:QUEENSMOURNING)
        stats = [:SPECIAL_ATTACK, :SPECIAL_DEFENSE].select { |s| b.pbCanRaiseStatStage?(s, b) }
        next if stats.empty?
        battle.pbShowAbilitySplash(b, false, true, KIFER.ability_name(:QUEENSMOURNING))
        stats.each { |s| b.pbRaiseStatStage(s, 1, b) }
        battle.pbHideAbilitySplash(b)
      end
    end

    # Parry: counters wait until the attack that caused them is over
    @parrying = false

    def self.parry_add(battle, holder, foe, ability)
      q = battle.instance_variable_get(:@kifer_k_parry)
      q = battle.instance_variable_set(:@kifer_k_parry, []) if !q
      return if q.any? { |h, f, _a| h.equal?(holder) && f.equal?(foe) }
      q << [holder, foe, ability]
    end

    def self.parry_run(battle)
      q = battle.instance_variable_get(:@kifer_k_parry)
      return if !q || q.empty? || @parrying
      battle.instance_variable_set(:@kifer_k_parry, [])
      @parrying = true
      begin
        q.each do |holder, foe, ability|
          break if battle.decision > 0
          next if holder.fainted? || foe.fainted? || !battle.battlers[foe.index].equal?(foe)
          KIFER::BatchF.use_extra_move(holder, :MACHPUNCH, foe.index, 20, ability)
        end
      ensure
        @parrying = false
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Game method hooks
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  attr_writer :kifer_k_kyp

  def kifer_k_kyp
    return @kifer_k_kyp || 0
  end

  # A part (e.g. Sturdy) counts for the batch K ability that has it: 039's
  # one hasActiveAbility? wrapper reads PART_OF above

  alias kifer_k_pbInitEffects pbInitEffects unless method_defined?(:kifer_k_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_k_pbInitEffects(batonPass)
    @kifer_k_kyp    = 0
    @kifer_k_outage = false
  end

  # Power Outage: no Electric type once it has used an Electric move
  alias kifer_k_pbTypes pbTypes unless method_defined?(:kifer_k_pbTypes)
  def pbTypes(withType3 = false)
    ret = kifer_k_pbTypes(withType3)
    return ret if !@kifer_k_outage
    return ret - [:ELECTRIC]
  end

  # Permanence
  alias kifer_k_canHeal? canHeal? unless method_defined?(:kifer_k_canHeal?)
  def canHeal?
    return false if KIFER::BatchK.no_heal?(self)
    return kifer_k_canHeal?
  end

  alias kifer_k_pbRecoverHP pbRecoverHP unless method_defined?(:kifer_k_pbRecoverHP)
  def pbRecoverHP(amt, anim = true, anyAnim = true)
    return 0 if amt > 0 && KIFER::BatchK.no_heal?(self)
    return kifer_k_pbRecoverHP(amt, anim, anyAnim)
  end

  # Queen's Mourning (the stage is compared, so Contrary's raise doesn't count)
  alias kifer_k_pbLowerStatStage pbLowerStatStage unless method_defined?(:kifer_k_pbLowerStatStage)
  def pbLowerStatStage(stat, increment, user, showAnim = true, ignoreContrary = false)
    before = @stages[stat]
    ret = kifer_k_pbLowerStatStage(stat, increment, user, showAnim, ignoreContrary)
    KIFER::BatchK.mourn(self, user) if @stages[stat] < before
    return ret
  end

  alias kifer_k_pbLowerStatStageByCause pbLowerStatStageByCause unless method_defined?(:kifer_k_pbLowerStatStageByCause)
  def pbLowerStatStageByCause(stat, increment, user, cause, showAnim = true, ignoreContrary = false)
    before = @stages[stat]
    ret = kifer_k_pbLowerStatStageByCause(stat, increment, user, cause, showAnim, ignoreContrary)
    KIFER::BatchK.mourn(self, user) if @stages[stat] < before
    return ret
  end

  # Mystic Blades: the move is special while it is used. Parry: counters run
  # after the outermost move use.
  alias kifer_k_pbUseMove pbUseMove unless method_defined?(:kifer_k_pbUseMove)
  def pbUseMove(choice, specialUsage = false)
    move = choice[2]
    blades = move.is_a?(PokeBattle_Move) && KIFER::BatchK.mystic_blades?(self, move)
    move.instance_variable_set(:@category, 1) if blades
    depth = @battle.instance_variable_get(:@kifer_k_depth) || 0
    @battle.instance_variable_set(:@kifer_k_depth, depth + 1)
    begin
      kifer_k_pbUseMove(choice, specialUsage)
    ensure
      @battle.instance_variable_set(:@kifer_k_depth, depth)
      move.instance_variable_set(:@category, 0) if blades
    end
    KIFER::BatchK.parry_run(@battle) if depth == 0
  end
end

class PokeBattle_Battle
  alias kifer_k_pbAttackPhaseMoves pbAttackPhaseMoves unless method_defined?(:kifer_k_pbAttackPhaseMoves)
  def pbAttackPhaseMoves
    KIFER::BatchK.mark_last(self)
    kifer_k_pbAttackPhaseMoves
  end

  alias kifer_k_pbEndOfRoundPhase pbEndOfRoundPhase unless method_defined?(:kifer_k_pbEndOfRoundPhase)
  def pbEndOfRoundPhase
    kifer_k_pbEndOfRoundPhase
    eachBattler do |b|
      next if b.kifer_k_kyp <= 0
      b.kifer_k_kyp -= 1
      b.effects[PBEffects::Quash] = 0 if b.kifer_k_kyp == 0
    end
  end
end

class PokeBattle_Move
  # Megabite: Sp. Atk in place of Attack (025's Magical Fists flag, read by 008)
  alias kifer_k_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_k_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    unless physicalMove? && KIFER.bite_move?(self) && user.hasActiveAbility?(:MEGABITE)
      return kifer_k_pbGetAttackStats(user, target)
    end
    old = @kifer_f_magical
    @kifer_f_magical = true
    begin
      return kifer_k_pbGetAttackStats(user, target)
    ensure
      @kifer_f_magical = old
    end
  end

  # Primal Maw: biting moves hit twice (PIF's Parental Bond counter)
  alias kifer_k_pbNumHits pbNumHits unless method_defined?(:kifer_k_pbNumHits)
  def pbNumHits(user, targets)
    user.instance_variable_set(:@kifer_k_maw, false)
    n = kifer_k_pbNumHits(user, targets)
    if n == 1 && pbDamagingMove? && !chargingTurnMove? && targets.length == 1 &&
       KIFER.bite_move?(self) && user.hasActiveAbility?(:PRIMALMAW)
      user.effects[PBEffects::ParentalBond] = 3
      user.instance_variable_set(:@kifer_k_maw, true)
      user.instance_variable_set(:@kifer_e_nf2, true)   # 024: the 2nd hit can't flinch
      return 2
    end
    return n
  end

  alias kifer_k_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_k_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    kifer_k_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    # 2nd hit: the game quartered it; x4 x0.4
    if user.instance_variable_get(:@kifer_k_maw) && user.effects[PBEffects::ParentalBond] == 1
      multipliers[:base_damage_multiplier] *= 1.6
    end
  end
end

#-------------------------------------------------------------------------------
# Good as Gold
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:GOODASGOLD,
  proc { |ability, user, target, move, type, battle|
    next false if !move.statusMove? || user.index == target.index
    next false if move.pbTarget(user).id == :AllBattlers
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
    battle.pbHideAbilitySplash(target)
    next true
  }
)

#-------------------------------------------------------------------------------
# Hardened Sheath
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:HARDENEDSHEATH,
  proc { |ability, user, targets, move, battle|
    next if user.fainted? || !KIFER::BatchH::HORN_MOVES.include?(move.id)
    next if KIFER::BatchK.dealt(user, targets) <= 0 || !user.pbCanRaiseStatStage?(:ATTACK, user)
    user.pbRaiseStatStageByAbility(:ATTACK, 1, user, true, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Haste Makes Waste (Stall's ER number, Analytic's handler)
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:HASTEMAKESWASTE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.7 if !target.movedThisRound?
  }
)
BattleHandlers::DamageCalcUserAbility.add(:HASTEMAKESWASTE, BattleHandlers::DamageCalcUserAbility[:ANALYTIC])

#-------------------------------------------------------------------------------
# Hungry Maws, Hunter's Horn, Hydra, Magma Eater
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:HUNGRYMAWS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER.bite_move?(move)
  }
)
BattleHandlers::UserAbilityEndOfMove.add(:HUNGRYMAWS, BattleHandlers::UserAbilityEndOfMove[:JAWSOFCARNAGE])
BattleHandlers::DamageCalcUserAbility.add(:HUNTERSHORN, BattleHandlers::DamageCalcUserAbility[:MIGHTYHORN])
BattleHandlers::UserAbilityEndOfMove.add(:HUNTERSHORN, BattleHandlers::UserAbilityEndOfMove[:PREDATOR])
BattleHandlers::UserAbilityEndOfMove.add(:HYDRA, BattleHandlers::UserAbilityEndOfMove[:HUBRIS])
BattleHandlers::UserAbilityEndOfMove.add(:MAGMAEATER, BattleHandlers::UserAbilityEndOfMove[:PREDATOR])

#-------------------------------------------------------------------------------
# Hydro Circuit
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:HYDROCIRCUIT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if type == :ELECTRIC
  }
)
BattleHandlers::UserAbilityEndOfMove.add(:HYDROCIRCUIT,
  proc { |ability, user, targets, move, battle|
    next if user.fainted? || !move.damagingMove? || move.calcType != :WATER
    KIFER::BatchK.heal(user, KIFER::BatchK.dealt(user, targets) / 4, ability)
  }
)

#-------------------------------------------------------------------------------
# Infernal Rage
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:INFERNALRAGE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.35 if type == :FIRE
  }
)
BattleHandlers::UserAbilityEndOfMove.add(:INFERNALRAGE,
  proc { |ability, user, targets, move, battle|
    next if user.fainted? || user.hp <= 1 || !move.damagingMove? || move.calcType != :FIRE
    dmg = KIFER::BatchK.dealt(user, targets)
    next if dmg <= 0 || !user.takesIndirectDamage?
    amt = [[(dmg * 0.05).round, 1].max, user.hp - 1].min
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    user.pbReduceHP(amt, false)
    battle.pbDisplay(_INTL("{1} is damaged by recoil!", user.pbThis))
    battle.pbHideAbilitySplash(user)
    user.pbItemHPHealCheck
  }
)

#-------------------------------------------------------------------------------
# Intrepid Sword
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:INTREPIDSWORD,
  proc { |ability, battler, battle|
    next if !battler.pbCanRaiseStatStage?(:ATTACK, battler)
    battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler, true, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Jumpscare (its +3 priority counts for Dazzling, Psychic Terrain...)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:JUMPSCARE,
  proc { |ability, battler, battle|
    next if KIFER::BatchK.once?(battle, :jumpscare, battler)
    foe = KIFER::BatchF.random_near_foe(battler)
    next if !foe || foe.fainted?
    battler.instance_variable_set(:@kifer_k_jump, true)
    begin
      KIFER::BatchF.use_extra_move(battler, :ASTONISH, foe.index, 40, ability)
    ensure
      battler.instance_variable_set(:@kifer_k_jump, false)
    end
    ds = foe.damageState
    if !foe.fainted? && !ds.unaffected && !ds.missed && !ds.substitute && ds.hpLost.to_i > 0
      foe.pbFlinch(battler)
    end
  }
)
BattleHandlers::PriorityChangeAbility.add(:JUMPSCARE,
  proc { |ability, battler, move, pri|
    next pri + 3 if move.id == :ASTONISH && battler.instance_variable_get(:@kifer_k_jump)
    next pri
  }
)

#-------------------------------------------------------------------------------
# Know Your Place
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:KNOWYOURPLACE,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user) || target.fainted? || target.kifer_k_kyp > 0
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    target.kifer_k_kyp = 5
    target.effects[PBEffects::Quash] = 1 if !target.movedThisRound? && target.effects[PBEffects::Quash] == 0
    battle.pbDisplay(_INTL("{1} will move last!", target.pbThis))
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Lucha Libre
#-------------------------------------------------------------------------------
BattleHandlers::MoveBlockingAbility.add(:LUCHALIBRE, BattleHandlers::MoveBlockingAbility[:DAZZLING])
BattleHandlers::AbilityOnStatLoss.add(:LUCHALIBRE, BattleHandlers::AbilityOnStatLoss[:DEFIANT])

#-------------------------------------------------------------------------------
# Malediction
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:MALEDICTION,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || user.index == target.index
    KIFER::Statuses.cause_bleed(user, target, move, ability, 20)
    next if target.fainted? || target.effects[PBEffects::Curse]
    next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
    next if battle.pbRandom(100) >= 10
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    target.effects[PBEffects::Curse] = true
    battle.pbDisplay(_INTL("{1} laid a curse on {2}!", user.pbThis, target.pbThis(true)))
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Malodor (as Hemotoxin, 027)
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:MALODOR,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user) || user.fainted? || user.index == target.index
    next if user.effects[PBEffects::GastroAcid] || user.unstoppableAbility?
    next if !user.affectedByContactEffect?
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    user.effects[PBEffects::GastroAcid] = true
    user.effects[PBEffects::Truant]     = false
    battle.pbDisplay(_INTL("{1}'s Ability was suppressed!", user.pbThis))
    battle.pbHideAbilitySplash(target)
    user.pbOnAbilityChanged(user.ability)
  }
)

#-------------------------------------------------------------------------------
# Marine Apex, Megabite, Mystic Blades, Purgatory, Reaper's Embarce
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:MARINEAPEX,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 1.5 if target.pbHasType?(:WATER)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:MEGABITE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER.bite_move?(move)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:MYSTICBLADES,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER::SLICING_MOVES.include?(move.id)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:PURGATORY,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :GHOST
    mults[:base_damage_multiplier] *= (user.hp <= user.totalhp / 3) ? 1.8 : 1.3
  }
)

BattleHandlers::DamageCalcUserAbility.add(:REAPERSEMBARCE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if move.pbContactMove?(user)
    if type == :DARK
      mults[:base_damage_multiplier] *= (user.hp <= user.totalhp / 3) ? 1.5 : 1.2
    end
  }
)

#-------------------------------------------------------------------------------
# Metallic Jaws, Ominous Shroud, Overcast
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:METALLICJAWS, BattleHandlers::AbilityOnSwitchIn[:METALLIC])
BattleHandlers::AbilityOnSwitchIn.add(:OMINOUSSHROUD, BattleHandlers::AbilityOnSwitchIn[:PHANTOM])
BattleHandlers::DamageCalcTargetAbilityNonIgnorable.add(:OMINOUSSHROUD,
  BattleHandlers::DamageCalcTargetAbilityNonIgnorable[:SHADOWSHIELD])

BattleHandlers::AbilityOnSwitchIn.add(:OVERCAST,
  proc { |ability, battler, battle|
    fog = BattleHandlers::AbilityOnSwitchIn[:LOWVISIBILITY]
    fog.call(ability, battler, battle) if fog
    next if battler.fainted? || battler.pbOwnSide.effects[PBEffects::Mist] > 0
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.pbOwnSide.effects[PBEffects::Mist] = 5
    battle.pbDisplay(_INTL("{1} became shrouded in mist!", battler.pbTeam))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Mucus Membrane
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:MUCUSMEMBRANE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.7
  }
)
BattleHandlers::TargetAbilityOnHit.add(:MUCUSMEMBRANE, BattleHandlers::TargetAbilityOnHit[:GOOEY])

#-------------------------------------------------------------------------------
# No Turning Back (PIF's "dropped below half" check; trapped as by Mean Look)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnHPDroppedBelowHalf.add(:NOTURNINGBACK,
  proc { |ability, battler, battle|
    next false if battler.fainted? || KIFER::BatchK.once?(battle, :noturningback, battler)
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED].each do |s|
      battler.pbRaiseStatStage(s, 1, battler) if battler.pbCanRaiseStatStage?(s, battler)
    end
    battler.effects[PBEffects::MeanLook] = battler.index
    battle.pbDisplay(_INTL("{1} can no longer escape!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
    next false
  }
)

#-------------------------------------------------------------------------------
# Parry
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:PARRY,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.8
  }
)
BattleHandlers::TargetAbilityOnHit.add(:PARRY,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user) || user.fainted? || target.fainted? || user.index == target.index
    next if KIFER.in_extra_move?(user)   # no counter to a counter
    KIFER::BatchK.parry_add(battle, target, user, ability)
  }
)

#-------------------------------------------------------------------------------
# Peaceful Slumber
#-------------------------------------------------------------------------------
KIFER::BatchK.both(BattleHandlers::EORHealingAbility, :PEACEFULSLUMBER, :SWEETDREAMS, :SELFSUFFICIENT)

#-------------------------------------------------------------------------------
# Phobia
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:PHOBIA,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    KIFER::Fear.on_hit(user, target, ability, 30)
  }
)
BattleHandlers::TargetAbilityOnHit.add(:PHOBIA,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user) || user.fainted? || user.index == target.index
    next if !user.affectedByContactEffect? || !KIFER::Fear.can_fear?(user)
    next if battle.pbRandom(100) >= 30
    KIFER::Fear.inflict(user, target, ability)
  }
)

#-------------------------------------------------------------------------------
# Power Outage
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:POWEROUTAGE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :ELECTRIC || user.instance_variable_get(:@kifer_k_outage)
    mults[:base_damage_multiplier] *= 2
  }
)
BattleHandlers::UserAbilityEndOfMove.add(:POWEROUTAGE,
  proc { |ability, user, targets, move, battle|
    next if !move.damagingMove? || move.calcType != :ELECTRIC
    next if user.instance_variable_get(:@kifer_k_outage)
    had = user.pbHasType?(:ELECTRIC)
    user.instance_variable_set(:@kifer_k_outage, true)
    next if !had || user.fainted?
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("{1} lost its Electric type!", user.pbThis))
    battle.pbHideAbilitySplash(user)
  }
)

# Its parts count for these abilities in hasActiveAbility? (003)
KIFER::BatchK::PART_OF.each { |part, wholes| KIFER.counts_as(part, *wholes) }
