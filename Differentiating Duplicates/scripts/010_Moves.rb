#===============================================================================
# Differentiating Duplicates - moves (setting "Changed moves")
# Duplicates share a function code, so each change checks the move's id.
#===============================================================================
module DiffDupes
  module Moves
    ALLY_TARGET = [:BARRIER, :SOFTBOILED, :MILKDRINK]
    WEB_HOLD    = 99   # MeanLook value for a Spider Web trap whose user has left
    PIVOTS      = ["0EE", "0ED", "151"]   # U-turn/Volt Switch/Flip Turn, Baton Pass, Parting Shot

    # Barrier, Soft-Boiled, Milk Drink: aimed at the user or an ally
    def self.ally_mode?(move)
      return ALLY_TARGET.include?(move.id) && DiffDupes.move_on?(move.id)
    end

    # Detect: attacks miss instead of being blocked
    def self.detecting?(b)
      return b && b.dd_detect && b.effects[PBEffects::Protect] && DiffDupes.move_on?(:DETECT) ? true : false
    end

    def self.detect_dodges?(move, user, target)
      return false unless detecting?(target)
      return false if user.index == target.index
      return false if user.effects[PBEffects::TwoTurnAttack]   # charging turn
      return false unless move.canProtectAgainst? || move.damagingMove?
      return !sure_hit?(move, user, target)
    end

    # Moves that can't miss still hit a Pokemon using Detect
    def self.sure_hit?(move, user, target)
      return true if user.hasActiveAbility?(:NOGUARD) || target.hasActiveAbility?(:NOGUARD)
      return true if user.effects[PBEffects::LockOn] > 0 && user.effects[PBEffects::LockOnPos] == target.index
      return true if move.pbOverrideSuccessCheckPerHit(user, target)
      return move.pbBaseAccuracy(user, target) == 0
    rescue StandardError
      return false
    end

    # Block: the trapped Pokemon's U-turn, Baton Pass etc. don't switch it out
    def self.blocked?(b)
      return b.dd_block && b.effects[PBEffects::MeanLook] >= 0 && DiffDupes.move_on?(:BLOCK) ? true : false
    end

    # Acid Armor: contact attackers may be poisoned for the rest of the round
    def self.acid_armor(move, user, target)
      return unless DiffDupes.move_on?(:ACIDARMOR)
      battle = target.battle
      return unless target.dd_acid_turn == battle.turnCount
      return if user.fainted? || user.index == target.index
      return unless target.damageState.calcDamage > 0 && !target.damageState.substitute
      return unless move.pbContactMove?(user) && user.affectedByContactEffect?
      return unless battle.pbRandom(100) < 30
      return unless user.pbCanPoison?(target, false)
      user.pbPoison(target, _INTL("{1} was poisoned by the acid!", user.pbThis))
    end
  end
end

#===============================================================================
# Battler hooks
#===============================================================================
class PokeBattle_Battler
  alias dd_pbInitEffects pbInitEffects unless method_defined?(:dd_pbInitEffects)
  def pbInitEffects(batonPass)
    webbed = []
    if @battle && DiffDupes.move_on?(:SPIDERWEB)
      @battle.eachBattler do |b|
        next if b.equal?(self)
        webbed << b if b.dd_web && b.effects[PBEffects::MeanLook] == @index
      end
    end
    dd_pbInitEffects(batonPass)
    # Spider Web: the trap stays after its user leaves
    webbed.each { |b| b.effects[PBEffects::MeanLook] = DiffDupes::Moves::WEB_HOLD }
    dd_reset
  end

  alias dd_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget unless method_defined?(:dd_pbSuccessCheckAgainstTarget)
  def pbSuccessCheckAgainstTarget(move, user, target)
    if !DiffDupes::Moves.detecting?(target) || user.index == target.index
      return dd_pbSuccessCheckAgainstTarget(move, user, target)
    end
    # Detect doesn't block; the miss happens in the per-hit check below
    target.effects[PBEffects::Protect] = false
    begin
      return dd_pbSuccessCheckAgainstTarget(move, user, target)
    ensure
      target.effects[PBEffects::Protect] = true
    end
  end

  alias dd_pbSuccessCheckPerHit pbSuccessCheckPerHit unless method_defined?(:dd_pbSuccessCheckPerHit)
  def pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
    if DiffDupes::Moves.detect_dodges?(move, user, target)
      PBDebug.log("[Move failed] #{target.pbThis} dodged it with Detect")
      return false
    end
    return dd_pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
  end

  alias dd_pbMissMessage pbMissMessage unless method_defined?(:dd_pbMissMessage)
  def pbMissMessage(move, user, target)
    if DiffDupes::Moves.detecting?(target) && user.index != target.index
      @battle.pbDisplay(_INTL("{1} avoided the attack!", target.pbThis))
      return
    end
    dd_pbMissMessage(move, user, target)
  end

  alias dd_pbEffectsOnMakingHit pbEffectsOnMakingHit unless method_defined?(:dd_pbEffectsOnMakingHit)
  def pbEffectsOnMakingHit(move, user, target)
    dd_pbEffectsOnMakingHit(move, user, target)
    begin
      DiffDupes::Moves.acid_armor(move, user, target)
    rescue StandardError => e
      DiffDupes.log("Acid Armor: #{e.class}: #{e.message}")
    end
  end
