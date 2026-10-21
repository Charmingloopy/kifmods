#===============================================================================
# KIF: Elite Redux – Elite Redux abilities, batch B
#   Mechanics follow Elite Redux 2.65 (its C source first, then its in-game
#   texts where the source doesn't have the ability).
#
#   Soul Eater       – a KO with its attack heals 1/4 of its max HP
#   Fossilized       – Rock moves hit it for x0.5 power; its Rock moves x1.2 Attack
#   Hydrate          – Normal moves become Water. Non-Water users: Water moves
#                      get STAB. Water users: their Water moves have a 10%
#                      chance to drench the target (031; "New battle effects" On)
#   Molten Down      – its Fire moves are super effective on Rock types
#   Amplifier        – sound moves x1.3 power; single-target sound moves hit
#                      both foes
#   Rampage          – no recharge turn after a move that KOs
#   Overwhelm        – its Dragon moves hit Fairy types for normal damage;
#                      Intimidate and Scare don't affect it
#   Majestic Moth    – on entry: +1 to its highest stat (stages counted)
#   Ground Shock     – its Electric moves hit Ground types for x0.5
#   Power Spot       – allies' moves x1.3 power (not its own)
#   Bad Luck         – it and its ally can't be crit; moves aimed at them have
#                      5% less accuracy; foes' hits on it roll minimum damage and
#                      their chance-based added effects don't happen
#   Precise Fist     – punching moves: +1 crit stage, added effects 5x as likely
#   Antarctic Bird   – its Ice and Flying moves x1.3 Attack
#   Firefighter      – x1.5 damage to Fire-type foes; x0.5 damage from Fire-type
#                      attackers (by the Pokemon's types, not the move's)
#   Pollinate        – Normal moves become Bug. Bug users: powder moves don't
#                      affect it; others: Bug moves get STAB
#   Combat Specialist – punching and kicking moves x1.3 power
#   Earth Eater      – Ground moves don't hurt it and heal 1/4 of its max HP
#   Ice Dew          – draws in Ice moves; they don't hurt it and raise its
#                      higher of Attack / Sp. Atk
#   Tectonize        – Normal moves become Ground. Ground users: Stealth Rock
#                      and Spikes don't hurt it; others: Ground moves get STAB
#   Curlipede        – on entry: Defense +1 and Defense Curl, and its first
#                      biting move gets +1 priority
#   Glacial Ghost    – in hail: Speed x1.5, evasion x1.25, no hail damage
#   Mimicry          – takes the type of the terrain (Electric, Fairy, Grass,
#                      Psychic) and goes back when the terrain ends
#   Powder Burst     – on entry: uses Powder on a random foe
#   Rain Shroud      – evasion x1.3 in rain
#   Salt Circle      – foes can't switch out or flee while it's in battle
#
#   Left out at first, now coded in 030-035 (fog, frostbite/bleeding,
#   fear, Toxic Terrain/enrage, one-offs).
#===============================================================================
module KIFER
  module BatchB
    MIMICRY_TYPES = { :Electric => :ELECTRIC, :Misty => :FAIRY, :Grassy => :GRASS, :Psychic => :PSYCHIC }

    # Bad Luck on this battler or its ally
    def self.bad_luck_side?(battler)
      return false unless battler
      return true if battler.hasActiveAbility?(:BADLUCK)
      battler.eachAlly { |b| return true if b.hasActiveAbility?(:BADLUCK) }
      return false
    end

    # Bad Luck against a foe's attack
    def self.bad_luck_vs?(user, target)
      return false unless user && target && user.opposes?(target)
      return target.hasActiveAbility?(:BADLUCK)
    end

    # Follow Me / Spotlight already decided the target
    def self.target_forced?(battle, user)
      battle.eachOtherSideBattler(user.index) do |b|
        return true if b.effects[PBEffects::FollowMe] > 0 || b.effects[PBEffects::Spotlight] > 0
      end
      return false
    end

    # -ate abilities: the one that changed the move's type (only that one's
    # power boost applies; another -ate as an innate would see powerBoost too)
    ATE_ABILITIES = [:AERILATE, :PIXILATE, :REFRIGERATE, :GALVANIZE]

    def self.ate_boost?(move, ability)
      return false if !move.powerBoost
      by = move.instance_variable_get(:@kifer_b_ate)
      return by.nil? || by == KIFER.ability_id(ability)
    end

    def self.mimicry_update_all(battle)
      battle.eachBattler { |b| b.kifer_b_mimicry_update }
    end
  end
