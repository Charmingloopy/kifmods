#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch H)
#   Mechanics follow Elite Redux 2.65 (its C source and in-game texts).
#
#   Chloroplast     – its Weather Ball, Solar Beam/Blade, Growth, Moonlight,
#                     Morning Sun, Synthesis and Grass/Water Pledge work as if
#                     in sun (Weather Ball: Fire, x2 power; Solar moves: no
#                     charge turn and no weather cut; Growth: +2/+2; healing
#                     moves: 2/3 HP; Grass Pledge: sea of fire on the foes'
#                     side; Water Pledge: rainbow on its side). Sun abilities
#                     don't trigger.
#   Fatal Precision – its super-effective attacks never miss (even a foe in
#                     the air or underground, as in ER's code) and always crit
#   Fort Knox       – foes' damage boosting abilities don't work on it (their
#                     damage cuts still do). Blocks Hyper Aggressive's 2nd hit
#                     and Speed Force; Parental Bond and Multi-Headed still work.
#   Weather Control – Thunder, Solar Beam/Blade, Hurricane, Blizzard, Silver
#                     Wind, Weather Ball, the wind Storm moves, Sheer Cold and
#                     Pledge moves don't affect it (an ally's too)
#   Juggernaut      – physical contact moves add 20% of its Defense to its
#                     Attack; can't be paralyzed (cured if it is)
#   Looter          – a KO with its attack heals 1/4 of its max HP
#   Emanate         – its Normal moves become Psychic. Psychic-type user: its
#                     Psychic moves have a 10% chance to confuse; other users:
#                     Psychic moves get the 1.5x same-type boost.
#   Accelerate      – two-turn moves are used in one turn (as with a Power
#                     Herb, but nothing is used up). Not Sky Drop.
#   Mighty Horn     – horn and drill moves x1.3
#   Aquatic         – on entry: adds the Water type
#   North Wind      – on entry: Aurora Veil on its side for 3 turns (5 with
#                     Light Clay), if it isn't up already; no hail damage
#   Two Step        – after it uses a dance move: a 50 power Revelation Dance
#   Elude           – hit by a non-contact move: its Speed is used in place of
#                     Defense / Sp. Def (raw Speed and its stages; Choice Scarf
#                     doesn't count)
#   Sun Basking     – in sun: foes' priority moves can't be used on its side
#                     and physical hits on it x0.5
#   Blur            – same as Elude, for contact moves
#   Dragonfly       – on entry: adds the Dragon type; floats like Levitate
#                     (Ground moves, Spikes, terrain)
#   Frozen Soul     – its Ice moves get +1 priority at full HP
#   Mixed Martial Arts – its Normal moves count as punching and kicking
#                     moves, for every ability that boosts those (Iron Fist,
#                     Striker, Power Fists, Combat Specialist, Precise Fist...;
#                     they check KIFER::BatchH.mma_move?)
#   Rockhard Will   – Rock moves x1.2, x1.5 at 1/3 HP or less
#   Suppress        – on entry: Torment on the foes next to it
#   Amphibious      – Water moves get the 1.5x same-type boost (2x with
#                     Adaptability). Can't be drenched (checked in 031's
#                     KIFER::Drench.on_hit).
#   Combustion      – Fire moves x1.5
#   Hemotoxin       – a Pokemon it poisons has its ability and innates turned
#                     off (as Gastro Acid) until it switches out
#   Phantom         – on entry: adds the Ghost type
#   Retriever       – switching out (not fainted) with no item: gets its
#                     battle-start item back
#   Super Hot Goo   – hit by a contact move: 30% chance to burn the attacker,
#                     and the attacker's Speed -1
#   Whiplash        – its physical hits lower the target's Defense by 1 after
#                     the damage, once per target each turn
#
# Left out at first, now coded in 030-035 (fog, frostbite/bleeding,
# fear, Toxic Terrain/enrage, one-offs).
#===============================================================================
KIFER.er_code(:CHLOROPLAST, :FATALPRECISION, :FORTKNOX, :WEATHERCONTROL, :JUGGERNAUT,
                :LOOTER, :EMANATE, :ACCELERATE, :MIGHTYHORN, :AQUATIC, :NORTHWIND,
                :TWOSTEP, :ELUDE, :SUNBASKING, :BLUR, :DRAGONFLY, :FROZENSOUL,
                :MIXEDMARTIALARTS, :ROCKHARDWILL, :SUPPRESS, :AMPHIBIOUS, :COMBUSTION,
                :HEMOTOXIN, :PHANTOM, :RETRIEVER, :SUPERHOTGOO, :WHIPLASH)

