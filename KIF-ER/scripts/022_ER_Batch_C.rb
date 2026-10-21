#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch C)
#   Mechanics follow Elite Redux 2.65 (its C source and in-game texts). Where
#   the public C source is older than 2.65 and its own description differs
#   from the 2.65 text, the 2.65 text is followed (noted on the ability).
#
#   Ambush          – its attacks always crit on its first turn in
#   Mountaineer     – Rock moves don't affect it; no damage from Stealth Rock
#                     (2.65 text; the older source also skipped Spikes and
#                     Sticky Web)
#   Earthbound      – Ground moves x1.2, x1.5 at 1/3 HP or less (2.65 text;
#                     the older source had a flat x1.25)
#   Electro Surge   – Electric Terrain on entry for 8 turns (12 with Terrain
#                     Extender). The terrain itself works as in PIF.
#   Cotton Down     – when an attack hits it, every other Pokémon's Speed -1
#                     (every hit of a multi-hit move)
#   Seaweed         – its Grass moves x2 against Fire types; Fire moves hit it
#                     for x0.5 if it is Grass type
#   Raging Storm    – in rain, its higher attacking stat (Attack or Sp. Atk,
#                     before stages) x1.5
#   Momentum        – contact moves use its Speed instead of Attack/Sp. Atk
#                     (with Speed Force: Speed x1.2)
#   Ice Scales      – special moves hit it for half
#   Sand Guard      – in a sandstorm: foes' priority moves at its side fail
#                     (as Dazzling) and special moves hit it for half
#   Coil Up         – on entry, its next biting move gets +1 priority; used
#                     up at the end of a turn it landed a biting move
#   Grounded        – on entry, adds the Ground type (kept until it switches
#                     out)
#   Sage Power      – special moves x1.5, but it's locked into the first move
#                     it uses until it switches out
#   Half Drake      – on entry, adds the Dragon type (kept until it switches
#                     out)
#   Raging Boxer    – punching moves hit twice, the 2nd hit at 40% (2.65 text;
#                     the older source had 50%). PIF rolls added effects on
#                     both hits, so a King's Rock can also flinch on the 2nd.
#   Trickster       – on entry, Disables the foe's last used move (PIF's
#                     Disable). Picks the foe like ER: the one opposite, or
#                     the other foe if that one is there. No foe move yet:
#                     nothing happens.
#   Cutthroat       – on entry, its next Keen Edge (slicing) move gets +1
#                     priority; used up at the end of a turn it landed one;
#                     using Sharpen gives it back
#   Imposing Wings  – wing/wind/air moves x1.3, Flying moves x1.25, and it
#                     counts as having Levitate (Ground immunity, hazards,
#                     terrain). Air moves are ER's list, minus moves PIF lacks.
#   On the Prowl    – on its first turn, moves with priority 0 or more get +1;
#                     negative priority becomes 0
#   Solenoglyphs    – biting moves have a 50% chance to badly poison
#   Telekinetic     – on entry, uses Telekinesis on a foe (picked as for
#                     Trickster); fails as Telekinesis does (Ingrain, Smack
#                     Down, Iron Ball, Gravity, Substitute...)
#   Blitz Boxer     – at full HP, punching moves get +1 priority
#   Dauntless Shield– on entry, Defense +1
#   Grappler        – its trapping moves last 6 turns and do 1/6 max HP a turn
#   Mind Crunch     – biting moves use its Sp. Atk (still against Defense)
#                     and do x1.3
#   Pretty Princess – x1.5 damage to a target with any lowered stat (not if
#                     either side has Unaware)
#   Rapid Response  – on its first turn: Speed x1.5 and Sp. Atk x1.2
#   Sand Song       – sound moves x1.2; Normal sound moves become Ground
#
#   "First turn" (Ambush, On the Prowl, Rapid Response) is the first round
#   after it comes in, the same rule PIF uses for Fake Out.
#
# Left out at first, now coded in 030-035 (fog, frostbite/bleeding,
# fear, Toxic Terrain/enrage, one-offs).
#===============================================================================
KIFER.er_code(:AMBUSH, :MOUNTAINEER, :EARTHBOUND, :ELECTROSURGE, :COTTONDOWN,
                :SEAWEED, :RAGINGSTORM, :MOMENTUM, :ICESCALES, :SANDGUARD,
                :COILUP, :GROUNDED, :SAGEPOWER, :HALFDRAKE, :RAGINGBOXER,
                :TRICKSTER, :CUTTHROAT, :IMPOSINGWINGS, :ONTHEPROWL,
                :SOLENOGLYPHS, :TELEKINETIC, :BLITZBOXER, :DAUNTLESSSHIELD,
                :GRAPPLER, :MINDCRUNCH, :PRETTYPRINCESS, :RAPIDRESPONSE,
                :SANDSONG)