end

class PokeBattle_Move
  # Withdraw: no critical hits on the user for the rest of the round
  alias dd_pbIsCritical? pbIsCritical? unless method_defined?(:dd_pbIsCritical?)
  def pbIsCritical?(user, target)
    return false if target.dd_withdraw_turn == @battle.turnCount && DiffDupes.move_on?(:WITHDRAW)
    return dd_pbIsCritical?(user, target)
  end
end

#===============================================================================
# Protect, Detect
#===============================================================================
class PokeBattle_Move_0AA
  alias dd_0aa_effect pbEffectGeneral unless method_defined?(:dd_0aa_effect)
  def pbEffectGeneral(user)
    dd_0aa_effect(user)
    user.dd_detect = (@id == :DETECT && DiffDupes.move_on?(:DETECT))
  end
end

#===============================================================================
# Iron Defense, Acid Armor, Barrier (+2 Defense)
#===============================================================================
class PokeBattle_Move_02F
  alias dd_02f_target pbTarget unless method_defined?(:dd_02f_target)
  def pbTarget(user)
    return GameData::Target.get(:UserOrNearAlly) if DiffDupes::Moves.ally_mode?(self)
    return dd_02f_target(user)
  end

  alias dd_02f_failed pbMoveFailed? unless method_defined?(:dd_02f_failed)
  def pbMoveFailed?(user, targets)
    return false if DiffDupes::Moves.ally_mode?(self)   # checked per target
    return dd_02f_failed(user, targets)
  end

  # alias, not super: keeps another mod's wrapper on this class (any load order)
  alias dd_02f_fails pbFailsAgainstTarget? unless method_defined?(:dd_02f_fails)
  def pbFailsAgainstTarget?(user, target)
    return dd_02f_fails(user, target) unless DiffDupes::Moves.ally_mode?(self)
    return !target.pbCanRaiseStatStage?(@statUp[0], user, self, true)
  end

  alias dd_02f_against pbEffectAgainstTarget unless method_defined?(:dd_02f_against)
  def pbEffectAgainstTarget(user, target)
    return dd_02f_against(user, target) unless DiffDupes::Moves.ally_mode?(self)
    target.pbRaiseStatStage(@statUp[0], @statUp[1], user)
  end

  alias dd_02f_effect pbEffectGeneral unless method_defined?(:dd_02f_effect)
  def pbEffectGeneral(user)
    return if DiffDupes::Moves.ally_mode?(self)
    dd_02f_effect(user)
    return unless @id == :ACIDARMOR && DiffDupes.move_on?(:ACIDARMOR)
    user.dd_acid_turn = @battle.turnCount
    @battle.pbDisplay(_INTL("{1} is coated in acid!", user.pbThis))
  end
end

#===============================================================================
# Meditate, Sharpen (+1 Attack)
#===============================================================================
class PokeBattle_Move_01C
  alias dd_01c_failed pbMoveFailed? unless method_defined?(:dd_01c_failed)
  def pbMoveFailed?(user, targets)
    if DiffDupes.move_on?(@id) && !damagingMove?
      case @id
      when :MEDITATE
        return false if user.pbCanRaiseStatStage?(:ATTACK, user, self) ||
                        user.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user, self)
        @battle.pbDisplay(_INTL("{1}'s stats won't go any higher!", user.pbThis))
        return true
      when :SHARPEN
        return false if user.pbCanRaiseStatStage?(:ATTACK, user, self) ||
                        user.effects[PBEffects::FocusEnergy] < 3
        @battle.pbDisplay(_INTL("But it failed!"))
        return true
      end
    end
    return dd_01c_failed(user, targets)
  end

  alias dd_01c_effect pbEffectGeneral unless method_defined?(:dd_01c_effect)
  def pbEffectGeneral(user)
    if DiffDupes.move_on?(@id) && !damagingMove?
      case @id
      when :MEDITATE   # +1 Attack, +1 Sp. Def
        shown = false
        [:ATTACK, :SPECIAL_DEFENSE].each do |s|
          next unless user.pbCanRaiseStatStage?(s, user, self)
          user.pbRaiseStatStage(s, 1, user, !shown)
          shown = true
        end
        return
      when :SHARPEN    # +1 Attack, +1 critical-hit stage
        user.pbRaiseStatStage(:ATTACK, 1, user) if user.pbCanRaiseStatStage?(:ATTACK, user, self)
        if user.effects[PBEffects::FocusEnergy] < 3
          user.effects[PBEffects::FocusEnergy] += 1
          @battle.pbDisplay(_INTL("{1} sharpened its aim!", user.pbThis))
        end
        return
      end
    end
    dd_01c_effect(user)
  end