end

KIFER.er_code(:SOULEATER, :FOSSILIZED, :HYDRATE, :MOLTENDOWN, :AMPLIFIER, :RAMPAGE,
                :OVERWHELM, :MAJESTICMOTH, :GROUNDSHOCK, :POWERSPOT, :BADLUCK,
                :PRECISEFIST, :ANTARCTICBIRD, :FIREFIGHTER, :POLLINATE,
                :COMBATSPECIALIST, :EARTHEATER, :ICEDEW, :TECTONIZE, :CURLIPEDE,
                :GLACIALGHOST, :MIMICRY, :POWDERBURST, :RAINSHROUD, :SALTCIRCLE)

#-------------------------------------------------------------------------------
# Soul Eater – a KO with its attack heals 1/4 of its max HP
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.copy(:PREDATOR, :SOULEATER)

#-------------------------------------------------------------------------------
# Fossilized – Rock moves hit it for x0.5 power; its Rock moves x1.2 Attack
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:FOSSILIZED,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 1.2 if type == :ROCK
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:FOSSILIZED,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 0.5 if type == :ROCK
  }
)

#-------------------------------------------------------------------------------
# Hydrate / Pollinate / Tectonize – Normal moves change type (no power boost).
# A user that isn't that type gets STAB on that type's moves. A user that is:
# Pollinate – powder moves don't affect it; Tectonize – no Stealth Rock or
# Spikes damage (both below); Hydrate – Water moves 10% drench (below).
#-------------------------------------------------------------------------------
{ :HYDRATE => :WATER, :POLLINATE => :BUG, :TECTONIZE => :GROUND }.each do |abil, newType|
  BattleHandlers::MoveBaseTypeModifierAbility.add(abil,
    proc { |ability, user, move, type|
      next if type != :NORMAL || !GameData::Type.exists?(newType)
      next newType
    }
  )

  BattleHandlers::DamageCalcUserAbility.add(abil,
    proc { |ability, user, target, move, mults, baseDmg, type|
      next if type != newType || !KIFER::BatchF.ability_stab?(user, type)
      mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
    }
  )
end

BattleHandlers::UserAbilityOnHit.add(:HYDRATE,
  proc { |ability, user, target, move, battle|
    next if move.calcType != :WATER || !user.pbHasType?(:WATER)
    KIFER::Drench.on_hit(user, target, ability, 10)
  }
)

module KIFER
  module BatchB
    def self.pollinate_powder_immune?(battler)
      return false if battler.fainted? || !battler.pbHasType?(:BUG)
      return false if !battler.hasActiveAbility?(:POLLINATE) || battler.battle.moldBreaker
      return true
    end
  end
end

# Marks which -ate ability changed the move, so another one's x1.2 (PIF's
# Aerilate and co., which only look at powerBoost) doesn't apply as well
KIFER::BatchB::ATE_ABILITIES.each do |abil|
  orig = BattleHandlers::MoveBaseTypeModifierAbility[abil]
  next if !orig
  BattleHandlers::MoveBaseTypeModifierAbility.add(abil,
    proc { |ability, user, move, type|
      ret = orig.call(ability, user, move, type)
      move.instance_variable_set(:@kifer_b_ate, abil) if ret && ret != type && move.powerBoost
      next ret
    }
  )
end

KIFER::BatchB::ATE_ABILITIES.each do |abil|
  orig = BattleHandlers::DamageCalcUserAbility[abil]
  next if !orig
  BattleHandlers::DamageCalcUserAbility.add(abil,
    proc { |ability, user, target, move, mults, baseDmg, type|
      next if !KIFER::BatchB.ate_boost?(move, abil)
      orig.call(ability, user, target, move, mults, baseDmg, type)
    }
  )
end

class PokeBattle_Move
  alias kifer_b_pbBaseType pbBaseType unless method_defined?(:kifer_b_pbBaseType)
  def pbBaseType(user)
    @kifer_b_ate = nil
    return kifer_b_pbBaseType(user)
  end
end

