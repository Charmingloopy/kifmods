#===============================================================================
# KIF: Elite Redux – ER rules a move's text adds to its effect (data: :rules
# in er_moves.rb, read from the long text by tools/convert_er_moves.py)
#   :never_miss    – skips the accuracy roll (a Pokemon in the air or
#                    underground still dodges)
#   :super_vs      – super effective against that type
#   :no_repeat     – fails if the user used it last turn
#   :ignore_stats  – ignores the target's Defense / Sp. Def and evasion stages
#   :ignore_boosts – the same, raised stages only
#   :hits_protect  – Protect and the like don't stop it
#   PIF moves: while Moves is applied and the move is ready; ER-only moves
#   (064) always. The AI sees never-miss accuracy, the matchup and no-repeat.
#===============================================================================
module KIFER
  module MoveRules
    RULES = {}
    KIFER::MOVES.each { |id, e| RULES[id] = e[:rules] if e[:rules] }
    KIFER::ER_ONLY_MOVES.each { |id, e| RULES[id] = e[:rules] if e[:rules] }
    RULES.freeze

    module_function

    def get(move_or_id, rule)
      return nil if move_or_id.nil?
      id = move_or_id.is_a?(Symbol) ? move_or_id : move_or_id.id
      r = RULES[id] or return nil   # most moves: one hash lookup
      return nil unless KIFER::Moves.applied?
      return nil unless KIFER::ER_ONLY_MOVES.key?(id) || KIFER::Moves.ready?(id)
      return r[rule]
    end

    # in_use: asked inside the use, where PIF has already written this move as
    # the last one used; the values from before the use are kept for it
    def repeat?(move, user, in_use = false)
      return false unless get(move, :no_repeat) && user
      last, round = in_use ? (user.instance_variable_get(:@kifer_mr_prev) || []) : [user.lastMoveUsed, user.lastRoundMoved]
      return last == move.id && round == user.battle.turnCount - 1
    end
  end
end

class PokeBattle_Move
  alias kifer_mr_canProtectAgainst? canProtectAgainst? unless method_defined?(:kifer_mr_canProtectAgainst?)
  def canProtectAgainst?
    return false if KIFER::MoveRules.get(self, :hits_protect)
    return kifer_mr_canProtectAgainst?
  end

  alias kifer_mr_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_mr_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    t = KIFER::MoveRules.get(self, :super_vs)
    return Effectiveness::SUPER_EFFECTIVE_ONE if t && defType == t
    return kifer_mr_pbCalcTypeModSingle(moveType, defType, user, target)
  end

  alias kifer_mr_pbMoveFailed? pbMoveFailed? unless method_defined?(:kifer_mr_pbMoveFailed?)
  def pbMoveFailed?(user, targets)
    if KIFER::MoveRules.repeat?(self, user, true)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return kifer_mr_pbMoveFailed?(user, targets)
  end

  alias kifer_mr_pbGetDefenseStats pbGetDefenseStats unless method_defined?(:kifer_mr_pbGetDefenseStats)
  def pbGetDefenseStats(user, target)
    stat, stage = kifer_mr_pbGetDefenseStats(user, target)
    return stat, 6 if KIFER::MoveRules.get(self, :ignore_stats)
    return stat, [stage, 6].min if KIFER::MoveRules.get(self, :ignore_boosts)
    return stat, stage
  end

  alias kifer_mr_pbCalcAccuracyModifiers pbCalcAccuracyModifiers unless method_defined?(:kifer_mr_pbCalcAccuracyModifiers)
  def pbCalcAccuracyModifiers(user, target, modifiers)
    kifer_mr_pbCalcAccuracyModifiers(user, target, modifiers)
    if KIFER::MoveRules.get(self, :ignore_stats)
      modifiers[:evasion_stage] = 0
    elsif KIFER::MoveRules.get(self, :ignore_boosts)
      modifiers[:evasion_stage] = [modifiers[:evasion_stage], 0].min
    end
  end
end

class PokeBattle_Battler
  alias kifer_mr_pbUseMove pbUseMove unless method_defined?(:kifer_mr_pbUseMove)
  def pbUseMove(*args, &blk)
    prev = @kifer_mr_prev
    @kifer_mr_prev = [@lastMoveUsed, @lastRoundMoved]
    begin
      return kifer_mr_pbUseMove(*args, &blk)
    ensure
      @kifer_mr_prev = prev
    end
  end

  alias kifer_mr_pbSuccessCheckPerHit pbSuccessCheckPerHit unless method_defined?(:kifer_mr_pbSuccessCheckPerHit)
  def pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
    skipAccuracyCheck ||= KIFER::MoveRules.get(move, :never_miss)
    return kifer_mr_pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
  end
end

class PokeBattle_AI
  alias kifer_mr_pbRoughAccuracy pbRoughAccuracy unless method_defined?(:kifer_mr_pbRoughAccuracy)
  def pbRoughAccuracy(move, user, target, skill)
    return 100 if KIFER::MoveRules.get(move, :never_miss)
    return kifer_mr_pbRoughAccuracy(move, user, target, skill)
  end

  alias kifer_mr_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_mr_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    m = defined?(KIFER::AIInnates) ? KIFER::AIInnates.current_move : nil
    t = m && KIFER::MoveRules.get(m, :super_vs)
    return Effectiveness::SUPER_EFFECTIVE_ONE if t && defType == t
    return kifer_mr_pbCalcTypeModSingle(moveType, defType, user, target)
  end

  alias kifer_mr_pbGetMoveScore pbGetMoveScore unless method_defined?(:kifer_mr_pbGetMoveScore)
  def pbGetMoveScore(move, user, target, skill = 100)
    return 0 if KIFER::MoveRules.repeat?(move, user)
    return kifer_mr_pbGetMoveScore(move, user, target, skill)
  end
end

# ER plain hits whose PIF class does something else (read by hand, 2026-10-19):
# every-other-turn instead of a recharge turn (Blast Burn and co.), no Speed
# drop (Ice Hammer), super effective on Water instead of x2 below half HP
# (Brine), and Smart Strike ignores abilities (Moongeist Beam's class)
KIFER::Moves.coded(:BLASTBURN, :FRENZYPLANT, :HYDROCANNON, :PRISMATICLASER, :ICEHAMMER, :BRINE, function_code: "000")
KIFER::Moves.coded(:SMARTSTRIKE, function_code: "163")