module KIFER
  module BatchH
    # ER's horn and drill moves (Mighty Horn)
    HORN_MOVES = [
      :HORNATTACK, :FURYATTACK, :HORNDRILL, :PECK, :DRILLPECK, :MEGAHORN,
      :POISONJAB, :DRILLRUN, :HORNLEECH, :SMARTSTRIKE, :PSYCHOCUT
    ].freeze

    # Moves Weather Control stops. Moves PIF doesn't have are never used.
    # Follows the ability's own move list (Silver Wind in, Ominous Wind out),
    # not ER's weather flag.
    WEATHER_MOVES = [
      :THUNDER, :SOLARBEAM, :SOLARBLADE, :HURRICANE, :BLIZZARD, :SILVERWIND,
      :WEATHERBALL, :BLEAKWINDSTORM, :WILDBOLTSTORM, :SANDSEARSTORM,
      :SPRINGTIDESTORM, :SHEERCOLD, :FIREPLEDGE, :WATERPLEDGE, :GRASSPLEDGE
    ].freeze

    # Ways of choosing the attacking stat that come before Juggernaut in ER
    JUGGERNAUT_BEFORE = [:EQUINOX, :ANCIENTIDOL, :MOMENTUM, :SPEEDFORCE]

    # hasActiveAbility? without leaving the innate's name on the battler (for
    # checks that show no splash)
    def self.has?(battler, id)
      return false unless battler
      old = battler.respond_to?(:kifer_inline) ? battler.kifer_inline : nil
      ret = battler.hasActiveAbility?(id)
      battler.instance_variable_set(:@kifer_inline, old)
      return ret
    end

    def self.sunny?(battle)
      return [:Sun, :HarshSun].include?(battle.pbWeather)
    end

    def self.chloroplast?(user)
      return has?(user, :CHLOROPLAST)
    end

    # Fort Knox: the target blocks the user's damage boosting abilities
    def self.fort_knox?(user, target)
      return false if !user || !target || user.equal?(target)
      return false unless target.respond_to?(:opposes?) && KIFER.on_field?(target.battle, :FORTKNOX)
      return false unless target.opposes?(user)
      return false if target.battle.moldBreaker
      return has?(target, :FORTKNOX)
    end

    # Runs a damage handler on a copy of the multipliers and keeps only the
    # parts that lower damage
    def self.no_boosts(mults)
      copy = mults.dup
      yield copy
      mults.keys.each do |k|
        old = mults[k]
        new = copy[k]
        next if !old.is_a?(Numeric) || !new.is_a?(Numeric)
        mults[k] = new if new < old
      end
    end

    def self.super_effective?(move, user, target)
      return false unless move && user && target && move.damagingMove?
      type = move.calcType || move.pbCalcType(user)
      return false unless type
      return Effectiveness.super_effective?(move.pbCalcTypeMod(type, user, target))
    end

    def self.fatal_precision?(move, user, target)
      return false unless user && target && has?(user, :FATALPRECISION)
      return super_effective?(move, user, target)
    end

    # Elude / Blur: the target's Speed stands in for its defense stat
    def self.speed_defense?(move, user, target)
      return false if !target || target.battle.moldBreaker
      return false unless KIFER.on_field?(target.battle, :BLUR) || KIFER.on_field?(target.battle, :ELUDE)
      contact = move.pbContactMove?(user)
      return has?(target, contact ? :BLUR : :ELUDE)
    end

    # Juggernaut adds 20% of its Defense to this hit (Power Core doesn't add
    # its own on top: in ER they are one or the other, and Juggernaut wins)
    def self.juggernaut?(move, user, target)
      return false unless move.physicalMove? && KIFER.on_field?(user.battle, :JUGGERNAUT) &&
                          move.pbContactMove?(user) && has?(user, :JUGGERNAUT)
      return false if JUGGERNAUT_BEFORE.any? { |a| has?(user, a) }
      return false if target && fort_knox?(user, target)
      return true
    end

    # Mixed Martial Arts: this use of the move counts as a punch and a kick
    def self.mma_move?(move)
      return move.instance_variable_get(:@kifer_h_mma) ? true : false
    end

    # Adds a third type on entry, to itself or (Monster Mash, 024) to target.
    # One added-type slot, as in ER: a type added later replaces an earlier one
    # (Aquatic, Phantom, Dragonfly; Grounded, Half Drake 022; Metallic 026)
    def self.add_type(ability, battler, battle, type, target = battler)
      return if !GameData::Type.exists?(type)
      return if target.pbHasType?(type) || !target.canChangeType?
      battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
      target.effects[PBEffects::Type3] = type
      battle.pbDisplay(_INTL("{1} transformed into the {2} type!", target.pbThis,
                             GameData::Type.get(type).name))
      battle.pbHideAbilitySplash(battler)
    end

    # Two Step: a 50 power Revelation Dance after a dance move
    def self.two_step(user, choice)
      battle = user.battle
      return if user.instance_variable_get(:@kifer_h_twostep)
      move = choice[2]
      return if !move || !move.danceMove?
      return if battle.decision > 0 || user.fainted?
      return if user.lastMoveUsed != move.id || user.lastMoveFailed
      return if user.effects[PBEffects::TwoTurnAttack]
      return if !GameData::Move.exists?(:REVELATIONDANCE)
      return if !user.hasActiveAbility?(:TWOSTEP)
      battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(:TWOSTEP))
      battle.pbHideAbilitySplash(user)
      target = choice[3]
      foe = (target.is_a?(Integer) && target >= 0) ? battle.battlers[target] : nil
      target = -1 if !foe || foe.fainted? || !foe.opposes?(user)
      oldLastRoundMoved = user.lastRoundMoved
      oldCurrentMove = user.currentMove
      user.instance_variable_set(:@kifer_h_twostep, true)
      begin
        KIFER.use_move_simple(user, :REVELATIONDANCE, target)   # its own priority (023)
      ensure
        user.instance_variable_set(:@kifer_h_twostep, false)
      end
      user.lastRoundMoved = oldLastRoundMoved
      user.currentMove = oldCurrentMove
    end

    # Hemotoxin: turns off the ability of a Pokemon it has just poisoned
    def self.hemotoxin(user, target)
      return if !user || user.equal?(target) || target.fainted?
      return if !target.poisoned? || target.effects[PBEffects::GastroAcid]
      return if target.unstoppableAbility?
      return if !user.hasActiveAbility?(:HEMOTOXIN)
      battle = target.battle
      battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(:HEMOTOXIN))
      target.effects[PBEffects::GastroAcid] = true
      target.effects[PBEffects::Truant]     = false
      battle.pbDisplay(_INTL("{1}'s Ability was suppressed!", target.pbThis))
      battle.pbHideAbilitySplash(user)
      target.pbOnAbilityChanged(target.ability)
    end
  end