module KIFER
  module BatchC
    # Elite Redux's wing, wind and air moves (Giant Wings / Imposing Wings)
    AIR_MOVES = [
      :RAZORWIND, :GUST, :WINGATTACK, :WHIRLWIND, :AEROBLAST, :ICYWIND,
      :STEELWING, :TWISTER, :HEATWAVE, :WEATHERBALL, :AIRCUTTER, :SILVERWIND,
      :TAILWIND, :AIRSLASH, :OMINOUSWIND, :LEAFTORNADO, :HURRICANE,
      :FAIRYWIND, :OBLIVIONWING, :DUALWINGBEAT,
      :BLIZZARD, :BRAVEBIRD, :PETALBLIZZARD, :POISONGAS, :POWDERSNOW
    ].freeze

    # Telekinesis can't lift these
    NO_TELEKINESIS = [:DIGLETT, :DUGTRIO, :SANDYGAST, :PALOSSAND]

    def self.first_turn?(battler)
      return battler.turnCount <= 1
    end

    # The foe ER's "uses a move on entry" abilities aim at: the one opposite,
    # then the other foe; the last one there wins
    def self.switch_in_target(battler)
      battle = battler.battle
      opp = battler.index ^ 1
      ret = nil
      [opp, opp ^ 2].each do |i|
        b = battle.battlers[i]
        ret = b if b && !b.fainted? && b.opposes?(battler)
      end
      return ret
    end

    # End of its move: Coil Up / Cutthroat use-up, Sage Power lock
    def self.after_move(battler, choice)
      st = battler.kifer_c
      move = choice.is_a?(Array) ? choice[2] : nil
      if move.is_a?(PokeBattle_Move) && battler.lastMoveUsed == move.id
        landed = !battler.lastMoveFailed   # a miss or no effect doesn't use it up
        st[:coiled] = false if st[:coiled] && KIFER.bite_move?(move) && landed
        st[:cutthroat] = false if st[:cutthroat] && KIFER::SLICING_MOVES.include?(move.id) && landed
        st[:cutthroat] = true if move.id == :SHARPEN && KIFER::BatchH.has?(battler, :CUTTHROAT)
      end
      # (not locked by a move one of its abilities used, 023)
      if !st[:sage] && !KIFER.in_extra_move?(battler) && KIFER::BatchH.has?(battler, :SAGEPOWER)
        if battler.lastMoveUsed && battler.pbHasMove?(battler.lastMoveUsed)
          st[:sage] = battler.lastMoveUsed
        elsif battler.lastRegularMoveUsed && battler.pbHasMove?(battler.lastRegularMoveUsed)
          st[:sage] = battler.lastRegularMoveUsed
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Battler state for this file (cleared when a Pokémon comes in)
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  def kifer_c
    @kifer_c ||= {}
    return @kifer_c
  end

  alias kifer_c_pbInitEffects pbInitEffects unless method_defined?(:kifer_c_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_c_pbInitEffects(batonPass)
    @kifer_c = {}
  end

  alias kifer_c_pbEndTurn pbEndTurn unless method_defined?(:kifer_c_pbEndTurn)
  def pbEndTurn(choice)
    kifer_c_pbEndTurn(choice)
    begin
      KIFER::BatchC.after_move(self, choice)
    rescue StandardError => e
      KIFER.log("batch C end of move: #{e.class}: #{e.message}")
    end
  end

  #-----------------------------------------------------------------------------
  # Sage Power – only the locked move can be chosen
  #-----------------------------------------------------------------------------
  alias kifer_c_pbCanChooseMove? pbCanChooseMove? unless method_defined?(:kifer_c_pbCanChooseMove?)
  def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
    return false unless kifer_c_pbCanChooseMove?(move, commandPhase, showMessages, specialUsage)
    lock = kifer_c[:sage]
    if lock && move.id != lock && pbHasMove?(lock) && !KIFER.in_extra_move?(self) &&
       hasActiveAbility?(:SAGEPOWER)
      if showMessages
        msg = _INTL("{1} allows the use of only {2}!", abilityName, GameData::Move.get(lock).name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      kifer_clear_inline if respond_to?(:kifer_clear_inline)
      return false
    end
    kifer_clear_inline if respond_to?(:kifer_clear_inline)
    return true
  end

  #-----------------------------------------------------------------------------
  # Imposing Wings – counts as Levitate
  #-----------------------------------------------------------------------------
  #-----------------------------------------------------------------------------
  # Grappler – its trapping moves hurt like Binding Band (1/6 max HP)
  #-----------------------------------------------------------------------------
  alias kifer_c_hasActiveItem? hasActiveItem? unless method_defined?(:kifer_c_hasActiveItem?)
  def hasActiveItem?(check_item, ignore_fainted = false)
    return true if kifer_c_hasActiveItem?(check_item, ignore_fainted)
    return false unless check_item == :BINDINGBAND
    return KIFER::BatchH.has?(self, :GRAPPLER)
  end
end

#-------------------------------------------------------------------------------
# Grappler – its trapping moves last 6 turns (PIF counts the turn it ends in,
# so 7 here; Grip Claw's longer time is kept)
#-------------------------------------------------------------------------------
class PokeBattle_Move_0CF
  alias kifer_c_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_c_pbEffectAgainstTarget)
  def pbEffectAgainstTarget(user, target)
    before = target.effects[PBEffects::Trapping]
    kifer_c_pbEffectAgainstTarget(user, target)
    if before == 0 && target.effects[PBEffects::Trapping] > 0 &&
       target.effects[PBEffects::Trapping] < 7 && KIFER::BatchH.has?(user, :GRAPPLER)
      target.effects[PBEffects::Trapping] = 7
    end
  end
end

class PokeBattle_Move
  #-----------------------------------------------------------------------------
  # Raging Boxer – punching moves hit twice (as Parental Bond)
  #-----------------------------------------------------------------------------
  alias kifer_c_pbNumHits pbNumHits unless method_defined?(:kifer_c_pbNumHits)
  def pbNumHits(user, targets)
    n = kifer_c_pbNumHits(user, targets)
    user.instance_variable_set(:@kifer_c_boxer, false)
    if n == 1 && KIFER.punch_move?(self) && pbDamagingMove? && !chargingTurnMove? &&
       targets.length == 1 && KIFER::BatchH.has?(user, :RAGINGBOXER)
      user.effects[PBEffects::ParentalBond] = 3
      user.instance_variable_set(:@kifer_c_boxer, true)
      return 2
    end
    return n
  end

  # Raging Boxer's 2nd hit is 40% (PIF already makes Parental Bond's 2nd hit
  # 1/4, so x1.6 here)
  alias kifer_c_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_c_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    kifer_c_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    if user.effects[PBEffects::ParentalBond] == 1 && user.instance_variable_get(:@kifer_c_boxer)
      multipliers[:base_damage_multiplier] *= 1.6
    end
  end

  #-----------------------------------------------------------------------------
  # Momentum – contact moves use Speed; Mind Crunch – biting moves use Sp. Atk
  #-----------------------------------------------------------------------------
  alias kifer_c_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_c_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    stat, stage = kifer_c_pbGetAttackStats(user, target)
    if !@kifer_f_magical && KIFER.on_field?(@battle, :MOMENTUM) && pbContactMove?(user) &&
       KIFER::BatchH.has?(user, :MOMENTUM)   # (Magical Fists' Sp. Atk wins, 025)
      spd = user.speed
      spd = (spd * 1.2).floor if KIFER::BatchH.has?(user, :SPEEDFORCE)
      return spd, user.stages[:SPEED] + 6
    end
    if KIFER.on_field?(@battle, :MINDCRUNCH) && KIFER.bite_move?(self) && KIFER::BatchH.has?(user, :MINDCRUNCH)
      return user.spatk, user.stages[:SPECIAL_ATTACK] + 6
    end
    return stat, stage
  end
end

#-------------------------------------------------------------------------------
# Mountaineer – no Stealth Rock damage on entry (Spikes, Toxic Spikes and
# Sticky Web still work). The hazard stays on the field (008 skips the
# Stealth Rock damage check).
#-------------------------------------------------------------------------------
class PokeBattle_Battle
  alias kifer_c_pbOnActiveOne pbOnActiveOne unless method_defined?(:kifer_c_pbOnActiveOne)
  def pbOnActiveOne(battler)
    if !battler || battler.fainted? || !KIFER::BatchH.has?(battler, :MOUNTAINEER)
      return kifer_c_pbOnActiveOne(battler)
    end
    battler.instance_variable_set(:@kifer_rock_proof, true)
    begin
      return kifer_c_pbOnActiveOne(battler)
    ensure
      battler.instance_variable_set(:@kifer_rock_proof, false)
    end
  end
end

#-------------------------------------------------------------------------------
# Ambush – always a critical hit on its first turn
#-------------------------------------------------------------------------------
BattleHandlers::CriticalCalcUserAbility.add(:AMBUSH,
  proc { |ability, user, target, c|
    next 99 if KIFER::BatchC.first_turn?(user)
  }
)

#-------------------------------------------------------------------------------
# Mountaineer – Rock moves don't affect it
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:MOUNTAINEER,
  proc { |ability, user, target, move, type, battle|
    next false if type != :ROCK || user.index == target.index
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
    battle.pbHideAbilitySplash(target)
    next true
  }
)

