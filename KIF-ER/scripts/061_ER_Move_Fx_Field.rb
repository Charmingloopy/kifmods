#===============================================================================
# KIF: Elite Redux – Elite Redux versions of PIF's field, protect and status moves
#   Only while the "Moves" setting is On (KIFER::Moves.applied?). With Moves
#   Off every move here is exactly PIF's.
#
#   Sunny Day, Rain Dance, Sandstorm, Hail – 8 turns (12 with the weather rock,
#                    as 050 does for weather abilities)
#   Electric, Grassy, Misty, Psychic Terrain – 8 turns (12 with Terrain Extender)
#   Barrier        – fails outside Psychic Terrain. In it: Reflect and Light
#                    Screen on the user's side (5 turns, 8 with Light Clay);
#                    a screen already up is left alone, fails if both are up.
#   Quick Guard    – protects the user's side from priority moves for 3 turns
#                    (the turn it's used and the next two)
#   Magic Room     – 5 turns: nobody takes indirect damage (anything PIF's
#                    takesIndirectDamage? covers: poison, burn, weather,
#                    hazards, recoil, Leech Seed...) and nobody can Mega
#                    Evolve. Held items work. Using it again ends it.
#   Wonder Room    – 5 turns: every Pokemon's Attack and Sp. Atk are swapped
#                    and its Attack/Sp. Atk stages don't count when it attacks.
#                    Defense and Sp. Def stay. Using it again ends it.
#   Smokescreen    – targets the user's side: for 5 turns moves used on that
#                    side have their evasion x1.25 (25% more evasive). Fails
#                    while the smoke is up.
#   Miracle Eye    – the target's type matchups are reversed (as Inverse Room,
#                    034) until it switches out, and Dark moves don't affect
#                    its Psychic type
#   Camouflage     – Protect (+4 priority); an attack it blocks turns the user
#                    into that attack's type
#   Mind Reader    – Protect; a Pokemon whose attack it blocks gets -1 Sp. Def
#   Detect         – blocks moves used on it that can miss (accuracy above 0),
#                    also those that go through Protect; moves that can't miss
#                    hit. Feint and the like don't break it.
#   Needle Arm     – no flinch; its hit sets Creeping Thorns on the target's
#                    side (its 100% added effect: Sheer Force and Shield Dust
#                    stop it)
#   Creeping Thorns – a Pokemon coming in on that side loses 1/8 of its max HP
#                    times the Grass type's effectiveness on it (as Stealth
#                    Rock does with Rock). Magic Guard and Magic Room block it;
#                    Rapid Spin and Defog clear it.
#   Glare, Stun Spore – can paralyze Electric types
#   Thunder Wave, Will-O-Wisp, Leech Seed – never miss when the user is
#                    Electric / Fire / Grass type
#   Gastro Acid    – also poisons the target
#   Sweet Kiss     – confuses and infatuates; fails only if it can do neither
#   Bestow         – gives the user's held item and passes on its status (as
#                    Psycho Shift); fails only if it can do neither
#===============================================================================
module KIFER
  module MoveFxField
    WEATHER_MOVES = [:SUNNYDAY, :RAINDANCE, :SANDSTORM, :HAIL]
    TERRAIN_MOVES = [:ELECTRICTERRAIN, :GRASSYTERRAIN, :MISTYTERRAIN, :PSYCHICTERRAIN]
    NO_MISS       = { :THUNDERWAVE => :ELECTRIC, :WILLOWISP => :FIRE, :LEECHSEED => :GRASS }
    PARA_ELECTRIC = [:GLARE, :STUNSPORE]
    GUARDS        = [:DETECT, :CAMOUFLAGE, :MINDREADER]   # their PIF code here: 0AA (Protect)
    ROOM_TURNS    = 5
    SMOKE_TURNS   = 5
    QUICK_GUARD_TURNS = 3
    PASSIVE_STATUSES  = [:POISON, :BURN, :FROSTBITE, :BLEEDING]

    def self.er?(move, list)
      return KIFER::Moves.applied? && list.include?(move.id) && KIFER::Moves.ready?(move.id)
    end

    # ER weather / terrain from a move: 8 turns, 12 with the extender item
    def self.er_turns(d)
      return (d > 5) ? 12 : 8
    end

    def self.magic_room?(battle)
      return battle.instance_variable_get(:@kifer_mx_magic).to_i > 0
    end

    def self.wonder_room?(battle)
      return battle.instance_variable_get(:@kifer_mx_wonder).to_i > 0
    end

    def self.smoke?(side)
      return side.instance_variable_get(:@kifer_mx_smoke).to_i > 0
    end

    def self.thorns?(side)
      return side.instance_variable_get(:@kifer_mx_thorns) ? true : false
    end

    def self.team(battle, side)
      b = battle.battlers.find { |x| x && x.idxOwnSide == side }
      return b ? b.pbTeam(true) : nil
    end

    #---------------------------------------------------------------------------
    # Room toggles (Magic Room, Wonder Room)
    #---------------------------------------------------------------------------
    def self.toggle_room(battle, ivar, on_msg, off_msg)
      if battle.instance_variable_get(ivar).to_i > 0
        battle.instance_variable_set(ivar, 0)
        battle.pbDisplay(off_msg)
      else
        battle.instance_variable_set(ivar, ROOM_TURNS)
        battle.pbDisplay(on_msg)
      end
    end

    #---------------------------------------------------------------------------
    # Miracle Eye: reversed matchups on the marked Pokemon (battle and battle AI)
    #---------------------------------------------------------------------------
    def self.eye_mod(ret, moveType, defType, target)
      return ret if !moveType || !defType || !target || !target.instance_variable_get(:@kifer_mx_eye)
      return Effectiveness::INEFFECTIVE if moveType == :DARK && defType == :PSYCHIC
      # something else (Inverse Room, Foresight, Ring Target...) already decided it
      return ret if ret != Effectiveness.calculate_one(moveType, defType)
      return KIFER::Specials1.invert(ret)
    end

    #---------------------------------------------------------------------------
    # Detect, Camouflage, Mind Reader
    #---------------------------------------------------------------------------
    def self.detect_blocks?(move, user, target)
      return false if !target || target.equal?(user)
      return false if target.instance_variable_get(:@kifer_mx_guard) != :DETECT
      return move.pbBaseAccuracy(user, target) > 0
    end

    def self.after_block(battle, move, user, target)
      g = target.instance_variable_get(:@kifer_mx_guard)
      return if !g || g == :DETECT || !target.damageState.protected || !move.damagingMove?
      return if !target.effects[PBEffects::Protect]
      if g == :CAMOUFLAGE
        type = move.calcType || move.type
        return if !type || !GameData::Type.exists?(type) || !target.canChangeType? || !target.pbHasOtherType?(type)
        target.pbChangeTypes(type)
        battle.pbDisplay(_INTL("{1} transformed into the {2} type!", target.pbThis, GameData::Type.get(type).name))
      elsif g == :MINDREADER
        return if user.fainted? || !user.pbCanLowerStatStage?(:SPECIAL_DEFENSE, target)
        user.pbLowerStatStage(:SPECIAL_DEFENSE, 1, target)
      end
    end

    #---------------------------------------------------------------------------
    # Creeping Thorns on entry; :switched when the Pokemon left because of it
    #---------------------------------------------------------------------------
    def self.thorns_entry(battle, battler)
      return nil if !thorns?(battler.pbOwnSide) || !battler.takesIndirectDamage?
      return nil if defined?(KIFER::ERVersions) && KIFER::ERVersions.on? && battler.hasActiveAbility?(:SHIELDDUST)   # ER: immune to entry hazards
      t = battler.pbTypes(true)
      eff = Effectiveness.calculate(:GRASS, t[0], t[1], t[2])
      return nil if Effectiveness.ineffective?(eff)
      eff = eff.to_f / Effectiveness::NORMAL_EFFECTIVE
      old = battler.hp
      battler.pbReduceHP(battler.totalhp * eff / 8, false)
      battle.pbDisplay(_INTL("{1} was hurt by the creeping thorns!", battler.pbThis))
      battler.pbItemHPHealCheck
      return :switched if battler.pbAbilitiesOnDamageTaken(old)
      return nil
    end

    # Battle AI: HP a Pokemon with these types would lose to the thorns on entry
    def self.thorns_loss(side, types, totalhp)
      return 0 if !side || !thorns?(side)
      eff = Effectiveness.calculate(:GRASS, types[0], types[1], types[2])
      return 0 if Effectiveness.ineffective?(eff)
      return (totalhp * eff.to_f / Effectiveness::NORMAL_EFFECTIVE / 8).floor
    end

    # Battle AI: Rapid Spin / Defog are worth more with thorns to clear
    def self.thorns_cleanup(battle, move, user, target)
      bench = battle.pbAbleNonActiveCount(user.idxOwnSide) > 0
      if move.function == "110"   # 062's AI wrapper shows Rapid Spin (KERB13) as 110
        return (bench && thorns?(user.pbOwnSide)) ? 60 : 0
      elsif move.function == "049"
        v = 0
        v -= 30 if target && thorns?(target.pbOwnSide)
        v += 40 if bench && Settings::MECHANICS_GENERATION >= 6 && thorns?(user.pbOwnSide)
        return v
      end
      return 0
    end

    def self.clear_thorns(battle, side, user)
      return if !thorns?(side)
      side.instance_variable_set(:@kifer_mx_thorns, false)
      battle.pbDisplay(_INTL("{1} blew away the creeping thorns!", user.pbThis))
    end

    #---------------------------------------------------------------------------
    # Bestow
    #---------------------------------------------------------------------------
    def self.bestow_item?(user, target)
      return user.item && !user.unlosableItem?(user.item) && !target.item &&
             !target.unlosableItem?(user.item)
    end

    def self.bestow_status?(user, target, move)
      return user.status != :NONE && target.pbCanInflictStatus?(user.status, user, false, move)
    end

    # Psycho Shift's own effect (031 adds frostbite and bleeding to it)
    def self.pass_status(battle, user, target)
      PokeBattle_Move_01B.new(battle, Pokemon::Move.new(:PSYCHOSHIFT)).pbEffectAgainstTarget(user, target)
    end

    #---------------------------------------------------------------------------
    # End of round: per-round guards off, counters down
    #---------------------------------------------------------------------------
    def self.end_of_round(battle, guard_up = nil)
      battle.battlers.each { |b| b.instance_variable_set(:@kifer_mx_guard, nil) if b }
      return if battle.decision > 0
      [[:@kifer_mx_magic, _INTL("Magic Room wore off!")],
       [:@kifer_mx_wonder, _INTL("Wonder Room wore off, and the Attack and Sp. Atk stats returned to normal!")]].each do |iv, msg|
        n = battle.instance_variable_get(iv).to_i
        next if n <= 0
        battle.instance_variable_set(iv, n - 1)
        battle.pbDisplay(msg) if n == 1
      end
      battle.sides.each_with_index do |side, i|
        n = side.instance_variable_get(:@kifer_mx_qg).to_i
        if n > 0 && guard_up && !guard_up[i]
          side.instance_variable_set(:@kifer_mx_qg, 0)          # Feint broke it
        elsif n > 0
          side.instance_variable_set(:@kifer_mx_qg, n - 1)
          side.effects[PBEffects::QuickGuard] = true if n > 1   # PIF clears it each round
        end
        n = side.instance_variable_get(:@kifer_mx_smoke).to_i
        next if n <= 0
        side.instance_variable_set(:@kifer_mx_smoke, n - 1)
        t = team(battle, i)
        battle.pbDisplay(_INTL("The smoke around {1} cleared!", t)) if n == 1 && t
      end
    end

    #---------------------------------------------------------------------------
    # Battle AI: scores for the new function codes (PIF's AI: absolute score;
    # DemICE's: change from the starting score). Reads only.
    #---------------------------------------------------------------------------
    def self.passive(b)
      return 0 if !b
      return (PASSIVE_STATUSES.include?(b.status) || b.effects[PBEffects::LeechSeed] >= 0) ? 25 : 0
    end

    def self.ai_delta(battle, move, user, target)
      f = move.function
      return nil if !f.is_a?(String) || !f.start_with?("KERA")
      case f
      when "KERA01"   # Barrier
        side = user.pbOwnSide
        missing = (side.effects[PBEffects::Reflect] > 0 ? 0 : 1) + (side.effects[PBEffects::LightScreen] > 0 ? 0 : 1)
        return -90 if battle.field.terrain != :Psychic || missing == 0
        return 25 * missing
      when "KERA02"   # Magic Room
        v = passive(user) - passive(target)
        return magic_room?(battle) ? -v - 10 : v - 10
      when "KERA03"   # Wonder Room
        v = 0
        v += 20 if target && (target.stages[:ATTACK] > 0 || target.stages[:SPECIAL_ATTACK] > 0)
        v -= 20 if user.stages[:ATTACK] > 0 || user.stages[:SPECIAL_ATTACK] > 0
        return wonder_room?(battle) ? -v - 10 : v - 10
      when "KERA04"   # Smokescreen
        return smoke?(user.pbOwnSide) ? -90 : 20
      when "KERA05"   # Miracle Eye: worth it when the user's attacks are resisted
        return -60 if !target || target.instance_variable_get(:@kifer_mx_eye)
        t = target.pbTypes(true)
        weak = user.moves.any? do |m|
          next false if !m || !m.damagingMove? || !m.type
          Effectiveness.calculate(m.type, t[0], t[1], t[2]) < Effectiveness::NORMAL_EFFECTIVE
        end
        return weak ? 30 : -20
      when "KERA06"   # Needle Arm (its damage is scored apart)
        return 0 if !target || thorns?(target.pbOwnSide)
        return battle.pbAbleNonActiveCount(target.index) > 0 ? 15 : 0
      end
      return 0
    end
  end
