#===============================================================================
# KIF: Elite Redux – effects for Elite Redux moves PIF doesn't have, batch 2
#   Psychic Noise  – the target can't heal for 2 turns (Heal Block)
#   Wave Crash     – 33% recoil (PIF's class) and its chance drenches (031)
#   Meteor Beam    – two turns; Sp. Atk +1 on the charging turn (Skull Bash's way)
#   Karma          – Speed -1, Sp. Atk +1, Sp. Def +1
#   Mystic Dance   – Sp. Atk +1, Speed +1
#   Victory Dance  – Attack, Defense and Speed +1
#   Coaching       – the user's allies: Attack and Defense +1
#   Steel Roller, Ice Spinner – remove the terrain after hitting; don't fail
#                    without one
#   Grassy Glide   – +1 priority on Grassy Terrain (grounded user)
#   Upper Hand     – fails unless the target chose a priority move and hasn't
#                    moved yet; flinches
#   Battle AI (both): each is scored as the PIF move it works like.
#===============================================================================
module KIFER
  module NewMoveFx2
    TERRAIN_GONE = { :Electric => "The electric current disappeared from the battlefield!",
                     :Grassy   => "The grass disappeared from the battlefield!",
                     :Misty    => "The mist disappeared from the battlefield!",
                     :Psychic  => "The weirdness disappeared from the battlefield!" }
    # code => the PIF code the AI scores it as
    AI_AS = { "KERD08" => "0BB", "KERD09" => "0FB", "KERD10" => "0C8", "KERD11" => "02C",
              "KERD12" => "02B", "KERD13" => "026", "KERD14" => "000", "KERD15" => "000",
              "KERD16" => "000", "KERD17" => "116" }

    module_function

    def clear_terrain(battle)
      t = battle.field.terrain
      return if t == :None
      battle.field.terrain = :None
      battle.field.terrainDuration = 0
      battle.pbDisplay(_INTL(TERRAIN_GONE[t] || "The terrain disappeared from the battlefield!"))
    end

    # the battler whose move this is
    def owner(move)
      move.battle.battlers.each { |b| return b if b && b.moves.any? { |m| m.equal?(move) } }
      return nil
    end
  end
end

class PokeBattle_Move_KERD08 < PokeBattle_Move   # Psychic Noise
  def pbAdditionalEffect(user, target)
    return if target.fainted? || target.damageState.substitute || target.effects[PBEffects::HealBlock] > 0
    target.effects[PBEffects::HealBlock] = 2
    @battle.pbDisplay(_INTL("{1} was prevented from healing!", target.pbThis))
  end
end

class PokeBattle_Move_KERD09 < PokeBattle_Move_0FB   # Wave Crash
  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    KIFER::Drench.on_hit(user, target, nil, 100)
  end
end

class PokeBattle_Move_KERD10 < PokeBattle_Move_0C8   # Meteor Beam
  def pbChargingTurnMessage(user, targets)
    @battle.pbDisplay(_INTL("{1} is overflowing with space power!", user.pbThis))
  end

  def pbChargingTurnEffect(user, target)
    user.pbRaiseStatStage(:SPECIAL_ATTACK, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user, self)
  end
end

class PokeBattle_Move_KERD11 < PokeBattle_Move   # Karma
  def pbMoveFailed?(user, targets)
    return false if [:SPECIAL_ATTACK, :SPECIAL_DEFENSE].any? { |s| user.pbCanRaiseStatStage?(s, user, self) }
    @battle.pbDisplay(_INTL("{1}'s stats won't go any higher!", user.pbThis))
    return true
  end

  def pbEffectGeneral(user)
    user.pbLowerStatStage(:SPEED, 1, user) if user.pbCanLowerStatStage?(:SPEED, user, self)
    anim = true
    [:SPECIAL_ATTACK, :SPECIAL_DEFENSE].each do |s|
      next if !user.pbCanRaiseStatStage?(s, user, self)
      anim = false if user.pbRaiseStatStage(s, 1, user, anim)
    end
  end
end

class PokeBattle_Move_KERD12 < PokeBattle_MultiStatUpMove   # Mystic Dance
  def initialize(battle, move)
    super
    @statUp = [:SPECIAL_ATTACK, 1, :SPEED, 1]
  end