end

#===============================================================================
# Harden, Withdraw (+1 Defense)
#===============================================================================
class PokeBattle_Move_01D
  alias dd_01d_effect pbEffectGeneral unless method_defined?(:dd_01d_effect)
  def pbEffectGeneral(user)
    dd_01d_effect(user)
    return unless @id == :WITHDRAW && DiffDupes.move_on?(:WITHDRAW) && !damagingMove?
    user.dd_withdraw_turn = @battle.turnCount
    @battle.pbDisplay(_INTL("{1} is safe inside its shell!", user.pbThis))
  end
end

#===============================================================================
# Recover, Soft-Boiled, Milk Drink, Slack Off, Heal Order (heal 1/2)
#===============================================================================
# pbMoveFailed? stays on PokeBattle_HealingMove (0D5 inherits it): KIF-ER's AI
# finds its bleeding hook by the class that owns that method
class PokeBattle_HealingMove
  alias dd_0d5_failed pbMoveFailed? unless method_defined?(:dd_0d5_failed)
  def pbMoveFailed?(user, targets)
    if is_a?(PokeBattle_Move_0D5)
      return false if DiffDupes::Moves.ally_mode?(self)   # checked per target
      # Slack Off still works at full HP while drowsy (it cures Yawn)
      return false if @id == :SLACKOFF && DiffDupes.move_on?(:SLACKOFF) && user.effects[PBEffects::Yawn] > 0
    end
    return dd_0d5_failed(user, targets)
  end
end

class PokeBattle_Move_0D5
  alias dd_0d5_target pbTarget unless method_defined?(:dd_0d5_target)
  def pbTarget(user)
    return GameData::Target.get(:UserOrNearAlly) if DiffDupes::Moves.ally_mode?(self)
    return dd_0d5_target(user)
  end

  alias dd_0d5_fails pbFailsAgainstTarget? unless method_defined?(:dd_0d5_fails)
  def pbFailsAgainstTarget?(user, target)
    return dd_0d5_fails(user, target) unless DiffDupes::Moves.ally_mode?(self)
    if target.hp == target.totalhp
      @battle.pbDisplay(_INTL("{1}'s HP is full!", target.pbThis))
      return true
    end
    return false
  end

  alias dd_0d5_against pbEffectAgainstTarget unless method_defined?(:dd_0d5_against)
  def pbEffectAgainstTarget(user, target)
    return dd_0d5_against(user, target) unless DiffDupes::Moves.ally_mode?(self)
    target.pbRecoverHP((target.totalhp / 2.0).round)
    @battle.pbDisplay(_INTL("{1}'s HP was restored.", target.pbThis))
  end

  alias dd_0d5_effect pbEffectGeneral unless method_defined?(:dd_0d5_effect)
  def pbEffectGeneral(user)
    return if DiffDupes::Moves.ally_mode?(self)
    if @id == :SLACKOFF && DiffDupes.move_on?(:SLACKOFF)
      dd_0d5_effect(user) if user.hp < user.totalhp
      if user.effects[PBEffects::Yawn] > 0
        user.effects[PBEffects::Yawn] = 0
        @battle.pbDisplay(_INTL("{1} shook off its drowsiness!", user.pbThis))
      end
      return
    end
    dd_0d5_effect(user)
    return unless @id == :HEALORDER && DiffDupes.move_on?(:HEALORDER)
    user.eachAlly do |b|
      next if b.hp == b.totalhp
      b.pbRecoverHP((b.totalhp / 4.0).round)
      @battle.pbDisplay(_INTL("{1}'s HP was restored.", b.pbThis))
    end
  end
end

#===============================================================================
# Synthesis, Morning Sun, Moonlight (heal by weather)
#===============================================================================
class PokeBattle_Move_0D8
  alias dd_0d8_start pbOnStartUse unless method_defined?(:dd_0d8_start)
  def pbOnStartUse(user, targets)
    dd_0d8_start(user, targets)
    return unless DiffDupes.move_on?(@id) && @battle.pbWeather == :None
    better = (@id == :MORNINGSUN && PBDayNight.isDay?) ||
             (@id == :MOONLIGHT && PBDayNight.isNight?)
    @healAmount = (user.totalhp * 2 / 3.0).round if better
  end