#-------------------------------------------------------------------------------
# Molten Down, Ground Shock, Overwhelm – type matchups
#-------------------------------------------------------------------------------
class PokeBattle_Move
  alias kifer_b_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_b_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_b_pbCalcTypeModSingle(moveType, defType, user, target)
    if moveType == :FIRE && defType == :ROCK && user.hasActiveAbility?(:MOLTENDOWN)
      ret = Effectiveness::SUPER_EFFECTIVE_ONE
    elsif moveType == :ELECTRIC && defType == :GROUND && ret == Effectiveness::INEFFECTIVE &&
          user.hasActiveAbility?(:GROUNDSHOCK)
      ret = Effectiveness::NOT_VERY_EFFECTIVE_ONE
    elsif moveType == :DRAGON && defType == :FAIRY && ret == Effectiveness::INEFFECTIVE &&
          user.hasActiveAbility?(:OVERWHELM)
      ret = Effectiveness::NORMAL_EFFECTIVE_ONE
    end
    return ret
  end

  #-----------------------------------------------------------------------------
  # Amplifier – single-target sound moves hit both foes (not multi-hit moves)
  #-----------------------------------------------------------------------------
  alias kifer_b_pbTarget pbTarget unless method_defined?(:kifer_b_pbTarget)
  def pbTarget(user)
    ret = kifer_b_pbTarget(user)
    if ret.id == :NearOther && KIFER.sound_move?(self) && !multiHitMove? &&
       user.respond_to?(:hasActiveAbility?) && user.hasActiveAbility?(:AMPLIFIER)
      return GameData::Target.get(:AllNearFoes)
    end
    return ret
  end

  #-----------------------------------------------------------------------------
  # Bad Luck – it and its ally can't be crit
  #-----------------------------------------------------------------------------
  alias kifer_b_pbIsCritical? pbIsCritical? unless method_defined?(:kifer_b_pbIsCritical?)
  def pbIsCritical?(user, target)
    return false if KIFER::BatchB.bad_luck_side?(target)
    return kifer_b_pbIsCritical?(user, target)
  end

  #-----------------------------------------------------------------------------
  # Bad Luck – moves aimed at it or its ally have 5% less accuracy
  #-----------------------------------------------------------------------------
  alias kifer_b_pbCalcAccuracyModifiers pbCalcAccuracyModifiers unless method_defined?(:kifer_b_pbCalcAccuracyModifiers)
  def pbCalcAccuracyModifiers(user, target, modifiers)
    kifer_b_pbCalcAccuracyModifiers(user, target, modifiers)
    if modifiers[:base_accuracy] > 0 && KIFER::BatchB.bad_luck_side?(target)
      modifiers[:base_accuracy] = modifiers[:base_accuracy] * 95 / 100
    end
  end

  #-----------------------------------------------------------------------------
  # Bad Luck – foes' hits on it roll the minimum damage (85%)
  #-----------------------------------------------------------------------------
  alias kifer_b_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_b_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    minRoll = KIFER::BatchB.bad_luck_vs?(user, target)
    @battle.kifer_b_min_roll = true if minRoll
    begin
      kifer_b_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    ensure
      @battle.kifer_b_min_roll = false if minRoll
    end
  end

  #-----------------------------------------------------------------------------
  # Precise Fist – punching moves' added effects are 5x as likely
  # Bad Luck – foes' added effects that aren't certain don't happen
  #-----------------------------------------------------------------------------
  alias kifer_b_pbAdditionalEffectChance pbAdditionalEffectChance unless method_defined?(:kifer_b_pbAdditionalEffectChance)
  def pbAdditionalEffectChance(user, target, effectChance = 0)
    ret = kifer_b_pbAdditionalEffectChance(user, target, effectChance)
    return ret if ret <= 0
    if KIFER.punch_move?(self) && user.hasActiveAbility?(:PRECISEFIST)
      ret *= 5
    end
    base = (effectChance > 0) ? effectChance : @addlEffect
    ret = 0 if base < 100 && KIFER::BatchB.bad_luck_vs?(user, target)
    return ret
  end

  alias kifer_b_pbFlinchChance pbFlinchChance unless method_defined?(:kifer_b_pbFlinchChance)
  def pbFlinchChance(user, target)
    ret = kifer_b_pbFlinchChance(user, target)
    ret = 0 if ret > 0 && ret < 100 && KIFER::BatchB.bad_luck_vs?(user, target)
    return ret
  end
end

