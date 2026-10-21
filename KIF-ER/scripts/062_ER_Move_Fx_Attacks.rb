#===============================================================================
# KIF: Elite Redux – Elite Redux effects of PIF attacks (needs 060's "Moves")
#   While Innates and Moves are On these moves use ER's numbers and effects
#   (their own move class, KERBxx, or a PIF class named below). With Moves Off
#   the game data holds PIF's function codes again, so they are PIF's moves.
#   Acrobatics      – x1.5 power without a held item (PIF: x2)
#   Astonish        – Fake Out's rules: first turn only, always flinches.
#                     Surprise!'s Astonish (030) still works on any turn.
#   Bug Bite, Pluck – eat a Berry as in PIF; any other item is knocked off
#   Covet, Thief    – steal the item, or knock it off when the user can't take
#                     it (it holds one); +1 priority while the user holds nothing
#   Kinesis         – the foe's item flies away and the foe flinches; fails if
#                     the foe has no item it can lose
#   Cross Poison    – hits twice
#   Double Slap     – 2-5 hits; the 3rd hit and later have the 10% confusion
#   Egg Bomb        – Fire, 30% burn (ER data); x1.5 power under Gravity
#   Flame Wheel     – Rollout's effect (PIF's code 0D3), no burn chance
#   Focus Punch     – doesn't fail when the user was hit: 40 power instead
#   Freeze Shock    – while it charges, a Pokemon that hits the user with a
#                     contact move is paralyzed (Beak Blast's rules)
#   Ice Burn        – the same, burned
#   Hold Back       – False Swipe with a 50% confusion chance
#   Horn Leech      – drains half; ignores the foe's Defense and evasion stages
#   Mega Drain      – drains 75%; Parabolic Charge – drains 25%
#   Rapid Spin      – also raises the user's Speed by 1
#   Rock Climb      – two turns, out of reach in the air on the first (as Fly),
#                     30% confusion
#   Round           – 20% flinch
#   Secret Power    – Hidden Power's type (physical, ER data); Techno Blast –
#                     Hidden Power's type (no Drives)
#   Seismic Toss    – Sky Drop that deals the user's level as damage
#   Sky Drop, Seismic Toss – the dropped foe takes its side's entry hazards
#                     (as on entry, with every immunity that applies there)
#   Self-Destruct   – x2 power if the user was hit this turn before it moved
#   Sky Attack      – raises Attack by 1 on the charging turn, no flinch
#   Smelling Salts  – cures the user's status after hitting (no x2 power)
#   Steam Eruption  – not weakened by sun
#   Struggle Bug    – always a critical hit while the user is below half HP
#                     (no Sp. Atk drop)
#   Synchronoise    – the user's second type (its only type if it has one);
#                     no longer fails on foes that share no type
#   Vice Grip       – very high crit ratio: 2 stages (the high-crit flag + 1)
#   Bleed hits      – Crabhammer, Dragon Claw, Drill Peck, Drill Run, Horn
#                     Attack, Leaf Blade, Night Slash, Psycho Cut, Shadow Claw,
#                     Stone Edge, X-Scissor and the ER moves Aqua Cutter,
#                     Berserker Horn, Black Magic, Devious Shot, Dragon Jab:
#                     their effect chance makes the target bleed (031; needs
#                     New features > Bleeding)
#   Drench hits     – Hydro Pump (30%), Water Gun (10%): the target gets
#                     drenched (031; needs New features > Drench)
#   Battle AI (both): each new code is scored as the PIF code it works like;
#     Kinesis on a foe with nothing to lose scores 0. Damage estimate:
#     Acrobatics x1.5, Cross Poison x2, Double Slap's average hits, Egg Bomb
#     x1.5 in Gravity, Seismic Toss = level, Steam Eruption in sun, Struggle
#     Bug's crits below half HP.
#===============================================================================
module KIFER
  module MoveFxAttacks
    # code => the PIF code it works like: two-turn checks (Gust hits Rock Climb,
    # Sky Drop's target...), the moves Metronome / Sleep Talk / Assist... can't
    # call, and the battle AI's score
    BASE = {
      "KERB01" => "086", "KERB02" => "012", "KERB03" => "0F4", "KERB04" => "0F1",
      "KERB05" => "0F0", "KERB06" => "005", "KERB07" => "0C0", "KERB08" => "00A",
      "KERB09" => "115", "KERB10" => "0E9", "KERB11" => "0DD", "KERB12" => "0DD",
      "KERB13" => "110", "KERB14" => "0C9", "KERB15" => "083", "KERB16" => "0CE",
      "KERB17" => "0C7", "KERB18" => "000", "KERB19" => "00A", "KERB20" => "000",
      "KERB21" => "000", "KERB22" => "000", "KERB23" => "0E0", "KERB24" => "0CE",
      "KERB25" => "0C5", "KERB26" => "0C6", "KERB27" => "000", "KERB28" => "000"
    }
    # the battle AI's score where the PIF code's would be wrong: Focus Punch
    # no longer fails, Sky Attack raises a stat while charging (Skull Bash)
    AI_AS = BASE.merge("KERB09" => "000", "KERB17" => "0C8")
    DRAIN = { :MEGADRAIN => 0.75, :PARABOLICCHARGE => 0.25 }
    CHARGE_STATUS = { "KERB25" => :PARALYSIS, "KERB26" => :BURN }
    CODE_OF = {}   # move class => its code (filled below)

    module_function

    # The battler whose move this is (nil for a move made on the spot)
    def owner(move)
      move.battle.battlers.each do |b|
        return b if b && b.moves.any? { |m| m.equal?(move) }
      end
      return nil
    end

    # Knock Off's rules for taking a target's item away
    def can_lose_item?(battle, user, target)
      return false if battle.wildBattle? && user.opposes?
      return false if !target.item || target.unlosableItem?(target.item)
      return false if target.hasActiveAbility?(:STICKYHOLD) && !battle.moldBreaker
      return true
    end

    def knock_off(battle, user, target)
      return false if user.fainted? || !can_lose_item?(battle, user, target)
      name = target.itemName
      target.pbRemoveItem(false)
      battle.pbDisplay(_INTL("{1} dropped its {2}!", target.pbThis, name))
      return true
    end

    # The dropped foe meets its side's entry hazards the way a Pokemon coming
    # in does (pbOnActiveOne, so every hazard immunity the mod adds applies)
    def drop_hazards(battle, target)
      return if target.fainted?
      battle.pbOnActiveOne(target)
    end

    def low_hp?(b); return b.hp * 2 < b.totalhp; end

    def sun_undone?(battle, type, user)
      return type == :WATER && [:Sun, :HarshSun].include?(battle.pbWeather) &&
             !user.hasActiveAbility?(:CATASTROPHE)   # Catastrophe (024) already turns it into x1.5
    end

    # Freeze Shock / Ice Burn: a contact hit on the charging user
    def charge_contact(move, user, target)
      return if user.fainted? || !target.opposes?(user)
      id = target.effects[PBEffects::TwoTurnAttack] or return
      st = CHARGE_STATUS[GameData::Move.get(id).function_code] or return
      return if !move.pbContactMove?(user) || !user.affectedByContactEffect?
      if st == :PARALYSIS
        user.pbParalyze(target) if user.pbCanParalyze?(target, false)
      else
        user.pbBurn(target) if user.pbCanBurn?(target, false)
      end
    end

    # Moves Metronome & co. can't call: the codes that work like listed ones
    def extend_blacklist(list)
      return if !list.is_a?(Array)
      BASE.each { |code, base| list << code if list.include?(base) && !list.include?(code) }
    end

    # Battle AI: base power estimate for the codes whose power rule is new
    def ai_base_damage(battle, ret, code, move, user, target)
      bd = move.baseDamage
      case code
      when "KERB01" then return user.item ? bd : (bd * 1.5).round
      when "KERB06" then return bd * 2
      when "KERB07" then return user.hasActiveAbility?(:SKILLLINK) ? bd * 5 : (bd * 19 / 6).floor
      when "KERB08" then return battle.field.effects[PBEffects::Gravity] > 0 ? (bd * 1.5).round : bd
      end
      return ret
    end

    # Battle AI: damage estimate for the rules the AIs can't see
    def ai_damage(battle, ret, code, move, user, target)
      case code
      when "KERB19" then return ret * 2 if sun_undone?(battle, move.type, user)
      when "KERB20" then return (ret * 1.5).round if low_hp?(user)
      end
      return ret
    end
  end
