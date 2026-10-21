#===============================================================================
# KIF: Elite Redux – Elite Redux effects of some PIF support moves
#   Used only while the "Moves" setting is On (the moves switch to these
#   classes then); with Moves Off every move is PIF's.
#   Aromatherapy  – also heals the user 30% (after the statuses are cured).
#   Aromatic Mist – the user and its partner: Sp. Def +2. Works in singles.
#   Conversion    – Sp. Atk and Speed +1, type of its first move.
#   Conversion 2  – Sp. Atk and Speed +1, a type that resists the last move
#                   that hit it (ER's target is the user). Each part works on
#                   its own; the move fails only if neither can happen.
#   Meditate      – Attack and Sp. Def +1.
#   Milk Drink, Soft-Boiled – heal the user or an ally by half its HP.
#   Refresh       – cures burn, poison, paralysis, frostbite and heals 25%.
#                   Not a healing move (Heal Block, 031's bleeding cure), as
#                   in PIF: a bleeding user can't heal, so it fails.
#   Sharpen       – its higher of Attack / Sp. Atk +1 and crit stage +1 (up to
#                   the always-crit stage). Cutthroat's reset is in 022.
#   Swallow       – heals 50%. With stockpiles, one stockpile (and the
#                   Defense / Sp. Def it gave) is spent instead of PP, and it
#                   can be used at 0 PP.
#   Healing moves (Milk Drink, Soft-Boiled, Swallow) on a bleeding
#   user cure the bleeding instead (031).
#===============================================================================
module KIFER
  module MoveFxSupport
    REFRESH_CURES = [:BURN, :POISON, :PARALYSIS, :FROSTBITE]
    module_function

    def heal(b, amt)
      return if b.hp >= b.totalhp || !b.canHeal?
      b.battle.pbDisplay(_INTL("{1}'s HP was restored.", b.pbThis)) if b.pbRecoverHP(amt) > 0
    end

    def can_raise?(b, stats, move)
      return (0...stats.length / 2).any? { |i| b.pbCanRaiseStatStage?(stats[i * 2], b, move) }
    end

    def raise_stats(b, stats, move)
      anim = true
      (0...stats.length / 2).each do |i|
        next if !b.pbCanRaiseStatStage?(stats[i * 2], b, move)
        anim = false if b.pbRaiseStatStage(stats[i * 2], stats[i * 2 + 1], b, anim)
      end
    end

    def higher_attack(b)
      return b.spatk > b.attack ? :SPECIAL_ATTACK : :ATTACK
    end

    # Swallow paid with a stockpile: take one, and one stage of what it gave
    def spend_stockpile(b, move)
      b.instance_variable_set(:@kifer_mfs_stock, false)
      return if b.effects[PBEffects::Stockpile] <= 0
      b.effects[PBEffects::Stockpile] -= 1
      anim = true
      [[:DEFENSE, PBEffects::StockpileDef], [:SPECIAL_DEFENSE, PBEffects::StockpileSpDef]].each do |s, e|
        next if b.effects[e] <= 0
        b.effects[e] -= 1
        anim = false if b.pbCanLowerStatStage?(s, b, move) && b.pbLowerStatStage(s, 1, b, anim)
      end
    end

    def stock_usable?(b, move)
      return move.is_a?(PokeBattle_Move_KERC07) && b.effects[PBEffects::Stockpile] > 0
    end

    #---------------------------------------------------------------------------
    # Battle AI: change to the starting score (no battle state is touched)
    #---------------------------------------------------------------------------
    def heal_value(b, frac = 1.0)
      return nil if b.hp >= b.totalhp || !b.canHeal?
      return ((50 - b.hp * 100 / b.totalhp) * frac).round
    end

    def setup_value(b, stat, ok)
      return ok ? 30 - 10 * b.stages[stat] : -90
    end

    def ai_delta(move, user, target)
      case move.function
      when "KERC01"   # Meditate
        return setup_value(user, :ATTACK, can_raise?(user, [:ATTACK, 1, :SPECIAL_DEFENSE, 1], move))
      when "KERC02"   # Sharpen
        st = higher_attack(user)
        return setup_value(user, st, user.pbCanRaiseStatStage?(st, user, move) ||
                                     user.effects[PBEffects::FocusEnergy] < 3)
      when "KERC03"   # Milk Drink, Soft-Boiled (user or ally)
        return -200 if !target || target.opposes?(user)
        return heal_value(target) || -90
      when "KERC04"   # Refresh
        d = REFRESH_CURES.include?(user.status) ? 40 : 0
        h = heal_value(user, 0.5)
        return -90 if d == 0 && !h
        return d + (h || 0)
      when "KERC05", "KERC06"   # Conversion, Conversion 2
        ok = !move.kifer_mfs_types(user).empty? || can_raise?(user, [:SPECIAL_ATTACK, 1, :SPEED, 1], move)
        return setup_value(user, :SPECIAL_ATTACK, ok)
      when "KERC07"   # Swallow
        return heal_value(user) || -90
      when "KERC08"   # Aromatic Mist
        ok = false
        user.battle.eachSameSideBattler(user.index) { |b| ok ||= b.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user, move) }
        return setup_value(user, :SPECIAL_DEFENSE, ok)
      when "KERC09"   # Aromatherapy
        cure = false
        user.battle.eachSameSideBattler(user.index) { |b| cure ||= b.status != :NONE }
        cure ||= user.battle.pbParty(user.index).any? { |p| p && p.able? && p.status != :NONE }
        h = heal_value(user, 0.6)
        return -90 if !cure && !h
        return (cure ? 40 : 0) + (h || 0)
      end
      return nil
    end
  end