end

#-------------------------------------------------------------------------------
# New move classes
#-------------------------------------------------------------------------------
# Barrier
class PokeBattle_Move_KERA01 < PokeBattle_Move
  def pbMoveFailed?(user, targets)
    side = user.pbOwnSide
    if @battle.field.terrain != :Psychic ||
       (side.effects[PBEffects::Reflect] > 0 && side.effects[PBEffects::LightScreen] > 0)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    side = user.pbOwnSide
    turns = user.hasActiveItem?(:LIGHTCLAY) ? 8 : 5
    if side.effects[PBEffects::Reflect] == 0
      side.effects[PBEffects::Reflect] = turns
      @battle.pbDisplay(_INTL("Reflect raised {1}'s Defense!", user.pbTeam(true)))
    end
    if side.effects[PBEffects::LightScreen] == 0
      side.effects[PBEffects::LightScreen] = turns
      @battle.pbDisplay(_INTL("Light Screen raised {1}'s Special Defense!", user.pbTeam(true)))
    end
  end
end

# Magic Room
class PokeBattle_Move_KERA02 < PokeBattle_Move
  def pbEffectGeneral(user)
    KIFER::MoveFxField.toggle_room(@battle, :@kifer_mx_magic,
      _INTL("It created a bizarre area in which Pokémon are protected from indirect damage!"),
      _INTL("The area returned to normal!"))
  end

  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
    return if KIFER::MoveFxField.magic_room?(@battle)   # no animation
    super
  end