end

#-------------------------------------------------------------------------------
# Move classes (used only while Moves is On: only then do the moves carry these codes)
#-------------------------------------------------------------------------------
class PokeBattle_Move_KERB01 < PokeBattle_Move   # Acrobatics
  def pbBaseDamageMultiplier(damageMult, user, target)
    damageMult *= 1.5 if !user.item
    return damageMult
  end
end

class PokeBattle_Move_KERB02 < PokeBattle_Move_012   # Astonish
  def pbMoveFailed?(user, targets)
    return false if user.instance_variable_get(:@kifer_f_extra)   # Surprise! (025's extra move)
    return super
  end
end

class PokeBattle_Move_KERB03 < PokeBattle_Move_0F4   # Bug Bite, Pluck
  def pbEffectAfterAllHits(user, target)
    return super if target.item && target.item.is_berry?
    return if target.damageState.unaffected || target.damageState.substitute
    KIFER::MoveFxAttacks.knock_off(@battle, user, target)
  end
end

class PokeBattle_Move_KERB04 < PokeBattle_Move_0F1   # Covet, Thief
  def priority
    u = KIFER::MoveFxAttacks.owner(self)
    return (u && !u.item) ? @priority + 1 : @priority
  end

  def pbEffectAfterAllHits(user, target)
    super
    return if target.damageState.unaffected || target.damageState.substitute
    KIFER::MoveFxAttacks.knock_off(@battle, user, target)   # nothing if it was stolen
  end