end

#===============================================================================
# Move classes
#===============================================================================
# Meditate
class PokeBattle_Move_KERC01 < PokeBattle_MultiStatUpMove
  def initialize(battle, move)
    super
    @statUp = [:ATTACK, 1, :SPECIAL_DEFENSE, 1]
  end
end

# Sharpen
class PokeBattle_Move_KERC02 < PokeBattle_Move
  def pbMoveFailed?(user, targets)
    @stat = KIFER::MoveFxSupport.higher_attack(user)
    return false if user.pbCanRaiseStatStage?(@stat, user, self) || user.effects[PBEffects::FocusEnergy] < 3
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbEffectGeneral(user)
    user.pbRaiseStatStage(@stat, 1, user) if user.pbCanRaiseStatStage?(@stat, user, self)
    return if user.effects[PBEffects::FocusEnergy] >= 3   # 3 = every hit crits
    user.effects[PBEffects::FocusEnergy] += 1
    @battle.pbDisplay(_INTL("{1} is getting pumped!", user.pbThis))
  end
end

# Milk Drink, Soft-Boiled: heal the user or an ally (Heal Pulse's code)
class PokeBattle_Move_KERC03 < PokeBattle_Move_0DF
  def pbFailsAgainstTarget?(user, target)
    if target.index == user.index && target.status == :BLEEDING   # as 031 does for self-healing moves
      target.pbCureStatus
      return true
    end
    return super
  end
end

# Refresh
class PokeBattle_Move_KERC04 < PokeBattle_Move_018
  def pbMoveFailed?(user, targets)
    return false if user.hp < user.totalhp && user.canHeal?
    return super
  end

  def pbEffectGeneral(user)
    super if KIFER::MoveFxSupport::REFRESH_CURES.include?(user.status)
    KIFER::MoveFxSupport.heal(user, (user.totalhp / 4.0).round)
  end
end

# Conversion
class PokeBattle_Move_KERC05 < PokeBattle_Move_05E
  STATS = [:SPECIAL_ATTACK, 1, :SPEED, 1]

  def kifer_mfs_types(user)
    m = user.moves[0]
    return [] if !m || !user.canChangeType? || GameData::Type.get(m.type).pseudo_type || user.pbHasType?(m.type)
    return [m.type]
  end

  def pbMoveFailed?(user, targets)
    @newTypes = kifer_mfs_types(user)
    return false if !@newTypes.empty? || KIFER::MoveFxSupport.can_raise?(user, STATS, self)
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbFailsAgainstTarget?(user, target); return false; end

  def pbEffectGeneral(user)
    KIFER::MoveFxSupport.raise_stats(user, STATS, self)
    super if !@newTypes.empty?   # 05E/05F: random one of @newTypes, with message
  end
end

# Conversion 2: resists the last move that hit the user
class PokeBattle_Move_KERC06 < PokeBattle_Move_KERC05
  def ignoresSubstitute?(user); return true; end

  def kifer_mfs_types(user)
    t = user.instance_variable_get(:@kifer_mfs_hit)
    return [] if !t || !user.canChangeType? || !GameData::Type.exists?(t) || GameData::Type.get(t).pseudo_type
    ret = []
    last = GameData::Type.get(:FAIRY).id_number   # not PIF's fusion-only types (Ice/Rock/Steel...)
    GameData::Type.each do |ty|
      next if ty.pseudo_type || ty.id_number > last || user.pbHasType?(ty.id) || !Effectiveness.resistant_type?(t, ty.id)
      ret.push(ty.id)
    end
    return ret
  end
end

# Swallow
class PokeBattle_Move_KERC07 < PokeBattle_HealingMove
  def pbHealAmount(user); return (user.totalhp / 2.0).round; end

  def pbDisplayUseMessage(user)
    super
    KIFER::MoveFxSupport.spend_stockpile(user, self) if user.instance_variable_get(:@kifer_mfs_stock)
  end
end

# Aromatic Mist: the user and its partner
class PokeBattle_Move_KERC08 < PokeBattle_Move
  def ignoresSubstitute?(user); return true; end

  def pbMoveFailed?(user, targets)
    @mist = []
    @battle.eachSameSideBattler(user.index) { |b| @mist << b if b.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user, self) }
    return false if !@mist.empty?
    @battle.pbDisplay(_INTL("But it failed!"))
    return true
  end

  def pbEffectGeneral(user)
    @mist.each { |b| b.pbRaiseStatStage(:SPECIAL_DEFENSE, 2, user) }
  end
end