end

# Wonder Room
class PokeBattle_Move_KERA03 < PokeBattle_Move
  def pbEffectGeneral(user)
    KIFER::MoveFxField.toggle_room(@battle, :@kifer_mx_wonder,
      _INTL("It created a bizarre area in which the Attack and Sp. Atk stats are swapped!"),
      _INTL("Wonder Room wore off, and the Attack and Sp. Atk stats returned to normal!"))
  end

  def pbShowAnimation(id, user, targets, hitNum = 0, showAnimation = true)
    return if KIFER::MoveFxField.wonder_room?(@battle)   # no animation
    super
  end
end

# Smokescreen
class PokeBattle_Move_KERA04 < PokeBattle_Move
  def pbMoveFailed?(user, targets)
    if KIFER::MoveFxField.smoke?(user.pbOwnSide)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbEffectGeneral(user)
    user.pbOwnSide.instance_variable_set(:@kifer_mx_smoke, KIFER::MoveFxField::SMOKE_TURNS)
    @battle.pbDisplay(_INTL("Smoke obscured {1}!", user.pbTeam(true)))
  end
end

# Miracle Eye
class PokeBattle_Move_KERA05 < PokeBattle_Move
  def ignoresSubstitute?(user); return true; end

  def pbEffectAgainstTarget(user, target)
    target.instance_variable_set(:@kifer_mx_eye, true)
    @battle.pbDisplay(_INTL("{1}'s type matchups were reversed!", target.pbThis))
  end