class PokeBattle_Battle
  attr_accessor :kifer_b_min_roll

  # The damage roll is the only pbRandom(16) in the damage multipliers. The
  # roll is still drawn, so the damage log's recorded rolls stay in step.
  alias kifer_b_pbRandom pbRandom unless method_defined?(:kifer_b_pbRandom)
  def pbRandom(x)
    v = kifer_b_pbRandom(x)
    if @kifer_b_min_roll && x == 16
      @kifer_b_min_roll = false
      return 0
    end
    return v
  end

  #-----------------------------------------------------------------------------
  # Mimicry – follows terrain changes
  #-----------------------------------------------------------------------------
  alias kifer_b_pbStartTerrain pbStartTerrain unless method_defined?(:kifer_b_pbStartTerrain)
  def pbStartTerrain(user, newTerrain, fixedDuration = true)
    kifer_b_pbStartTerrain(user, newTerrain, fixedDuration)
    KIFER::BatchB.mimicry_update_all(self)
  end

  alias kifer_b_pbEORTerrain pbEORTerrain unless method_defined?(:kifer_b_pbEORTerrain)
  def pbEORTerrain
    kifer_b_pbEORTerrain
    KIFER::BatchB.mimicry_update_all(self)
  end
end

#-------------------------------------------------------------------------------
# Amplifier – sound moves x1.3 power
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:AMPLIFIER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER.sound_move?(move)
  }
)

#-------------------------------------------------------------------------------
# Rampage – no recharge turn after a move that KOs
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:RAMPAGE,
  proc { |ability, user, targets, move, battle|
    next if user.effects[PBEffects::HyperBeam] <= 0
    next unless targets.any? { |b| b.damageState.fainted }
    user.effects[PBEffects::HyperBeam] = 0
  }
)

#-------------------------------------------------------------------------------
# Overwhelm – Intimidate and Scare don't affect it
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  def kifer_b_overwhelm_blocks
    @battle.pbShowAbilitySplash(self, false, true, KIFER.ability_name(:OVERWHELM))
    @battle.pbDisplay(_INTL("{1}'s stats were not lowered!", pbThis))
    @battle.pbHideAbilitySplash(self)
  end

  alias kifer_b_pbLowerAttackStatStageIntimidate pbLowerAttackStatStageIntimidate unless method_defined?(:kifer_b_pbLowerAttackStatStageIntimidate)
  def pbLowerAttackStatStageIntimidate(user)
    if !fainted? && hasActiveAbility?(:OVERWHELM)
      kifer_b_overwhelm_blocks
      return false
    end
    return kifer_b_pbLowerAttackStatStageIntimidate(user)
  end

  alias kifer_b_pbLowerStatStageByAbility pbLowerStatStageByAbility unless method_defined?(:kifer_b_pbLowerStatStageByAbility)
  def pbLowerStatStageByAbility(stat, increment, user, splashAnim = true, checkContact = false, ability_name = nil)
    if ability_name && ability_name == KIFER.ability_name(:SCARE) && !fainted? &&
       hasActiveAbility?(:OVERWHELM)
      kifer_b_overwhelm_blocks
      return false
    end
    return kifer_b_pbLowerStatStageByAbility(stat, increment, user, splashAnim, checkContact, ability_name)
  end

  #-----------------------------------------------------------------------------
  # Per-battler state (Mimicry) is cleared when a Pokemon comes in
  #-----------------------------------------------------------------------------
  alias kifer_b_pbInitEffects pbInitEffects unless method_defined?(:kifer_b_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_b_pbInitEffects(batonPass)
    @kifer_b_mimic_type  = nil
    @kifer_b_mimic_saved = nil
  end

  # Curlipede's old flag name, now Coil Up's (022)
  def kifer_b_coiled; kifer_c[:coiled]; end
  def kifer_b_coiled=(v); kifer_c[:coiled] = v; end

  #-----------------------------------------------------------------------------
  # Ice Dew – draws in Ice moves (after Follow Me / Spotlight, like Storm Drain)
  #-----------------------------------------------------------------------------
  alias kifer_b_pbChangeTargets pbChangeTargets unless method_defined?(:kifer_b_pbChangeTargets)
  def pbChangeTargets(move, user, targets)
    targets = kifer_b_pbChangeTargets(move, user, targets)
    return targets if @battle.switching || move.cannotRedirect?
    target_data = move.pbTarget(user)
    return targets if !target_data.can_target_one_foe? || targets.length != 1
    return targets if KIFER::BatchB.target_forced?(@battle, user)
    priority = @battle.pbPriority(true)
    nearOnly = !target_data.can_choose_distant_target?
    return pbChangeTargetByAbility(:ICEDEW, :ICE, move, user, targets, priority, nearOnly)
  end

  #-----------------------------------------------------------------------------
  # Glacial Ghost – no hail damage
  #-----------------------------------------------------------------------------
  alias kifer_b_takesHailDamage? takesHailDamage? unless method_defined?(:kifer_b_takesHailDamage?)
  def takesHailDamage?
    return false unless kifer_b_takesHailDamage?
    return false if hasActiveAbility?(:GLACIALGHOST)
    return true
  end

  #-----------------------------------------------------------------------------
  # Mimicry – takes the terrain's type, and its old types back after
  #-----------------------------------------------------------------------------
  def kifer_b_mimicry_update
    return if !@pokemon
    want = nil
    if !fainted? && hasActiveAbility?(:MIMICRY)
      want = KIFER::BatchB::MIMICRY_TYPES[@battle.field.terrain]
      want = nil if want && !GameData::Type.exists?(want)
    end
    if want
      return if @kifer_b_mimic_type == want
      @kifer_b_mimic_saved ||= [@type1, @type2, @effects[PBEffects::Type3]]
      @kifer_b_mimic_type = want
      @battle.pbShowAbilitySplash(self, false, true, KIFER.ability_name(:MIMICRY))
      pbChangeTypes(want)
      @battle.pbDisplay(_INTL("{1} transformed into the {2} type!", pbThis, GameData::Type.get(want).name))
      @battle.pbHideAbilitySplash(self)
    elsif @kifer_b_mimic_saved
      @type1, @type2, @effects[PBEffects::Type3] = @kifer_b_mimic_saved
      @kifer_b_mimic_saved = nil
      @kifer_b_mimic_type  = nil
      @battle.pbDisplay(_INTL("{1} returned to its original type!", pbThis)) if !fainted?
    end
  end
end

#-------------------------------------------------------------------------------
# Majestic Moth – on entry: +1 to its highest stat (stages counted)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:MAJESTICMOTH,
  proc { |ability, battler, battle|
    stat = KIFER::BatchD.highest_stat(battler)
    next if !battler.pbCanRaiseStatStage?(stat, battler)
    battler.pbRaiseStatStageByAbility(stat, 1, battler, true, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Power Spot – allies' moves x1.3 power
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAllyAbility.add(:POWERSPOT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3
  }
)

#-------------------------------------------------------------------------------
# Precise Fist – punching moves get +1 crit stage
#-------------------------------------------------------------------------------
BattleHandlers::CriticalCalcUserAbility.add(:PRECISEFIST,
  proc { |ability, user, target, c|
    m = KIFER::BatchA.crit_move   # (the crit handler isn't given the move, 020)
    next c + 1 if m && KIFER.punch_move?(m)
    next c
  }
)

#-------------------------------------------------------------------------------
# Antarctic Bird – its Ice and Flying moves x1.3 Attack
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:ANTARCTICBIRD,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 1.3 if type == :ICE || type == :FLYING
  }
)