#-------------------------------------------------------------------------------
# Earthbound – Ground moves x1.2, x1.5 at 1/3 HP or less
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:EARTHBOUND,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :GROUND
    mults[:attack_multiplier] *= KIFER::BatchA.pinch_boost(user)
  }
)

#-------------------------------------------------------------------------------
# Electro Surge – Electric Terrain on entry, 8 turns (12 with Terrain Extender)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:ELECTROSURGE,
  proc { |ability, battler, battle|
    next if battle.field.terrain == :Electric
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbStartTerrain(battler, :Electric)   # hides the splash
    battle.field.terrainDuration = battler.hasActiveItem?(:TERRAINEXTENDER) ? 12 : 8
  }
)

#-------------------------------------------------------------------------------
# Cotton Down – hit by an attack: every other Pokémon's Speed -1
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:COTTONDOWN,
  proc { |ability, user, target, move, battle|
    next if !user || !move || user.fainted? || user.index == target.index
    name = KIFER.ability_name(ability)
    battle.pbShowAbilitySplash(target, false, true, name)
    battle.eachBattler do |b|
      next if b.index == target.index
      b.pbLowerStatStageByAbility(:SPEED, 1, target, false, false, name)
    end
    battle.pbHideAbilitySplash(target)
  }
)

#-------------------------------------------------------------------------------
# Seaweed – Grass moves x2 against Fire types; Fire moves x0.5 on it if Grass
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:SEAWEED,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 2 if type == :GRASS && user.pbHasType?(:GRASS) && target.pbHasType?(:FIRE)   # ER: "If user is Grass-type"
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:SEAWEED,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 0.5 if type == :FIRE && target.pbHasType?(:GRASS)
  }
)