end

class PokeBattle_Move_KERD13 < PokeBattle_MultiStatUpMove   # Victory Dance
  def initialize(battle, move)
    super
    @statUp = [:ATTACK, 1, :DEFENSE, 1, :SPEED, 1]
  end
end

class PokeBattle_Move_KERD14 < PokeBattle_Move   # Coaching
  def pbMoveFailed?(user, targets)
    ok = false
    user.eachAlly do |b|
      ok = true if [:ATTACK, :DEFENSE].any? { |s| b.pbCanRaiseStatStage?(s, user, self) }
    end
    return false if ok
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbEffectGeneral(user)
    user.eachAlly do |b|
      anim = true
      [:ATTACK, :DEFENSE].each do |s|
        next if !b.pbCanRaiseStatStage?(s, user, self)
        anim = false if b.pbRaiseStatStage(s, 1, user, anim)
      end
    end
  end
end

class PokeBattle_Move_KERD15 < PokeBattle_Move   # Steel Roller, Ice Spinner
  def pbEffectAfterAllHits(user, target)
    return if user.fainted? || target.damageState.unaffected
    KIFER::NewMoveFx2.clear_terrain(@battle)
  end
end

class PokeBattle_Move_KERD16 < PokeBattle_Move   # Grassy Glide
  def priority
    u = KIFER::NewMoveFx2.owner(self)
    return @priority + 1 if u && @battle.field.terrain == :Grassy && !u.airborne?
    return @priority
  end
end

class PokeBattle_Move_KERD17 < PokeBattle_Move   # Upper Hand
  def pbFailsAgainstTarget?(user, target)
    ch = @battle.choices[target.index]
    m = ch.is_a?(Array) && ch[0] == :UseMove ? ch[2] : nil
    pri = ch.is_a?(Array) ? ch[4].to_i : 0
    if !m || pri <= 0 || m.statusMove? || target.movedThisRound?
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end

  def pbAdditionalEffect(user, target)
    target.pbFlinch(user) unless target.damageState.substitute
  end
end

class PokeBattle_AI
  alias kifer_nmf2_pbGetMoveScoreFunctionCode pbGetMoveScoreFunctionCode unless method_defined?(:kifer_nmf2_pbGetMoveScoreFunctionCode)
  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
    f = move && move.function
    as = KIFER::NewMoveFx2::AI_AS[f]
    return kifer_nmf2_pbGetMoveScoreFunctionCode(score, move, user, target, skill) if !as
    move.instance_variable_set(:@function, as)   # scored as the PIF move it works like
    begin
      return kifer_nmf2_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
    ensure
      move.instance_variable_set(:@function, f)
    end
  end
end

KIFER::NewMoveFx2::AI_AS.each_key do |c|
  k = Object.const_get("PokeBattle_Move_#{c}")
  KIFER::TerrainEnrage.wrap_move_class(k) if defined?(KIFER::TerrainEnrage) && KIFER::TerrainEnrage.respond_to?(:wrap_move_class)
end
KIFER::Statuses.hook_heal_moves if defined?(KIFER::Statuses) && KIFER::Statuses.respond_to?(:hook_heal_moves)

KIFER::Moves.coded(:PSYCHICNOISE, function_code: "KERD08")
KIFER::Moves.coded(:WAVECRASH, function_code: "KERD09", chance: 10)   # ER text: 10% drench (the ROM data says 0)
KIFER::Moves.coded(:METEORBEAM, function_code: "KERD10")
KIFER::Moves.coded(:KARMA, function_code: "KERD11")
KIFER::Moves.coded(:MYSTICDANCE, function_code: "KERD12")
KIFER::Moves.coded(:VICTORYDANCE, function_code: "KERD13")
KIFER::Moves.coded(:COACHING, function_code: "KERD14")
KIFER::Moves.coded(:STEELROLLER, :ICESPINNER, function_code: "KERD15")
KIFER::Moves.coded(:GRASSYGLIDE, function_code: "KERD16")
KIFER::Moves.coded(:UPPERHAND, function_code: "KERD17")
KIFER::NewMoves.register   # in the game now (064)