end

#-------------------------------------------------------------------------------
# Fort Knox – foes' damage boosting abilities (and their allies' ones) only
# keep the parts that lower damage
#-------------------------------------------------------------------------------
class << BattleHandlers
  alias kifer_h_triggerDamageCalcUserAbility triggerDamageCalcUserAbility unless method_defined?(:kifer_h_triggerDamageCalcUserAbility)
  def triggerDamageCalcUserAbility(ability, user, target, move, mults, *rest)
    unless KIFER::BatchH.fort_knox?(user, target)
      return kifer_h_triggerDamageCalcUserAbility(ability, user, target, move, mults, *rest)
    end
    KIFER::BatchH.no_boosts(mults) do |m|
      kifer_h_triggerDamageCalcUserAbility(ability, user, target, move, m, *rest)
    end
  end

  alias kifer_h_triggerDamageCalcUserAllyAbility triggerDamageCalcUserAllyAbility unless method_defined?(:kifer_h_triggerDamageCalcUserAllyAbility)
  def triggerDamageCalcUserAllyAbility(ability, user, target, move, mults, *rest)
    unless KIFER::BatchH.fort_knox?(user, target)
      return kifer_h_triggerDamageCalcUserAllyAbility(ability, user, target, move, mults, *rest)
    end
    KIFER::BatchH.no_boosts(mults) do |m|
      kifer_h_triggerDamageCalcUserAllyAbility(ability, user, target, move, m, *rest)
    end
  end