#-------------------------------------------------------------------------------
# Raging Storm – in rain, its higher attacking stat x1.5
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:RAGINGSTORM,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next unless [:Rain, :HeavyRain].include?(user.battle.pbWeather)
    next if user.hasActiveItem?(:UTILITYUMBRELLA)
    special_high = KIFER::BatchF.highest_attack_stat(user) == :SPECIAL_ATTACK
    if (special_high && move.specialMove?(type)) || (!special_high && move.physicalMove?(type))
      mults[:attack_multiplier] *= 1.5
    end
  }
)

#-------------------------------------------------------------------------------
# Ice Scales – special moves hit it for half
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:ICESCALES,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.5 if move.specialMove?(type)
  }
)

#-------------------------------------------------------------------------------
# Sand Guard – in a sandstorm: blocks foes' priority moves, halves special hits
#-------------------------------------------------------------------------------
BattleHandlers::MoveBlockingAbility.add(:SANDGUARD,
  proc { |ability, bearer, user, targets, move, battle|
    next false if battle.pbWeather != :Sandstorm
    next false if !battle.choices[user.index][4] || battle.choices[user.index][4] <= 0
    next false if !bearer.opposes?(user)
    next false if !targets.any? { |b| b.opposes?(user) }
    next bearer.hasActiveAbility?(:SANDGUARD)   # names it on the game's splash
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:SANDGUARD,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if user.battle.pbWeather != :Sandstorm
    mults[:final_damage_multiplier] *= 0.5 if move.specialMove?(type)
  }
)