end

class PokeBattle_Move_KERB05 < PokeBattle_Move   # Kinesis
  def pbFailsAgainstTarget?(user, target)
    return false if KIFER::MoveFxAttacks.can_lose_item?(@battle, user, target)
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbEffectAgainstTarget(user, target)
    name = target.itemName
    target.pbRemoveItem(false)
    @battle.pbDisplay(_INTL("{1}'s {2} flew away!", target.pbThis, name))
    target.pbFlinch(user)
  end
end

class PokeBattle_Move_KERB06 < PokeBattle_Move_005   # Cross Poison
  def multiHitMove?; return true; end
  def pbNumHits(user, targets); return 2; end
end

class PokeBattle_Move_KERB07 < PokeBattle_Move_0C0   # Double Slap
  def pbInitialEffect(user, targets, hitNum)
    @kifer_mfa_hit = hitNum
    super
  end

  def pbAdditionalEffect(user, target)
    return if (@kifer_mfa_hit || 0) < 2 || target.damageState.substitute   # from the 3rd hit
    target.pbConfuse if target.pbCanConfuse?(user, false, self)
  end
end

class PokeBattle_Move_KERB08 < PokeBattle_Move_00A   # Egg Bomb
  def pbBaseDamageMultiplier(damageMult, user, target)
    damageMult *= 1.5 if @battle.field.effects[PBEffects::Gravity] > 0
    return damageMult
  end
end

class PokeBattle_Move_KERB09 < PokeBattle_Move   # Focus Punch
  def pbDisplayChargeMessage(user)   # as PIF's (115)
    user.effects[PBEffects::FocusPunch] = true
    @battle.pbCommonAnimation("FocusPunch", user)
    @battle.pbDisplay(_INTL("{1} is tightening its focus!", user.pbThis))
  end

  def pbBaseDamage(baseDmg, user, target)
    return 40 if user.effects[PBEffects::FocusPunch] && user.lastHPLost > 0
    return baseDmg
  end
end

class PokeBattle_Move_KERB10 < PokeBattle_Move_0E9   # Hold Back
  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    target.pbConfuse if target.pbCanConfuse?(user, false, self)
  end
end

class PokeBattle_Move_KERB11 < PokeBattle_Move_0DD   # Horn Leech
  def pbCalcAccuracyModifiers(user, target, modifiers)
    super
    modifiers[:evasion_stage] = 0
  end

  def pbGetDefenseStats(user, target)
    stat, _stage = super
    return stat, 6
  end
end

class PokeBattle_Move_KERB12 < PokeBattle_Move_0DD   # Mega Drain, Parabolic Charge
  def pbEffectAgainstTarget(user, target)
    return if target.damageState.hpLost <= 0
    share = KIFER::MoveFxAttacks::DRAIN[@id] || 0.5
    user.instance_variable_set(:@kifer_f_draining, true)   # Absorbant (025) heals more from drains
    begin
      user.pbRecoverHPFromDrain((target.damageState.hpLost * share).round, target)
    ensure
      user.instance_variable_set(:@kifer_f_draining, false)
    end
  end