end

class PokeBattle_Move
  #-----------------------------------------------------------------------------
  # Juggernaut – physical contact moves add 20% of its Defense to its Attack
  # (Fort Knox: 035 turns the attacker's abilities off, Hyper Aggressive and
  # Speed Force too)
  #-----------------------------------------------------------------------------
  alias kifer_h_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_h_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    stat, stage = kifer_h_pbGetAttackStats(user, target)
    if KIFER::BatchH.juggernaut?(self, user, nil)
      stat += (user.defense * 0.2).floor
    end
    return stat, stage
  end

  #-----------------------------------------------------------------------------
  # Elude / Blur – Speed in place of Defense / Sp. Def
  #-----------------------------------------------------------------------------
  alias kifer_h_pbGetDefenseStats pbGetDefenseStats unless method_defined?(:kifer_h_pbGetDefenseStats)
  def pbGetDefenseStats(user, target)
    if KIFER::BatchH.speed_defense?(self, user, target)
      return KIFER::BatchA.def_stat(self, :SPEED) { kifer_h_pbGetDefenseStats(user, target) }
    end
    return kifer_h_pbGetDefenseStats(user, target)
  end

  #-----------------------------------------------------------------------------
  # Mixed Martial Arts – its Normal moves are punches (and kicks)
  #-----------------------------------------------------------------------------
  alias kifer_h_pbCalcType pbCalcType unless method_defined?(:kifer_h_pbCalcType)
  def pbCalcType(user)
    ret = kifer_h_pbCalcType(user)
    @kifer_h_mma = (ret == :NORMAL && KIFER.on_field?(@battle, :MIXEDMARTIALARTS) &&
                      KIFER::BatchH.has?(user, :MIXEDMARTIALARTS))
    return ret
  end

  alias kifer_h_punchingMove? punchingMove? unless method_defined?(:kifer_h_punchingMove?)
  def punchingMove?
    return true if @kifer_h_mma
    return kifer_h_punchingMove?
  end
end

# Psyshock and co. have their own defense stat
class PokeBattle_Move_122
  alias kifer_h_122_pbGetDefenseStats pbGetDefenseStats unless method_defined?(:kifer_h_122_pbGetDefenseStats)
  def pbGetDefenseStats(user, target)
    if KIFER::BatchH.speed_defense?(self, user, target)
      return KIFER::BatchA.def_stat(self, :SPEED) { kifer_h_122_pbGetDefenseStats(user, target) }
    end
    return kifer_h_122_pbGetDefenseStats(user, target)
  end
end

BattleHandlers::CriticalCalcUserAbility.add(:FATALPRECISION,
  proc { |ability, user, target, c|
    # (the crit handler isn't given the move, 020 notes it)
    next 99 if KIFER::BatchH.super_effective?(KIFER::BatchA.crit_move, user, target)
  }
)