#-------------------------------------------------------------------------------
# Coil Up – on entry, its next biting move gets +1 priority
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:COILUP,
  proc { |ability, battler, battle|
    next if battler.kifer_c[:coiled]
    battler.kifer_c[:coiled] = true
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("{1} coiled up!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

BattleHandlers::PriorityChangeAbility.add(:COILUP,
  proc { |ability, battler, move, pri|
    next pri + 1 if battler.kifer_c[:coiled] && KIFER.bite_move?(move)
  }
)
BattleHandlers::PriorityChangeAbility.copy(:COILUP, :CURLIPEDE)

#-------------------------------------------------------------------------------
# Grounded / Half Drake – on entry, add the Ground / Dragon type
#   There is one slot for an added type (the game's Type3, as ER's type3), so
#   a type added later replaces an earlier one (Grounded + Half Drake: Dragon;
#   Monster Mash on a Metallic foe: Ghost), as in ER. Entry abilities run in a
#   fixed order (main ability, then innates in order), so the last one wins.
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:GROUNDED,
  proc { |ability, battler, battle|
    KIFER::BatchH.add_type(ability, battler, battle, :GROUND)
  }
)

BattleHandlers::AbilityOnSwitchIn.add(:HALFDRAKE,
  proc { |ability, battler, battle|
    KIFER::BatchH.add_type(ability, battler, battle, :DRAGON)
  }
)

#-------------------------------------------------------------------------------
# Sage Power – special moves x1.5 (the move lock is above)
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:SAGEPOWER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if move.specialMove?(type)
  }
)

#-------------------------------------------------------------------------------
# Trickster – on entry, Disables the foe's last used move
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:TRICKSTER,
  proc { |ability, battler, battle|
    t = KIFER::BatchC.switch_in_target(battler)
    next if !t || t.effects[PBEffects::Disable] > 0
    mv = t.lastRegularMoveUsed
    next if !mv
    veil = KIFER::BatchH.has?(t, :AROMAVEIL)
    t.eachAlly { |b| veil = true if KIFER::BatchH.has?(b, :AROMAVEIL) }
    next if veil
    ok = false
    t.eachMove { |m| ok = true if m.id == mv && (m.pp > 0 || m.total_pp == 0) }
    next if !ok
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    t.effects[PBEffects::Disable]     = 5   # the same as PIF's Disable move
    t.effects[PBEffects::DisableMove] = mv
    battle.pbDisplay(_INTL("{1}'s {2} was disabled!", t.pbThis, GameData::Move.get(mv).name))
    battle.pbHideAbilitySplash(battler)
    t.pbItemStatusCureCheck
  }
)

#-------------------------------------------------------------------------------
# Cutthroat – on entry, its next slicing move gets +1 priority
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:CUTTHROAT,
  proc { |ability, battler, battle|
    battler.kifer_c[:cutthroat] = true
  }
)

BattleHandlers::PriorityChangeAbility.add(:CUTTHROAT,
  proc { |ability, battler, move, pri|
    next pri + 1 if battler.kifer_c[:cutthroat] && KIFER::SLICING_MOVES.include?(move.id)
  }
)