#-------------------------------------------------------------------------------
# Firefighter – x1.5 damage to Fire types, x0.5 damage from Fire types
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:FIREFIGHTER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 1.5 if target.pbHasType?(:FIRE)
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:FIREFIGHTER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.5 if user.pbHasType?(:FIRE)
  }
)

#-------------------------------------------------------------------------------
# Combat Specialist – punching and kicking moves x1.3 power
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:COMBATSPECIALIST,
  proc { |ability, user, target, move, mults, baseDmg, type|
    if KIFER.punch_move?(move) || KIFER.kick_move?(move)
      mults[:base_damage_multiplier] *= 1.3
    end
  }
)

#-------------------------------------------------------------------------------
# Earth Eater – Ground moves don't hurt it and heal 1/4 of its max HP
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:EARTHEATER,
  proc { |ability, user, target, move, type, battle|
    next pbBattleMoveImmunityHealAbility(user, target, move, type, :GROUND, battle)
  }
)

#-------------------------------------------------------------------------------
# Ice Dew – Ice moves don't hurt it and raise its higher attacking stat
#   (Sp. Atk on a tie)
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:ICEDEW,
  proc { |ability, user, target, move, type, battle|
    next false if type != :ICE
    atk = KIFER::BatchD.staged(target, :ATTACK)
    spa = KIFER::BatchD.staged(target, :SPECIAL_ATTACK)
    stat = (spa < atk) ? :ATTACK : :SPECIAL_ATTACK
    next pbBattleMoveImmunityStatAbility(user, target, move, type, :ICE, stat, 1, battle)
  }
)