#-------------------------------------------------------------------------------
# Fatal Precision – super-effective attacks never miss
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_h_pbSuccessCheckPerHit pbSuccessCheckPerHit unless method_defined?(:kifer_h_pbSuccessCheckPerHit)
  def pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
    return true if KIFER::BatchH.fatal_precision?(move, user, target)
    return kifer_h_pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
  end

  #-----------------------------------------------------------------------------
  # Two Step – Revelation Dance after a dance move
  #-----------------------------------------------------------------------------
  alias kifer_h_pbUseMove pbUseMove unless method_defined?(:kifer_h_pbUseMove)
  def pbUseMove(choice, specialUsage = false)
    kifer_h_pbUseMove(choice, specialUsage)
    KIFER::BatchH.two_step(self, choice)
  ensure
    # Mixed Martial Arts' mark is for this use only
    choice[2].instance_variable_set(:@kifer_h_mma, false) if choice[2].is_a?(PokeBattle_Move)
  end

  #-----------------------------------------------------------------------------
  # Hemotoxin – poisoning turns the target's abilities off
  #-----------------------------------------------------------------------------
  alias kifer_h_pbInflictStatus pbInflictStatus unless method_defined?(:kifer_h_pbInflictStatus)
  def pbInflictStatus(newStatus, newStatusCount = 0, msg = nil, user = nil)
    kifer_h_pbInflictStatus(newStatus, newStatusCount, msg, user)
    KIFER::BatchH.hemotoxin(user, self) if newStatus == :POISON
  end

  #-----------------------------------------------------------------------------
  # Dragonfly – floats like Levitate
  #-----------------------------------------------------------------------------
  alias kifer_h_airborne? airborne? unless method_defined?(:kifer_h_airborne?)
  def airborne?
    return true if kifer_h_airborne?
    return false if hasActiveItem?(:IRONBALL)
    return false if @effects[PBEffects::Ingrain] || @effects[PBEffects::SmackDown]
    return false if @battle.field.effects[PBEffects::Gravity] > 0
    return true if !@battle.moldBreaker && KIFER.on_field?(@battle, :DRAGONFLY) && KIFER::BatchH.has?(self, :DRAGONFLY)
    return false
  end

  #-----------------------------------------------------------------------------
  # North Wind – no hail damage
  #-----------------------------------------------------------------------------
  alias kifer_h_takesHailDamage? takesHailDamage? unless method_defined?(:kifer_h_takesHailDamage?)
  def takesHailDamage?
    return false unless kifer_h_takesHailDamage?
    return false if KIFER::BatchH.has?(self, :NORTHWIND)
    return true
  end
end

#-------------------------------------------------------------------------------
# Chloroplast – moves that change in sun act as if it is sunny
#-------------------------------------------------------------------------------
class PokeBattle_Move_087   # Weather Ball
  alias kifer_h_087_pbBaseDamage pbBaseDamage unless method_defined?(:kifer_h_087_pbBaseDamage)
  def pbBaseDamage(baseDmg, user, target)
    if KIFER::BatchH.chloroplast?(user) && @battle.pbWeather == :None
      return baseDmg * 2
    end
    return kifer_h_087_pbBaseDamage(baseDmg, user, target)
  end

  alias kifer_h_087_pbBaseType pbBaseType unless method_defined?(:kifer_h_087_pbBaseType)
  def pbBaseType(user)
    return :FIRE if GameData::Type.exists?(:FIRE) && KIFER::BatchH.chloroplast?(user)
    return kifer_h_087_pbBaseType(user)
  end
end

class PokeBattle_Move_0C4   # Solar Beam, Solar Blade
  alias kifer_h_0c4_pbIsChargingTurn? pbIsChargingTurn? unless method_defined?(:kifer_h_0c4_pbIsChargingTurn?)
  def pbIsChargingTurn?(user)
    ret = kifer_h_0c4_pbIsChargingTurn?(user)
    if ret && !user.effects[PBEffects::TwoTurnAttack] && KIFER::BatchH.chloroplast?(user)
      @powerHerb = false
      @chargingTurn = true
      @damagingTurn = true
      return false
    end
    return ret
  end

  alias kifer_h_0c4_pbBaseDamageMultiplier pbBaseDamageMultiplier unless method_defined?(:kifer_h_0c4_pbBaseDamageMultiplier)
  def pbBaseDamageMultiplier(damageMult, user, target)
    return damageMult if KIFER::BatchH.chloroplast?(user)
    return kifer_h_0c4_pbBaseDamageMultiplier(damageMult, user, target)
  end