end

class PokeBattle_Move_KERB13 < PokeBattle_Move_110   # Rapid Spin
  def pbEffectAfterAllHits(user, target)
    super
    return if user.fainted? || target.damageState.unaffected
    user.pbRaiseStatStage(:SPEED, 1, user) if user.pbCanRaiseStatStage?(:SPEED, user, self)
  end
end

class PokeBattle_Move_KERB14 < PokeBattle_Move_0C9   # Rock Climb (Fly's semi-invulnerable turn)
  def pbChargingTurnMessage(user, targets)
    @battle.pbDisplay(_INTL("{1} climbed up high!", user.pbThis))
  end

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    target.pbConfuse if target.pbCanConfuse?(user, false, self)
  end
end

class PokeBattle_Move_KERB15 < PokeBattle_Move_083   # Round
  def flinchingMove?; return true; end

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    target.pbFlinch(user)
  end
end

class PokeBattle_Move_KERB24 < PokeBattle_Move_0CE   # Sky Drop
  def pbEffectAfterAllHits(user, target)
    super
    return if !@damagingTurn || target.damageState.unaffected || target.damageState.substitute
    KIFER::MoveFxAttacks.drop_hazards(@battle, target)
  end
end

class PokeBattle_Move_KERB16 < PokeBattle_Move_KERB24   # Seismic Toss
  def pbFixedDamage(user, target); return user.level; end

  def pbCalcDamage(user, target, numTargets = 1)   # as PIF's fixed-damage moves
    target.damageState.critical   = false
    target.damageState.calcDamage = [pbFixedDamage(user, target), 1].max
  end
end

class PokeBattle_Move_KERB17 < PokeBattle_TwoTurnMove   # Sky Attack
  def pbChargingTurnMessage(user, targets)
    @battle.pbDisplay(_INTL("{1} became cloaked in a harsh light!", user.pbThis))
  end

  def pbChargingTurnEffect(user, target)
    user.pbRaiseStatStage(:ATTACK, 1, user) if user.pbCanRaiseStatStage?(:ATTACK, user, self)
  end
end

class PokeBattle_Move_KERB18 < PokeBattle_Move   # Smelling Salts
  def pbEffectAfterAllHits(user, target)
    return if user.fainted? || user.status == :NONE || target.damageState.unaffected
    user.pbCureStatus
  end
end

class PokeBattle_Move_KERB19 < PokeBattle_Move_00A   # Steam Eruption
  def pbModifyDamage(damageMult, user, target)
    damageMult *= 2 if KIFER::MoveFxAttacks.sun_undone?(@battle, @calcType, user)   # undoes the sun's /2
    return damageMult
  end
end

class PokeBattle_Move_KERB20 < PokeBattle_Move   # Struggle Bug
  def pbCritialOverride(user, target)
    return 1 if KIFER::MoveFxAttacks.low_hp?(user)
    return super
  end
end

class PokeBattle_Move_KERB21 < PokeBattle_Move   # Synchronoise
  def pbBaseType(user)
    t = user.pbTypes
    return t[1] || t[0] || @type
  end
end

class PokeBattle_Move_KERB22 < PokeBattle_Move   # Vice Grip
  # shortcut: the extra crit stage is lent through Focus Energy's counter for
  # the length of the check (always put back); a crit-stage hook would be cleaner
  def pbIsCritical?(user, target)
    fe = PBEffects::FocusEnergy
    user.effects[fe] += 1
    begin
      return super
    ensure
      user.effects[fe] -= 1
    end
  end
end

class PokeBattle_Move_KERB23 < PokeBattle_Move_0E0   # Self-Destruct
  def pbBaseDamage(baseDmg, user, target)
    baseDmg *= 2 if user.tookDamage   # hit by a move this turn
    return baseDmg
  end
end

class PokeBattle_Move_KERB25 < PokeBattle_Move_0C5; end   # Freeze Shock (contact: KIFER::MoveFxAttacks.charge_contact)
class PokeBattle_Move_KERB26 < PokeBattle_Move_0C6; end   # Ice Burn

class PokeBattle_Move_KERB27 < PokeBattle_Move   # Bleed hit
  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute || !KIFER.feature_on?(:bleeding)
    target.pbBleed(user) if target.pbCanBleed?(user, false, self)
  end
end