end

# Needle Arm
class PokeBattle_Move_KERA06 < PokeBattle_Move
  def pbAdditionalEffect(user, target)
    side = target.pbOwnSide
    return if KIFER::MoveFxField.thorns?(side)
    side.instance_variable_set(:@kifer_mx_thorns, true)
    @battle.pbDisplay(_INTL("Creeping thorns surround {1}!", target.pbTeam(true)))
  end
end

#-------------------------------------------------------------------------------
# PIF classes, changed for their ER move only
#-------------------------------------------------------------------------------
class PokeBattle_WeatherMove
  alias kifer_mx_wm_pbEffectGeneral pbEffectGeneral unless method_defined?(:kifer_mx_wm_pbEffectGeneral)
  def pbEffectGeneral(user)
    kifer_mx_wm_pbEffectGeneral(user)
    return if !KIFER::MoveFxField.er?(self, KIFER::MoveFxField::WEATHER_MOVES)
    f = @battle.field
    f.weatherDuration = KIFER::MoveFxField.er_turns(f.weatherDuration) if f.weather == @weatherType && f.weatherDuration > 0
  end
end

%w[154 155 156 173].each do |code|
  Object.const_get("PokeBattle_Move_#{code}").class_eval <<-RUBY, __FILE__, __LINE__ + 1
    alias kifer_mx_#{code}_pbEffectGeneral pbEffectGeneral unless method_defined?(:kifer_mx_#{code}_pbEffectGeneral)
    def pbEffectGeneral(user)
      kifer_mx_#{code}_pbEffectGeneral(user)
      return if !KIFER::MoveFxField.er?(self, KIFER::MoveFxField::TERRAIN_MOVES)
      f = @battle.field
      f.terrainDuration = KIFER::MoveFxField.er_turns(f.terrainDuration) if f.terrainDuration > 0
    end
  RUBY