# Aromatherapy
class PokeBattle_Move_KERC09 < PokeBattle_Move_019
  def pbMoveFailed?(user, targets)
    return false if user.hp < user.totalhp && user.canHeal?
    return super
  end

  def pbEffectGeneral(user)
    super
    KIFER::MoveFxSupport.heal(user, (user.totalhp * 0.3).round)
  end
end

#===============================================================================
# Battle hooks
#===============================================================================
class PokeBattle_Move
  # Conversion 2: the last move that hit each battler
  alias kifer_mfs_pbRecordDamageLost pbRecordDamageLost unless method_defined?(:kifer_mfs_pbRecordDamageLost)
  def pbRecordDamageLost(user, target)
    kifer_mfs_pbRecordDamageLost(user, target)
    target.instance_variable_set(:@kifer_mfs_hit, @calcType)
  end
end

class PokeBattle_Battler
  alias kifer_mfs_pbInitEffects pbInitEffects unless method_defined?(:kifer_mfs_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_mfs_pbInitEffects(batonPass)
    @kifer_mfs_hit = nil
    @kifer_mfs_stock = false
  end

  # Swallow: a stockpile instead of PP (taken after the use message)
  alias kifer_mfs_pbReducePP pbReducePP unless method_defined?(:kifer_mfs_pbReducePP)
  def pbReducePP(move)
    if move.pp >= 0 && KIFER::MoveFxSupport.stock_usable?(self, move)
      @kifer_mfs_stock = true
      return true
    end
    return kifer_mfs_pbReducePP(move)
  end
end

class PokeBattle_Battle
  # Swallow can be chosen at 0 PP while there are stockpiles
  alias kifer_mfs_pbCanChooseMove? pbCanChooseMove? unless method_defined?(:kifer_mfs_pbCanChooseMove?)
  def pbCanChooseMove?(idxBattler, idxMove, showMessages, sleepTalk = false)
    b = @battlers[idxBattler]
    m = b && b.moves[idxMove]
    if m && m.pp == 0 && KIFER::MoveFxSupport.stock_usable?(b, m)
      return false if b.effects[PBEffects::Encore] > 0 && b.pbEncoredMoveIndex >= 0 && idxMove != b.pbEncoredMoveIndex
      return b.pbCanChooseMove?(m, true, showMessages, sleepTalk)
    end
    return kifer_mfs_pbCanChooseMove?(idxBattler, idxMove, showMessages, sleepTalk)
  end

  alias kifer_mfs_pbCanChooseAnyMove? pbCanChooseAnyMove? unless method_defined?(:kifer_mfs_pbCanChooseAnyMove?)
  def pbCanChooseAnyMove?(idxBattler, sleepTalk = false)
    return true if kifer_mfs_pbCanChooseAnyMove?(idxBattler, sleepTalk)
    b = @battlers[idxBattler]
    return false if !b
    return b.moves.each_index.any? { |i| b.moves[i].pp == 0 && KIFER::MoveFxSupport.stock_usable?(b, b.moves[i]) &&
                                         pbCanChooseMove?(idxBattler, i, false, sleepTalk) }
  end
end

class PokeBattle_AI
  alias kifer_mfs_pbGetMoveScoreFunctionCode pbGetMoveScoreFunctionCode unless method_defined?(:kifer_mfs_pbGetMoveScoreFunctionCode)
  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
    ret = kifer_mfs_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
    return ret if !move.function.start_with?("KERC") || !ret.is_a?(Numeric)
    return ret if KIFER::AI.bleed_cure_move?(move, user)   # 040 scores the cure
    d = KIFER::MoveFxSupport.ai_delta(move, user, target)
    return ret if !d
    return KIFER::AI.demice_on? ? d : score + d
  rescue StandardError => e
    KIFER.log("AI support move score: #{e.class}: #{e.message}")
    return ret
  end
end

#===============================================================================
# Register: the moves use these classes (and ER's targets) while Moves is On
#===============================================================================
KIFER::Moves.coded(:MEDITATE, function_code: "KERC01")
KIFER::Moves.coded(:SHARPEN, function_code: "KERC02")
KIFER::Moves.coded(:MILKDRINK, :SOFTBOILED, function_code: "KERC03", target: :UserOrNearAlly)
KIFER::Moves.coded(:REFRESH, function_code: "KERC04")
KIFER::Moves.coded(:CONVERSION, function_code: "KERC05")
KIFER::Moves.coded(:CONVERSION2, function_code: "KERC06", target: :User)
KIFER::Moves.coded(:SWALLOW, function_code: "KERC07")
KIFER::Moves.coded(:AROMATICMIST, function_code: "KERC08", target: :User)
KIFER::Moves.coded(:AROMATHERAPY, function_code: "KERC09")
# the new classes get 031's bleeding hook and 033's per-target wraps too
KIFER::Statuses.hook_heal_moves if defined?(KIFER::Statuses) && KIFER::Statuses.respond_to?(:hook_heal_moves)
KIFER::TerrainEnrage.wrap_all_moves if defined?(KIFER::TerrainEnrage) && KIFER::TerrainEnrage.respond_to?(:wrap_all_moves)