end

class PokeBattle_Move_028   # Growth
  alias kifer_h_028_pbOnStartUse pbOnStartUse unless method_defined?(:kifer_h_028_pbOnStartUse)
  def pbOnStartUse(user, targets)
    kifer_h_028_pbOnStartUse(user, targets)
    @statUp[1] = @statUp[3] = 2 if KIFER::BatchH.chloroplast?(user)
  end
end

class PokeBattle_Move_0D8   # Moonlight, Morning Sun, Synthesis
  alias kifer_h_0d8_pbOnStartUse pbOnStartUse unless method_defined?(:kifer_h_0d8_pbOnStartUse)
  def pbOnStartUse(user, targets)
    kifer_h_0d8_pbOnStartUse(user, targets)
    @healAmount = (user.totalhp * 2 / 3.0).round if KIFER::BatchH.chloroplast?(user)
  end
end

class PokeBattle_PledgeMove
  # Used alone in sun, Grass Pledge leaves a sea of fire and Water Pledge a
  # rainbow (as if Fire Pledge had joined in)
  alias kifer_h_pledge_pbEffectAfterAllHits pbEffectAfterAllHits unless method_defined?(:kifer_h_pledge_pbEffectAfterAllHits)
  def pbEffectAfterAllHits(user, target)
    kifer_h_pledge_pbEffectAfterAllHits(user, target)
    return if @pledgeCombo || @pledgeSetup
    return if ![:GRASSPLEDGE, :WATERPLEDGE].include?(@id)
    return if !KIFER::BatchH.chloroplast?(user)
    msg = nil
    anim = nil
    if @id == :GRASSPLEDGE
      if user.pbOpposingSide.effects[PBEffects::SeaOfFire] == 0
        user.pbOpposingSide.effects[PBEffects::SeaOfFire] = 4
        msg = _INTL("A sea of fire enveloped {1}!", user.pbOpposingTeam(true))
        anim = (user.opposes?) ? "SeaOfFire" : "SeaOfFireOpp"
      end
    elsif user.pbOwnSide.effects[PBEffects::Rainbow] == 0
      user.pbOwnSide.effects[PBEffects::Rainbow] = 4
      msg = _INTL("A rainbow appeared in the sky on {1}'s side!", user.pbTeam(true))
      anim = (user.opposes?) ? "RainbowOpp" : "Rainbow"
    end
    @battle.pbDisplay(msg) if msg
    @battle.pbCommonAnimation(anim) if anim
  end
end

#-------------------------------------------------------------------------------
# Accelerate – two-turn moves are used at once
#-------------------------------------------------------------------------------
class PokeBattle_TwoTurnMove
  alias kifer_h_2t_pbIsChargingTurn? pbIsChargingTurn? unless method_defined?(:kifer_h_2t_pbIsChargingTurn?)
  def pbIsChargingTurn?(user)
    ret = kifer_h_2t_pbIsChargingTurn?(user)
    if ret && @chargingTurn && !@damagingTurn && KIFER::BatchH.has?(user, :ACCELERATE)
      @damagingTurn = true
      return false
    end
    return ret
  end
end

#-------------------------------------------------------------------------------
# Two Step – the follow-up Revelation Dance has 50 power
#-------------------------------------------------------------------------------
class PokeBattle_Move_169
  alias kifer_h_169_pbBaseDamage pbBaseDamage unless method_defined?(:kifer_h_169_pbBaseDamage)
  def pbBaseDamage(baseDmg, user, target)
    return 50 if user.instance_variable_get(:@kifer_h_twostep)
    return kifer_h_169_pbBaseDamage(baseDmg, user, target)
  end
end

#-------------------------------------------------------------------------------
# Weather Control – weather moves don't affect it (foes' and allies')
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:WEATHERCONTROL,
  proc { |ability, user, target, move, type, battle|
    next false if user.index == target.index
    next false if !KIFER::BatchH::WEATHER_MOVES.include?(move.id)
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
    battle.pbHideAbilitySplash(target)
    next true
  }
)