end

# Quick Guard: 3 turns (the end of round sets it again)
class PokeBattle_Move_0AB
  alias kifer_mx_0AB_pbEffectGeneral pbEffectGeneral unless method_defined?(:kifer_mx_0AB_pbEffectGeneral)
  def pbEffectGeneral(user)
    kifer_mx_0AB_pbEffectGeneral(user)
    return if !KIFER::MoveFxField.er?(self, [:QUICKGUARD])
    user.pbOwnSide.instance_variable_set(:@kifer_mx_qg, KIFER::MoveFxField::QUICK_GUARD_TURNS)
  end
end

# Detect, Camouflage, Mind Reader (Protect's class)
class PokeBattle_Move_0AA
  alias kifer_mx_0AA_pbEffectGeneral pbEffectGeneral unless method_defined?(:kifer_mx_0AA_pbEffectGeneral)
  def pbEffectGeneral(user)
    return kifer_mx_0AA_pbEffectGeneral(user) if !KIFER::MoveFxField.er?(self, KIFER::MoveFxField::GUARDS)
    if @id == :DETECT   # its own guard, not Protect's (nothing breaks it)
      user.effects[PBEffects::ProtectRate] *= (Settings::MECHANICS_GENERATION >= 6) ? 3 : 2
      pbProtectMessage(user)
    else
      kifer_mx_0AA_pbEffectGeneral(user)
    end
    user.instance_variable_set(:@kifer_mx_guard, @id)
  end
end

# Glare, Stun Spore: Electric types can be paralyzed
class PokeBattle_Move_007
  alias kifer_mx_007_pbFailsAgainstTarget? pbFailsAgainstTarget? unless method_defined?(:kifer_mx_007_pbFailsAgainstTarget?)
  def pbFailsAgainstTarget?(user, target)
    return kifer_mx_007_pbFailsAgainstTarget?(user, target) if !KIFER::MoveFxField.er?(self, KIFER::MoveFxField::PARA_ELECTRIC)
    target.instance_variable_set(:@kifer_mx_no_elec, true)
    begin
      return kifer_mx_007_pbFailsAgainstTarget?(user, target)
    ensure
      target.instance_variable_set(:@kifer_mx_no_elec, false)
    end
  end
end