#-------------------------------------------------------------------------------
# Curlipede – Let's Roll (Defense +1, Defense Curl) + Coil Up (first biting
# move gets +1 priority; Coil Up's flag and handler in 022, used up once a
# biting move lands)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:CURLIPEDE,
  proc { |ability, battler, battle|
    name = KIFER.ability_name(ability)
    if battler.pbCanRaiseStatStage?(:DEFENSE, battler)
      battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler, true, name)
    end
    battler.effects[PBEffects::DefenseCurl] = true
    battler.kifer_c[:coiled] = true
  }
)

#-------------------------------------------------------------------------------
# Glacial Ghost – in hail: Speed x1.5 and evasion x1.25
#-------------------------------------------------------------------------------
BattleHandlers::SpeedCalcAbility.add(:GLACIALGHOST,
  proc { |ability, battler, mult|
    next mult * 1.5 if battler.battle.pbWeather == :Hail
    next mult
  }
)

BattleHandlers::AccuracyCalcTargetAbility.add(:GLACIALGHOST,
  proc { |ability, mods, user, target, move, type|
    mods[:evasion_multiplier] *= 1.25 if target.battle.pbWeather == :Hail
  }
)

#-------------------------------------------------------------------------------
# Mimicry – on entry, takes the type of the terrain there is
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:MIMICRY,
  proc { |ability, battler, battle|
    battler.kifer_b_mimicry_update
  }
)

#-------------------------------------------------------------------------------
# Powder Burst – on entry: uses Powder on a random foe (this round, a Fire move
# from it explodes for 1/4 of its max HP instead)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:POWDERBURST,
  proc { |ability, battler, battle|
    foes = []
    battle.eachOtherSideBattler(battler.index) { |b| foes << b }
    next if foes.empty?
    target = foes[battle.pbRandom(foes.length)]
    next if target.effects[PBEffects::Powder]
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    if target.affectedByPowder?(true)
      target.effects[PBEffects::Powder] = true
      battle.pbDisplay(_INTL("{1} is covered in powder!", target.pbThis))
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Rain Shroud – evasion x1.3 in rain
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcTargetAbility.add(:RAINSHROUD,
  proc { |ability, mods, user, target, move, type|
    mods[:evasion_multiplier] *= 1.3 if [:Rain, :HeavyRain].include?(target.battle.pbWeather)
  }
)

#-------------------------------------------------------------------------------
# Salt Circle – foes can't switch out or flee (moves that switch still work)
#-------------------------------------------------------------------------------
BattleHandlers::TrappingTargetAbility.add(:SALTCIRCLE,
  proc { |ability, switcher, bearer, battle|
    next true
  }
)

#-------------------------------------------------------------------------------
# Pollinate (Bug-type user) – powder moves, Powder and Effect Spore don't
# affect it
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_b_affectedByPowder? affectedByPowder? unless method_defined?(:kifer_b_affectedByPowder?)
  def affectedByPowder?(showMsg = false)
    if KIFER::BatchB.pollinate_powder_immune?(self)
      if showMsg
        @battle.pbShowAbilitySplash(self, false, true, KIFER.ability_name(:POLLINATE))
        @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis))
        @battle.pbHideAbilitySplash(self)
      end
      return false
    end
    return kifer_b_affectedByPowder?(showMsg)
  end

  alias kifer_b_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget unless method_defined?(:kifer_b_pbSuccessCheckAgainstTarget)
  def pbSuccessCheckAgainstTarget(move, user, target)
    if move.powderMove? && target.index != user.index && KIFER::BatchB.pollinate_powder_immune?(target)
      @battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(:POLLINATE))
      @battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
      @battle.pbHideAbilitySplash(target)
      return false
    end
    return kifer_b_pbSuccessCheckAgainstTarget(move, user, target)
  end
end

#-------------------------------------------------------------------------------
# Tectonize (Ground-type user) – Stealth Rock and Spikes don't hurt it on
# entry
#-------------------------------------------------------------------------------
class PokeBattle_Battle
  alias kifer_b_pbOnActiveOne pbOnActiveOne unless method_defined?(:kifer_b_pbOnActiveOne)
  def pbOnActiveOne(battler)
    if !battler || battler.fainted? || !battler.pbHasType?(:GROUND) || !battler.hasActiveAbility?(:TECTONIZE)
      return kifer_b_pbOnActiveOne(battler)
    end
    return KIFER.hazard_proof(battler) { kifer_b_pbOnActiveOne(battler) }
  end
end