#-------------------------------------------------------------------------------
# Dragonfly – Ground moves miss it (shown with its splash)
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:DRAGONFLY,
  proc { |ability, user, target, move, type, battle|
    next false if type != :GROUND || !move.damagingMove? || move.hitsFlyingTargets?
    next false if !target.airborne?
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("{1} avoided the attack!", target.pbThis))
    battle.pbHideAbilitySplash(target)
    next true
  }
)

#-------------------------------------------------------------------------------
# Juggernaut – can't be paralyzed
#-------------------------------------------------------------------------------
BattleHandlers::StatusImmunityAbility.add(:JUGGERNAUT,
  proc { |ability, battler, status|
    next true if status == :PARALYSIS
  }
)

BattleHandlers::StatusCureAbility.add(:JUGGERNAUT,
  proc { |ability, battler|
    next if battler.status != :PARALYSIS
    battler.battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.pbCureStatus(PokeBattle_SceneConstants::USE_ABILITY_SPLASH)
    if !PokeBattle_SceneConstants::USE_ABILITY_SPLASH
      battler.battle.pbDisplay(_INTL("{1}'s {2} cured its paralysis!", battler.pbThis,
                                     KIFER.ability_name(ability)))
    end
    battler.battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Looter – a KO with its attack heals 1/4 of its max HP
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.copy(:PREDATOR, :LOOTER)

#-------------------------------------------------------------------------------
# Emanate – Normal moves become Psychic; Psychic STAB or 10% confusion
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.add(:EMANATE,
  proc { |ability, user, move, type|
    next if type != :NORMAL || !GameData::Type.exists?(:PSYCHIC)
    next :PSYCHIC
  }
)

BattleHandlers::DamageCalcUserAbility.add(:EMANATE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :PSYCHIC || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

BattleHandlers::UserAbilityOnHit.add(:EMANATE,
  proc { |ability, user, target, move, battle|
    next if move.calcType != :PSYCHIC || !user.pbHasType?(:PSYCHIC)
    next if target.fainted? || battle.pbRandom(100) >= 10
    next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
    next if !target.pbCanConfuse?(user, false, move)
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    target.pbConfuse
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Mighty Horn – horn and drill moves x1.3
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:MIGHTYHORN,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER::BatchH::HORN_MOVES.include?(move.id)
  }
)

#-------------------------------------------------------------------------------
# Aquatic / Phantom / Dragonfly – add a type on entry
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:AQUATIC,
  proc { |ability, battler, battle|
    KIFER::BatchH.add_type(ability, battler, battle, :WATER)
  }
)

BattleHandlers::AbilityOnSwitchIn.add(:PHANTOM,
  proc { |ability, battler, battle|
    KIFER::BatchH.add_type(ability, battler, battle, :GHOST)
  }
)

BattleHandlers::AbilityOnSwitchIn.add(:DRAGONFLY,
  proc { |ability, battler, battle|
    KIFER::BatchH.add_type(ability, battler, battle, :DRAGON)
  }
)

#-------------------------------------------------------------------------------
# North Wind – Aurora Veil on entry for 3 turns (5 with Light Clay)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:NORTHWIND,
  proc { |ability, battler, battle|
    side = battler.pbOwnSide
    next if side.effects[PBEffects::AuroraVeil] > 0
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    side.effects[PBEffects::AuroraVeil] = battler.hasActiveItem?(:LIGHTCLAY) ? 5 : 3
    battle.pbDisplay(_INTL("Aurora Veil made {1} stronger against physical and special moves!",
                           battler.pbTeam(true)))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Sun Basking – in sun: blocks foes' priority moves; physical hits x0.5
#-------------------------------------------------------------------------------
BattleHandlers::MoveBlockingAbility.add(:SUNBASKING,
  proc { |ability, bearer, user, targets, move, battle|
    next false if !KIFER::BatchH.sunny?(battle)
    next false if !battle.choices[user.index][4] || battle.choices[user.index][4] <= 0
    next false if !bearer.opposes?(user)
    next false if !targets.any? { |b| b.opposes?(user) }
    next bearer.hasActiveAbility?(:SUNBASKING)   # names it on the game's splash
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:SUNBASKING,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if !move.physicalMove? || !KIFER::BatchH.sunny?(user.battle)
    mults[:final_damage_multiplier] *= 0.5
  }
)

#-------------------------------------------------------------------------------
# Frozen Soul – Ice moves +1 priority at full HP
#-------------------------------------------------------------------------------
BattleHandlers::PriorityChangeAbility.add(:FROZENSOUL,
  proc { |ability, battler, move, pri|
    next pri + 1 if battler.hp == battler.totalhp && move.pbCalcType(battler) == :ICE
  }
)

#-------------------------------------------------------------------------------
# Rockhard Will – Rock moves x1.2, x1.5 at 1/3 HP or less
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:ROCKHARDWILL,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= KIFER::BatchA.pinch_boost(user) if type == :ROCK
  }
)

#-------------------------------------------------------------------------------
# Suppress – Torment on the foes next to it on entry
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:SUPPRESS,
  proc { |ability, battler, battle|
    foes = []
    battle.eachOtherSideBattler(battler.index) do |b|
      next if !b.near?(battler) || b.effects[PBEffects::Torment]
      foes << b
    end
    next if foes.empty?
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    foes.each do |b|
      veil = b.hasActiveAbility?(:AROMAVEIL)
      b.eachAlly { |a| veil = true if a.hasActiveAbility?(:AROMAVEIL) }
      if veil && !battle.moldBreaker
        battle.pbDisplay(_INTL("{1} is protected by an aromatic veil!", b.pbThis))
        next
      end
      b.effects[PBEffects::Torment] = true
      battle.pbDisplay(_INTL("{1} was subjected to torment!", b.pbThis))
      b.pbItemStatusCureCheck
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Amphibious – Water moves get the same-type boost
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:AMPHIBIOUS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :WATER || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

#-------------------------------------------------------------------------------
# Combustion – Fire moves x1.5
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:COMBUSTION,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if type == :FIRE
  }
)