# Sweet Kiss: confusion and infatuation
class PokeBattle_Move_013
  alias kifer_mx_013_pbFailsAgainstTarget? pbFailsAgainstTarget? unless method_defined?(:kifer_mx_013_pbFailsAgainstTarget?)
  alias kifer_mx_013_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_mx_013_pbEffectAgainstTarget)
  def pbFailsAgainstTarget?(user, target)
    if KIFER::MoveFxField.er?(self, [:SWEETKISS])
      return false if target.pbCanConfuse?(user, false, self) || target.pbCanAttract?(user, false)
    end
    return kifer_mx_013_pbFailsAgainstTarget?(user, target)
  end

  def pbEffectAgainstTarget(user, target)
    return kifer_mx_013_pbEffectAgainstTarget(user, target) if !KIFER::MoveFxField.er?(self, [:SWEETKISS])
    target.pbConfuse if target.pbCanConfuse?(user, false, self)
    target.pbAttract(user) if target.pbCanAttract?(user, false)
  end
end

# Gastro Acid: also poisons
class PokeBattle_Move_068
  alias kifer_mx_068_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_mx_068_pbEffectAgainstTarget)
  def pbEffectAgainstTarget(user, target)
    kifer_mx_068_pbEffectAgainstTarget(user, target)
    return if !KIFER::MoveFxField.er?(self, [:GASTROACID])
    target.pbPoison(user) if target.pbCanPoison?(user, false, self)
  end
end

# Bestow: item and status
class PokeBattle_Move_0F3
  alias kifer_mx_0F3_pbMoveFailed? pbMoveFailed? unless method_defined?(:kifer_mx_0F3_pbMoveFailed?)
  alias kifer_mx_0F3_pbFailsAgainstTarget? pbFailsAgainstTarget? unless method_defined?(:kifer_mx_0F3_pbFailsAgainstTarget?)
  alias kifer_mx_0F3_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_mx_0F3_pbEffectAgainstTarget)
  def pbMoveFailed?(user, targets)
    return false if user.status != :NONE && KIFER::MoveFxField.er?(self, [:BESTOW])
    return kifer_mx_0F3_pbMoveFailed?(user, targets)
  end

  def pbFailsAgainstTarget?(user, target)
    return kifer_mx_0F3_pbFailsAgainstTarget?(user, target) if !KIFER::MoveFxField.er?(self, [:BESTOW])
    return false if KIFER::MoveFxField.bestow_item?(user, target) ||
                    KIFER::MoveFxField.bestow_status?(user, target, self)
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbEffectAgainstTarget(user, target)
    return kifer_mx_0F3_pbEffectAgainstTarget(user, target) if !KIFER::MoveFxField.er?(self, [:BESTOW])
    status = KIFER::MoveFxField.bestow_status?(user, target, self)
    kifer_mx_0F3_pbEffectAgainstTarget(user, target) if KIFER::MoveFxField.bestow_item?(user, target)
    KIFER::MoveFxField.pass_status(@battle, user, target) if status && user.status != :NONE && target.status == :NONE
  end
end

# Creeping Thorns: Rapid Spin and Defog clear them
class PokeBattle_Move_110
  alias kifer_mx_110_pbEffectAfterAllHits pbEffectAfterAllHits unless method_defined?(:kifer_mx_110_pbEffectAfterAllHits)
  def pbEffectAfterAllHits(user, target)
    kifer_mx_110_pbEffectAfterAllHits(user, target)
    return if user.fainted? || target.damageState.unaffected
    KIFER::MoveFxField.clear_thorns(@battle, user.pbOwnSide, user)
  end
end

class PokeBattle_Move_049
  # PIF's Defog fails with nothing to clear: the thorns count as something
  alias kifer_mx_049_pbFailsAgainstTarget? pbFailsAgainstTarget? unless method_defined?(:kifer_mx_049_pbFailsAgainstTarget?)
  def pbFailsAgainstTarget?(user, target)
    return false if KIFER::MoveFxField.thorns?(target.pbOwnSide)
    return false if Settings::MECHANICS_GENERATION >= 6 && KIFER::MoveFxField.thorns?(target.pbOpposingSide)
    return kifer_mx_049_pbFailsAgainstTarget?(user, target)
  end

  alias kifer_mx_049_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_mx_049_pbEffectAgainstTarget)
  def pbEffectAgainstTarget(user, target)
    kifer_mx_049_pbEffectAgainstTarget(user, target)
    KIFER::MoveFxField.clear_thorns(@battle, target.pbOwnSide, user)
    KIFER::MoveFxField.clear_thorns(@battle, target.pbOpposingSide, user) if Settings::MECHANICS_GENERATION >= 6
  end