class PokeBattle_Move_KERB28 < PokeBattle_Move   # Drench hit (the move's chance is already rolled)
  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    KIFER::Drench.on_hit(user, target, nil, 100)
  end
end

KIFER::MoveFxAttacks::BASE.each_key do |code|
  KIFER::MoveFxAttacks::CODE_OF[Object.const_get("PokeBattle_Move_#{code}")] = code
end

#-------------------------------------------------------------------------------
# Battler: the codes count as their PIF code in two-turn checks; Freeze Shock /
# Ice Burn punish contact while charging
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_mfa_inTwoTurnAttack? inTwoTurnAttack? unless method_defined?(:kifer_mfa_inTwoTurnAttack?)
  def inTwoTurnAttack?(*arg)
    return true if kifer_mfa_inTwoTurnAttack?(*arg)
    id = @effects[PBEffects::TwoTurnAttack]
    return false if !id
    base = KIFER::MoveFxAttacks::BASE[GameData::Move.get(id).function_code]
    return !base.nil? && arg.include?(base)
  end

  alias kifer_mfa_pbEffectsOnMakingHit pbEffectsOnMakingHit unless method_defined?(:kifer_mfa_pbEffectsOnMakingHit)
  def pbEffectsOnMakingHit(move, user, target)
    kifer_mfa_pbEffectsOnMakingHit(move, user, target)
    KIFER::MoveFxAttacks.charge_contact(move, user, target)
  end
end

# Metronome, Sleep Talk, Assist, Copycat, Mirror Move, Me First, Mimic,
# Sketch, Encore, Instruct: their "can't call" lists get the codes too
%w[05C 05D 0AF 0B0 0B4 0B5 0B6 0BC 16B].each do |c|
  k = (Object.const_get("PokeBattle_Move_#{c}") rescue nil)
  next if !k || k.instance_method(:initialize).owner != k
  orig = :"kifer_mfa_init_#{c}"
  next if k.private_method_defined?(orig) || k.method_defined?(orig)
  k.send(:alias_method, orig, :initialize)
  k.send(:define_method, :initialize) do |*args|
    send(orig, *args)
    KIFER::MoveFxAttacks.extend_blacklist(@moveBlacklist)
  end
  k.send(:private, :initialize)
end

#-------------------------------------------------------------------------------
# Battle AI (PIF's and DemICE's: KIF sends both through these methods). Reads
# only; the move's code is lent for the length of the call and put back.
#-------------------------------------------------------------------------------
class PokeBattle_AI
  alias kifer_mfa_pbGetMoveScoreFunctionCode pbGetMoveScoreFunctionCode unless method_defined?(:kifer_mfa_pbGetMoveScoreFunctionCode)
  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
    f = move && move.function
    as = KIFER::MoveFxAttacks::AI_AS[f]
    return kifer_mfa_pbGetMoveScoreFunctionCode(score, move, user, target, skill) if !as
    if f == "KERB05" && target && !KIFER::MoveFxAttacks.can_lose_item?(@battle, user, target)
      return KIFER::AI.demice_on? ? -score : 0   # Kinesis would fail
    end
    move.instance_variable_set(:@function, as)   # scored as the PIF move it works like
    begin
      return kifer_mfa_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
    ensure
      move.instance_variable_set(:@function, f)
    end
  end

  alias kifer_mfa_pbMoveBaseDamage pbMoveBaseDamage unless method_defined?(:kifer_mfa_pbMoveBaseDamage)
  def pbMoveBaseDamage(move, user, target, *rest)
    ret = kifer_mfa_pbMoveBaseDamage(move, user, target, *rest)
    code = move && KIFER::MoveFxAttacks::CODE_OF[move.class]
    return ret if !code || !ret.is_a?(Numeric)
    return KIFER::MoveFxAttacks.ai_base_damage(@battle, ret, code, move, user, target)
  end

  alias kifer_mfa_pbRoughDamage pbRoughDamage unless method_defined?(:kifer_mfa_pbRoughDamage)
  def pbRoughDamage(move, user, target, *args)
    code = move && KIFER::MoveFxAttacks::CODE_OF[move.class]
    if code == "KERB16"   # Seismic Toss: the user's level (Flying foes take none, as Sky Drop)
      return 0 if target.pbHasType?(:FLYING) || Effectiveness.ineffective?(pbCalcTypeMod(move.type, user, target))
      return user.level
    end
    ret = kifer_mfa_pbRoughDamage(move, user, target, *args)
    return ret if !code || !ret.is_a?(Numeric)
    return KIFER::MoveFxAttacks.ai_damage(@battle, ret, code, move, user, target)
  end