end

#===============================================================================
# Mean Look, Block, Spider Web (trap)
#===============================================================================
class PokeBattle_Move_0EF
  alias dd_0ef_against pbEffectAgainstTarget unless method_defined?(:dd_0ef_against)
  def pbEffectAgainstTarget(user, target)
    dd_0ef_against(user, target)
    return unless DiffDupes.move_on?(@id) && !damagingMove?
    return unless target.effects[PBEffects::MeanLook] == user.index
    target.dd_web   = (@id == :SPIDERWEB)
    target.dd_block = (@id == :BLOCK)
  end
end

# U-turn/Volt Switch/Flip Turn, Baton Pass, Parting Shot: a Blocked user stays in
DiffDupes::Moves::PIVOTS.each do |code|
  name = "PokeBattle_Move_#{code}"
  next unless Object.const_defined?(name)
  Object.const_get(name).class_eval do
    alias_method :dd_pivot_end, :pbEndOfMoveUsageEffect unless method_defined?(:dd_pivot_end)
    def pbEndOfMoveUsageEffect(user, targets, numHits, switchedBattlers)
      if DiffDupes::Moves.blocked?(user) && !user.fainted? && numHits > 0 &&
         @battle.pbCanChooseNonActive?(user.index)
        @battle.pbDisplay(_INTL("{1} is blocked and can't switch out!", user.pbThis))
        return
      end
      dd_pivot_end(user, targets, numHits, switchedBattlers)
    end
  end
end

# Both AIs: a Blocked Pokemon's pivot moves are scored as if it had nothing to
# switch to (each AI's own "can't switch" scoring)
class PokeBattle_Battle
  attr_accessor :dd_no_switch

  alias dd_pbCanChooseNonActive? pbCanChooseNonActive? unless method_defined?(:dd_pbCanChooseNonActive?)
  def pbCanChooseNonActive?(idxBattler)
    return false if @dd_no_switch == idxBattler
    return dd_pbCanChooseNonActive?(idxBattler)
  end
end

class PokeBattle_AI
  # Each AI's own score change for a Protect that would do nothing
  DD_PROTECT_POINTLESS = { :pif => 90, :demice => 200 }

  alias dd_pbGetMoveScoreFunctionCode pbGetMoveScoreFunctionCode unless method_defined?(:dd_pbGetMoveScoreFunctionCode)
  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
    if DiffDupes::Moves::PIVOTS.include?(move.function) && DiffDupes::Moves.blocked?(user)
      @battle.dd_no_switch = user.index
      begin
        ret = dd_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
      ensure
        @battle.dd_no_switch = nil
      end
    else
      ret = dd_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
    end
    # Detect: the foe's best attack never misses, so dodging doesn't help
    if ret.is_a?(Numeric) && move.id == :DETECT && DiffDupes.move_on?(:DETECT) && dd_detect_pierced?(user, skill)
      demice = defined?(KIF::PowerfulAI) && KIF::PowerfulAI.respond_to?(:on?) && KIF::PowerfulAI.on?
      ret -= DD_PROTECT_POINTLESS[demice ? :demice : :pif]
    end
    return ret
  end

  def dd_detect_pierced?(user, skill)
    foe = user.pbDirectOpposing(true)
    return false if !foe || foe.fainted?
    best, best_dmg = nil, 0
    foe.eachMove do |m|
      next if !m.damagingMove? || pbCheckMoveImmunity(1, m, foe, user, skill)
      d = pbRoughDamage(m, foe, user, skill, pbMoveBaseDamage(m, foe, user, skill))
      best, best_dmg = m, d if d > best_dmg
    end
    return best ? DiffDupes::Moves.sure_hit?(best, foe, user) : false
  rescue StandardError => e
    DiffDupes.log("AI Detect: #{e.class}: #{e.message}")
    return false
  end

  # Block: U-turn, Baton Pass and Parting Shot don't get a Blocked foe out
  # (KIF's trap value, KIF 0.21.6x+)
  if method_defined?(:kif_ai_trap_escape_codes)
    alias dd_kif_ai_trap_escape_codes kif_ai_trap_escape_codes unless method_defined?(:dd_kif_ai_trap_escape_codes)
    def kif_ai_trap_escape_codes(user, move, target)
      ret = dd_kif_ai_trap_escape_codes(user, move, target)
      return ret unless move && move.id == :BLOCK && move.statusMove? && DiffDupes.move_on?(:BLOCK)
      return ret - DiffDupes::Moves::PIVOTS
    end
  end
end