end

#-------------------------------------------------------------------------------
# Every move: never-miss moves, Wonder Room stages, Smokescreen, Miracle Eye
#-------------------------------------------------------------------------------
class PokeBattle_Move
  alias kifer_mx_pbBaseAccuracy pbBaseAccuracy unless method_defined?(:kifer_mx_pbBaseAccuracy)
  def pbBaseAccuracy(user, target)
    t = KIFER::MoveFxField::NO_MISS[@id]
    return 0 if t && KIFER::Moves.applied? && KIFER::Moves.ready?(@id) && user.pbHasType?(t)
    return kifer_mx_pbBaseAccuracy(user, target)
  end

  alias kifer_mx_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_mx_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    stat, stage = kifer_mx_pbGetAttackStats(user, target)
    if KIFER::MoveFxField.wonder_room?(@battle) && (stat == user.attack || stat == user.spatk)
      stage = 6   # Attack / Sp. Atk stages don't count
    end
    return stat, stage
  end

  alias kifer_mx_pbCalcAccuracyModifiers pbCalcAccuracyModifiers unless method_defined?(:kifer_mx_pbCalcAccuracyModifiers)
  def pbCalcAccuracyModifiers(user, target, modifiers)
    kifer_mx_pbCalcAccuracyModifiers(user, target, modifiers)
    if target && !target.equal?(user) && KIFER::MoveFxField.smoke?(target.pbOwnSide)
      modifiers[:evasion_multiplier] *= 1.25
    end
  end

  alias kifer_mx_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_mx_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_mx_pbCalcTypeModSingle(moveType, defType, user, target)
    return KIFER::MoveFxField.eye_mod(ret, moveType, defType, target)
  end
end