end

#-------------------------------------------------------------------------------
# Registering: ready while Moves is On, with the ER values the data lacks
#-------------------------------------------------------------------------------
KIFER::MoveFxAttacks::CODE_OF.each_key do |k|
  KIFER::TerrainEnrage.wrap_move_class(k) if defined?(KIFER::TerrainEnrage) && KIFER::TerrainEnrage.respond_to?(:wrap_move_class)
end
KIFER::Statuses.hook_heal_moves if defined?(KIFER::Statuses) && KIFER::Statuses.respond_to?(:hook_heal_moves)

KIFER::Moves.coded(:ACROBATICS, function_code: "KERB01")
KIFER::Moves.coded(:ASTONISH, function_code: "KERB02")
KIFER::Moves.coded(:BUGBITE, :PLUCK, function_code: "KERB03")
KIFER::Moves.coded(:COVET, :THIEF, function_code: "KERB04")
KIFER::Moves.coded(:KINESIS, function_code: "KERB05")
KIFER::Moves.coded(:CROSSPOISON, function_code: "KERB06")
KIFER::Moves.coded(:DOUBLESLAP, function_code: "KERB07")
KIFER::Moves.coded(:EGGBOMB, function_code: "KERB08")
KIFER::Moves.coded(:FLAMEWHEEL, function_code: "0D3", chance: 0)       # Rollout
KIFER::Moves.coded(:FOCUSPUNCH, function_code: "KERB09")
KIFER::Moves.coded(:FREEZESHOCK, function_code: "KERB25")
KIFER::Moves.coded(:ICEBURN, function_code: "KERB26")
KIFER::Moves.coded(:HOLDBACK, function_code: "KERB10", chance: 50)     # ER text: 50% (the ROM data says 0)
KIFER::Moves.coded(:HORNLEECH, function_code: "KERB11")
KIFER::Moves.coded(:MEGADRAIN, :PARABOLICCHARGE, function_code: "KERB12")
KIFER::Moves.coded(:RAPIDSPIN, function_code: "KERB13")
KIFER::Moves.coded(:ROCKCLIMB, function_code: "KERB14", chance: 30)    # ER text: 30% (the ROM data says 20)
KIFER::Moves.coded(:ROUND, function_code: "KERB15")
KIFER::Moves.coded(:SECRETPOWER, function_code: "090", chance: 0)      # Hidden Power
KIFER::Moves.coded(:TECHNOBLAST, function_code: "090")
KIFER::Moves.coded(:SEISMICTOSS, function_code: "KERB16")
KIFER::Moves.coded(:SELFDESTRUCT, function_code: "KERB23")
KIFER::Moves.coded(:SKYATTACK, function_code: "KERB17", chance: 0)
KIFER::Moves.coded(:SKYDROP, function_code: "KERB24")
KIFER::Moves.coded(:SMELLINGSALT, function_code: "KERB18")
KIFER::Moves.coded(:STEAMERUPTION, function_code: "KERB19")
KIFER::Moves.coded(:STRUGGLEBUG, function_code: "KERB20", chance: 0)
KIFER::Moves.coded(:SYNCHRONOISE, function_code: "KERB21")
KIFER::Moves.coded(:VICEGRIP, function_code: "KERB22")
KIFER::Moves.coded(:CRABHAMMER, :DRAGONCLAW, :DRILLPECK, :DRILLRUN, :HORNATTACK, :LEAFBLADE, :NIGHTSLASH,
                   :PSYCHOCUT, :SHADOWCLAW, :STONEEDGE, :XSCISSOR, function_code: "KERB27")
KIFER::Moves.coded(:AQUACUTTER, :BERSERKERHORN, :BLACKMAGIC, :DEVIOUSSHOT, :DRAGONJAB, function_code: "KERB27")   # ER-only (064)
KIFER::Moves.coded(:HYDROPUMP, function_code: "KERB28", chance: 30)   # ER text: 30% (the ROM data says 0)
KIFER::Moves.coded(:WATERGUN, function_code: "KERB28", chance: 10)    # ER text: 10% (the ROM data says 0)