#-------------------------------------------------------------------------------
# Retriever – gets its item back when switching out
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchOut.add(:RETRIEVER,
  proc { |ability, battler, endOfBattle|
    next if endOfBattle || battler.fainted? || battler.item
    item = battler.initialItem
    next if !item || !GameData::Item.exists?(item)
    battler.item = item
    PBDebug.log("[Ability triggered] #{battler.pbThis}'s #{KIFER.ability_name(ability)} got back #{battler.itemName}")
  }
)

#-------------------------------------------------------------------------------
# Super Hot Goo – contact: 30% burn on the attacker, attacker's Speed -1
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:SUPERHOTGOO,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    name = KIFER.ability_name(ability)
    if !user.burned? && battle.pbRandom(100) < 30
      battle.pbShowAbilitySplash(target, false, true, name)
      if user.pbCanBurn?(target, PokeBattle_SceneConstants::USE_ABILITY_SPLASH) &&
         user.affectedByContactEffect?(PokeBattle_SceneConstants::USE_ABILITY_SPLASH)
        msg = nil
        if !PokeBattle_SceneConstants::USE_ABILITY_SPLASH
          msg = _INTL("{1}'s {2} burned {3}!", target.pbThis, name, user.pbThis(true))
        end
        user.pbBurn(target, msg)
      end
      battle.pbHideAbilitySplash(target)
    end
    user.pbLowerStatStageByAbility(:SPEED, 1, target, true, true, name)
  }
)

#-------------------------------------------------------------------------------
# Whiplash – physical hits: target's Defense -1, once per target each turn
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:WHIPLASH,
  proc { |ability, user, target, move, battle|
    next if !move.physicalMove? || target.fainted?
    next if target.instance_variable_get(:@kifer_h_whiplash) == battle.turnCount
    target.instance_variable_set(:@kifer_h_whiplash, battle.turnCount)
    target.pbLowerStatStageByAbility(:DEFENSE, 1, user, true, false, KIFER.ability_name(ability))
  }
)