#-------------------------------------------------------------------------------
# Imposing Wings – air moves x1.3, Flying moves x1.25 (Levitate part above)
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:IMPOSINGWINGS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER::BatchC::AIR_MOVES.include?(move.id)
    mults[:attack_multiplier] *= 1.25 if type == :FLYING
  }
)

#-------------------------------------------------------------------------------
# On the Prowl – first turn: priority 0+ gets +1, negative becomes 0
#-------------------------------------------------------------------------------
BattleHandlers::PriorityChangeAbility.add(:ONTHEPROWL,
  proc { |ability, battler, move, pri|
    next if !KIFER::BatchC.first_turn?(battler)
    next (pri >= 0) ? pri + 1 : 0
  }
)

#-------------------------------------------------------------------------------
# Solenoglyphs – biting moves: 50% chance to badly poison
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:SOLENOGLYPHS,
  proc { |ability, user, target, move, battle|
    next if !KIFER.bite_move?(move) || target.fainted?
    next if battle.pbRandom(2) != 0
    next if !target.pbCanPoison?(user, false)
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    target.pbPoison(user, nil, true)
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Telekinetic – on entry, uses Telekinesis on a foe (3 turns)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:TELEKINETIC,
  proc { |ability, battler, battle|
    t = KIFER::BatchC.switch_in_target(battler)
    next if !t
    next if battle.field.effects[PBEffects::Gravity] > 0
    next if t.effects[PBEffects::Ingrain] || t.effects[PBEffects::SmackDown] ||
            t.effects[PBEffects::Telekinesis] > 0 || t.effects[PBEffects::Substitute] > 0
    next if t.hasActiveItem?(:IRONBALL)
    next if KIFER::BatchC::NO_TELEKINESIS.any? { |s| t.isSpecies?(s) } ||
            (t.isSpecies?(:GENGAR) && t.mega?)
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    t.effects[PBEffects::Telekinesis] = 3
    battle.pbDisplay(_INTL("{1} was hurled into the air!", t.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Blitz Boxer – at full HP, punching moves get +1 priority
#-------------------------------------------------------------------------------
BattleHandlers::PriorityChangeAbility.add(:BLITZBOXER,
  proc { |ability, battler, move, pri|
    next pri + 1 if battler.hp == battler.totalhp && KIFER.punch_move?(move)
  }
)

#-------------------------------------------------------------------------------
# Dauntless Shield – on entry, Defense +1
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:DAUNTLESSSHIELD,
  proc { |ability, battler, battle|
    next if !battler.pbCanRaiseStatStage?(:DEFENSE, battler)
    battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler, true, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Mind Crunch – biting moves x1.3 (Sp. Atk part above)
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:MINDCRUNCH,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER.bite_move?(move)
  }
)

#-------------------------------------------------------------------------------
# Pretty Princess – x1.5 against a target with a lowered stat
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:PRETTYPRINCESS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if !target.hasLoweredStatStages?
    next if KIFER::BatchH.has?(user, :UNAWARE) || KIFER::BatchH.has?(target, :UNAWARE)
    mults[:base_damage_multiplier] *= 1.5
  }
)

#-------------------------------------------------------------------------------
# Rapid Response – first turn: Speed x1.5, Sp. Atk x1.2
#-------------------------------------------------------------------------------
BattleHandlers::SpeedCalcAbility.add(:RAPIDRESPONSE,
  proc { |ability, battler, mult|
    next mult * 1.5 if KIFER::BatchC.first_turn?(battler)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:RAPIDRESPONSE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if !KIFER::BatchC.first_turn?(user)
    mults[:attack_multiplier] *= 1.2 if move.specialMove?(type)
  }
)

#-------------------------------------------------------------------------------
# Sand Song – sound moves x1.2; Normal sound moves become Ground
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.add(:SANDSONG,
  proc { |ability, user, move, type|
    next :GROUND if type == :NORMAL && KIFER.sound_move?(move) && GameData::Type.exists?(:GROUND)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:SANDSONG,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.2 if KIFER.sound_move?(move)
  }
)

# Imposing Wings counts as Levitate (003's "counts as" table)
KIFER.counts_as(:LEVITATE, :IMPOSINGWINGS)