#-------------------------------------------------------------------------------
# Battlers
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_mx_pbInitEffects pbInitEffects unless method_defined?(:kifer_mx_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_mx_pbInitEffects(batonPass)
    @kifer_mx_guard = nil
    @kifer_mx_eye = false
  end

  # Wonder Room swaps Attack and Sp. Atk (PIF's swaps the defenses this way)
  alias kifer_mx_attack attack unless method_defined?(:kifer_mx_attack)
  alias kifer_mx_spatk spatk unless method_defined?(:kifer_mx_spatk)
  def attack
    return kifer_mx_spatk if @battle && KIFER::MoveFxField.wonder_room?(@battle)
    return kifer_mx_attack
  end

  def spatk
    return kifer_mx_attack if @battle && KIFER::MoveFxField.wonder_room?(@battle)
    return kifer_mx_spatk
  end

  alias kifer_mx_takesIndirectDamage? takesIndirectDamage? unless method_defined?(:kifer_mx_takesIndirectDamage?)
  def takesIndirectDamage?(showMsg = false)
    return false if @battle && KIFER::MoveFxField.magic_room?(@battle)
    return kifer_mx_takesIndirectDamage?(showMsg)
  end

  # Glare / Stun Spore: no Electric type while the game asks if it can paralyze
  alias kifer_mx_pbHasType? pbHasType? unless method_defined?(:kifer_mx_pbHasType?)
  def pbHasType?(type)
    return false if @kifer_mx_no_elec && type == :ELECTRIC
    return kifer_mx_pbHasType?(type)
  end

  alias kifer_mx_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget unless method_defined?(:kifer_mx_pbSuccessCheckAgainstTarget)
  def pbSuccessCheckAgainstTarget(move, user, target)
    if KIFER::MoveFxField.detect_blocks?(move, user, target)
      @battle.pbCommonAnimation("Protect", target)
      @battle.pbDisplay(_INTL("{1} protected itself!", target.pbThis))
      target.damageState.protected = true
      @battle.successStates[user.index].protected = true
      return false
    end
    ret = kifer_mx_pbSuccessCheckAgainstTarget(move, user, target)
    KIFER::MoveFxField.after_block(@battle, move, user, target) if !ret && target && !target.equal?(user)
    return ret
  end
end

#-------------------------------------------------------------------------------
# Battle: Creeping Thorns on entry, Mega Evolution in Magic Room, end of round
#-------------------------------------------------------------------------------
class PokeBattle_Battle
  alias kifer_mx_pbOnActiveOne pbOnActiveOne unless method_defined?(:kifer_mx_pbOnActiveOne)
  def pbOnActiveOne(battler)
    ret = kifer_mx_pbOnActiveOne(battler)   # Healing Wish / Lunar Dance heal first, then PIF's hazards
    return ret if !ret
    if !battler.fainted? && KIFER::MoveFxField.thorns?(battler.pbOwnSide)
      return pbOnActiveOne(battler) if KIFER::MoveFxField.thorns_entry(self, battler) == :switched
      if battler.fainted?   # as PIF does after its hazards
        battler.pbFaint
        pbGainExp
        pbJudge
        return false
      end
    end
    return ret
  end

  if method_defined?(:pbCanMegaEvolve?)
    alias kifer_mx_pbCanMegaEvolve? pbCanMegaEvolve? unless method_defined?(:kifer_mx_pbCanMegaEvolve?)
    def pbCanMegaEvolve?(idxBattler)
      return false if KIFER::MoveFxField.magic_room?(self)
      return kifer_mx_pbCanMegaEvolve?(idxBattler)
    end
  end

  alias kifer_mx_pbEndOfRoundPhase pbEndOfRoundPhase unless method_defined?(:kifer_mx_pbEndOfRoundPhase)
  def pbEndOfRoundPhase
    guard_up = @sides.map { |s| s.effects[PBEffects::QuickGuard] }   # Feint may have broken one
    kifer_mx_pbEndOfRoundPhase
    KIFER::MoveFxField.end_of_round(self, guard_up)
  end
end

#-------------------------------------------------------------------------------
# Battle AI (PIF's and DemICE's: KIF sends both through these methods)
#-------------------------------------------------------------------------------
class PokeBattle_AI
  alias kifer_mx_pbGetMoveScoreFunctionCode pbGetMoveScoreFunctionCode unless method_defined?(:kifer_mx_pbGetMoveScoreFunctionCode)
  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
    d = KIFER::MoveFxField.ai_delta(@battle, move, user, target)
    return KIFER::AI.demice_on? ? d : score + d if !d.nil?
    ret = kifer_mx_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
    return ret if !ret.is_a?(Numeric)
    return ret + KIFER::MoveFxField.thorns_cleanup(@battle, move, user, target)
  end

  alias kifer_mx_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_mx_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_mx_pbCalcTypeModSingle(moveType, defType, user, target)
    return KIFER::MoveFxField.eye_mod(ret, moveType, defType, target)
  end
end

#-------------------------------------------------------------------------------
# Registering: ready while Moves is On, with the ER values the data lacks
#-------------------------------------------------------------------------------
[PokeBattle_Move_KERA01, PokeBattle_Move_KERA02, PokeBattle_Move_KERA03,
 PokeBattle_Move_KERA04, PokeBattle_Move_KERA05, PokeBattle_Move_KERA06].each do |k|
  KIFER::TerrainEnrage.wrap_move_class(k)   # 033's per-target context
end

KIFER::Moves.coded(:SUNNYDAY, :RAINDANCE, :SANDSTORM, :HAIL,
                   :ELECTRICTERRAIN, :GRASSYTERRAIN, :MISTYTERRAIN, :PSYCHICTERRAIN,
                   :QUICKGUARD, :DETECT, :GLARE, :STUNSPORE, :THUNDERWAVE, :WILLOWISP,
                   :LEECHSEED, :GASTROACID, :SWEETKISS, :BESTOW)
KIFER::Moves.coded(:BARRIER, function_code: "KERA01")
KIFER::Moves.coded(:MAGICROOM, function_code: "KERA02")
KIFER::Moves.coded(:WONDERROOM, function_code: "KERA03")
KIFER::Moves.coded(:SMOKESCREEN, function_code: "KERA04", target: :UserSide, flags: "e")   # ER: the user's side (no Protect / Magic Coat)
KIFER::Moves.coded(:MIRACLEEYE, function_code: "KERA05")
KIFER::Moves.coded(:NEEDLEARM, function_code: "KERA06")
KIFER::Moves.coded(:CAMOUFLAGE, function_code: "0AA", priority: 4)   # ER: +4, a protect move
KIFER::Moves.coded(:MINDREADER, function_code: "0AA", target: :User)
# The data may already hold ER values (060 swaps at load): add these moves now
