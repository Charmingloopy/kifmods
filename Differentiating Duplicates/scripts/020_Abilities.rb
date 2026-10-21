#===============================================================================
# Differentiating Duplicates - abilities (setting "Changed abilities")
# Handler changes go through DiffDupes.ability_hook (001_Core.rb), so the
# "KIF:ER conflicts" setting decides which version runs.
#===============================================================================
module DiffDupes
  module Abilities
    LIGHT_MOVES = [:SIGNALBEAM, :FLASHCANNON, :DAZZLINGGLEAM, :LUSTERPURGE, :MIRRORSHOT,
                   :AURORABEAM, :SOLARBEAM, :SOLARBLADE, :PHOTONGEYSER, :PRISMATICLASER,
                   :LIGHTOFRUIN, :CHARGEBEAM]
    SLEEP_FUNCTIONS = ["003", "004"]   # sleep moves, Yawn

    # Battle Armor: no damage from Rough Skin, Iron Barbs or Rocky Helmet
    def self.armor_blocks?(user)
      return user.hasActiveAbility?(:BATTLEARMOR) && DiffDupes.ability_on?(:BATTLEARMOR)
    end

    # Keen Eye: Psychic moves hit Dark types for not very effective damage
    def self.keen_eye(ret, move_type, def_type, user)
      return ret unless move_type == :PSYCHIC && def_type == :DARK && Effectiveness.ineffective?(ret)
      return ret unless user && user.hasActiveAbility?(:KEENEYE) && DiffDupes.ability_on?(:KEENEYE)
      return Effectiveness::NOT_VERY_EFFECTIVE_ONE
    end

    # White Smoke: a foe whose stat drop it blocked loses 1 accuracy (once a round)
    def self.white_smoke(bearer, user)
      return if @ws_busy
      return unless user && !user.fainted? && user.index != bearer.index && user.opposes?(bearer)
      key = [bearer.battle.object_id, bearer.battle.turnCount, user.index, bearer.index]   # per battle: a new battle starts at turn 0 again
      return if @ws_last == key
      @ws_last = key
      @ws_busy = true   # two White Smokes mustn't trigger each other forever
      begin
        user.pbLowerStatStageByAbility(:ACCURACY, 1, bearer, true)
      ensure
        @ws_busy = false
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Vital Spirit (+1 Speed) / Insomnia (+1 Sp. Atk): absorb sleep moves
#-------------------------------------------------------------------------------
{ :VITALSPIRIT => :SPEED, :INSOMNIA => :SPECIAL_ATTACK }.each do |id, stat|
  DiffDupes.ability_hook(:MoveImmunityTargetAbility, id) do |pif, cur, ability, user, target, move, type, battle|
    if move.statusMove? && DiffDupes::Abilities::SLEEP_FUNCTIONS.include?(move.function) &&
       user.index != target.index
      battle.pbShowAbilitySplash(target)
      if target.pbCanRaiseStatStage?(stat, target)
        target.pbRaiseStatStage(stat, 1, target)
      else
        battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
      end
      battle.pbHideAbilitySplash(target)
      next true
    end
    next pif ? pif.call(ability, user, target, move, type, battle) : false
  end
end
DiffDupes.ability_hook(:UserAbilityEndOfMove, :VITALSPIRIT)   # PIF has none: cancels KIF-ER's

#-------------------------------------------------------------------------------
# Solid Rock: 4x weaknesses halved, 2x weaknesses x0.75 (Filter unchanged)
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:DamageCalcTargetAbility, :SOLIDROCK) do |pif, cur, ability, user, target, move, mults, baseDmg, type|
  tm = target.damageState.typeMod
  if tm >= Effectiveness::NORMAL_EFFECTIVE * 4
    mults[:final_damage_multiplier] *= 0.5
  elsif Effectiveness.super_effective?(tm)
    mults[:final_damage_multiplier] *= 0.75
  end
end

#-------------------------------------------------------------------------------
# Turboblaze / Teravolt: Fire / Electric moves x1.1 (Mold Breaker unchanged)
#-------------------------------------------------------------------------------
{ :TURBOBLAZE => :FIRE, :TERAVOLT => :ELECTRIC }.each do |id, boost_type|
  DiffDupes.ability_hook(:DamageCalcUserAbility, id) do |pif, cur, ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.1 if type == boost_type
    pif.call(ability, user, target, move, mults, baseDmg, type) if pif
  end
  DiffDupes.ability_hook(:AbilityOnSwitchIn, id)   # PIF's entry message only
end

#-------------------------------------------------------------------------------
# Keen Eye: Psychic moves can hit Dark types (not very effective)
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:AccuracyCalcUserAbility, :KEENEYE)   # PIF's accuracy effect only

class PokeBattle_Move
  alias dd_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:dd_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = dd_pbCalcTypeModSingle(moveType, defType, user, target)
    return DiffDupes::Abilities.keen_eye(ret, moveType, defType, user)
  end

  # Illuminate: light moves x1.2 for everyone while it's on the field
  alias dd_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:dd_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    dd_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    if DiffDupes::Abilities::LIGHT_MOVES.include?(@id) && DiffDupes.ability_on?(:ILLUMINATE) &&
       @battle.pbCheckGlobalAbility(:ILLUMINATE)
      multipliers[:base_damage_multiplier] *= 1.2
    end
  end
end

class PokeBattle_AI
  alias dd_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:dd_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = dd_pbCalcTypeModSingle(moveType, defType, user, target)
    return DiffDupes::Abilities.keen_eye(ret, moveType, defType, user)
  end

  # Illuminate for both AIs (PIF and DemICE share this method): the damage
  # estimate doesn't call PokeBattle_Move#pbCalcDamageMultipliers
  alias dd_pbRoughDamage pbRoughDamage unless method_defined?(:dd_pbRoughDamage)
  def pbRoughDamage(move, user, target, *args)
    ret = dd_pbRoughDamage(move, user, target, *args)
    begin
      return ret unless ret.is_a?(Numeric) && ret > 0
      return ret unless DiffDupes::Abilities::LIGHT_MOVES.include?(move.id)
      return ret unless DiffDupes.ability_on?(:ILLUMINATE) && @battle.pbCheckGlobalAbility(:ILLUMINATE)
      return (ret * 1.2).floor
    rescue StandardError => e
      DiffDupes.log("AI Illuminate: #{e.class}: #{e.message}")
      return ret
    end
  end

  # Solid Rock for both AIs: KIF's one method for Filter / Solid Rock in the
  # damage estimate (KIF 0.21.58+; older KIF: the AI keeps x0.75)
  if method_defined?(:kif_ai_weakness_ability_multiplier)
    alias dd_kif_ai_weakness_ability_multiplier kif_ai_weakness_ability_multiplier unless method_defined?(:dd_kif_ai_weakness_ability_multiplier)
    def kif_ai_weakness_ability_multiplier(user, target, move, type, typeMod, moldBreaker)
      ret = dd_kif_ai_weakness_ability_multiplier(user, target, move, type, typeMod, moldBreaker)
      begin
        return ret if moldBreaker || typeMod < Effectiveness::NORMAL_EFFECTIVE * 4
        return ret unless target.hasActiveAbility?(:SOLIDROCK) && DiffDupes.ability_on?(:SOLIDROCK)
        return target.hasActiveAbility?(:FILTER) ? 0.5 * 0.75 : 0.5   # both: they stack (Cody's rule)
      rescue StandardError => e
        DiffDupes.log("AI Solid Rock: #{e.class}: #{e.message}")
        return ret
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Illuminate: cancel KIF-ER's version when this mod wins
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:AccuracyCalcUserAbility, :ILLUMINATE)
DiffDupes.ability_hook(:UserAbilityOnHit, :ILLUMINATE)

#-------------------------------------------------------------------------------
# Pure Power: can't be confused (Huge Power unchanged)
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:StatusCureAbility, :PUREPOWER) do |pif, cur, ability, battler|
  pif.call(ability, battler) if pif
  next if battler.effects[PBEffects::Confusion] == 0
  battler.battle.pbShowAbilitySplash(battler)
  battler.pbCureConfusion
  battler.battle.pbDisplay(_INTL("{1} snapped out of its confusion.", battler.pbThis))
  battler.battle.pbHideAbilitySplash(battler)
end

#-------------------------------------------------------------------------------
# White Smoke: blocking a foe's stat drop lowers the foe's accuracy
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:AbilityOnSwitchIn, :WHITESMOKE)   # PIF has none: cancels KIF-ER's smoke
DiffDupes.ability_hook(:StatLossImmunityAbility, :WHITESMOKE) do |pif, cur, ability, battler, stat, battle, showMessages|
  ret = pif ? pif.call(ability, battler, stat, battle, showMessages) : false
  # showMessages: a move's own drop; live: a side effect or ability drop while a
  # move really hits. Quiet checks (the AI's) stay quiet.
  battler.dd_ws_blocked = true if ret && (showMessages || battle.dd_ws_live?)
  next ret
end

#-------------------------------------------------------------------------------
# Air Lock: also ends Tailwind on both sides when it enters (Cloud Nine unchanged)
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:AbilityOnSwitchIn, :AIRLOCK) do |pif, cur, ability, battler, battle|
  pif.call(ability, battler, battle) if pif
  sides = battle.sides.select { |s| s.effects[PBEffects::Tailwind] > 0 }
  next if sides.empty?
  sides.each { |s| s.effects[PBEffects::Tailwind] = 0 }
  battle.pbDisplay(_INTL("The tailwind stopped blowing!"))
end

#-------------------------------------------------------------------------------
# Battle Armor: no damage from Rough Skin, Iron Barbs, Rocky Helmet
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:DamageCalcTargetAbility, :BATTLEARMOR)   # PIF has none: cancels KIF-ER's x0.8
DiffDupes.ability_hook(:TargetAbilityOnHit, :ROUGHSKIN, :BATTLEARMOR) do |pif, cur, ability, user, target, move, battle|
  next if DiffDupes::Abilities.armor_blocks?(user)
  cur.call(ability, user, target, move, battle) if cur
end
DiffDupes.ability_hook(:TargetItemOnHit, :ROCKYHELMET, :BATTLEARMOR) do |pif, cur, item, user, target, move, battle|
  next if DiffDupes::Abilities.armor_blocks?(user)
  cur.call(item, user, target, move, battle) if cur
end

#-------------------------------------------------------------------------------
# Iron Barbs: Steel-type damage, 1/8 scaled by type matchup (Rough Skin unchanged)
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:TargetAbilityOnHit, :IRONBARBS) do |pif, cur, ability, user, target, move, battle|
  next unless move.pbContactMove?(user)
  next if DiffDupes::Abilities.armor_blocks?(user)
  battle.pbShowAbilitySplash(target)
  if user.takesIndirectDamage?(PokeBattle_SceneConstants::USE_ABILITY_SPLASH) &&
     user.affectedByContactEffect?(PokeBattle_SceneConstants::USE_ABILITY_SPLASH)
    t = user.pbTypes(true)
    eff = Effectiveness.calculate(:STEEL, t[0], t[1], t[2])
    amt = (user.totalhp * eff / (Effectiveness::NORMAL_EFFECTIVE * 8.0)).round
    amt = 1 if amt < 1
    battle.scene.pbDamageAnimation(user)
    user.pbReduceHP(amt, false)
    battle.pbDisplay(_INTL("{1} is hurt by the iron barbs!", user.pbThis))
  end
  battle.pbHideAbilitySplash(target)
end

#-------------------------------------------------------------------------------
# Tangling Hair: a contact attacker can't switch out next round (Gooey unchanged)
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:TargetAbilityOnHit, :TANGLINGHAIR) do |pif, cur, ability, user, target, move, battle|
  pif.call(ability, user, target, move, battle) if pif
  next unless move.pbContactMove?(user) && !user.fainted? && user.affectedByContactEffect?
  next if user.dd_tangle_turn == battle.turnCount + 1   # multi-hit: tangle once
  user.dd_tangle_turn = battle.turnCount + 1
  battle.pbDisplay(_INTL("{1} got tangled up!", user.pbThis))
end

#-------------------------------------------------------------------------------
# Minus: Speed x1.5 with a Plus/Minus ally instead of Sp. Atk (Plus unchanged)
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:DamageCalcUserAbility, :MINUS) { |*_args| nil }
DiffDupes.ability_hook(:SpeedCalcAbility, :MINUS) do |pif, cur, ability, battler, mult|
  partner = false
  battler.eachAlly { |b| partner = true if b.hasActiveAbility?([:MINUS, :PLUS]) }
  next partner ? mult * 1.5 : mult
end

#-------------------------------------------------------------------------------
# Queenly Majesty: blocking a priority move also lowers the attacker's Attack
#-------------------------------------------------------------------------------
DiffDupes.ability_hook(:MoveBlockingAbility, :QUEENLYMAJESTY) do |pif, cur, ability, bearer, user, targets, move, battle|
  ret = pif ? pif.call(ability, bearer, user, targets, move, battle) : false
  user.dd_qm_by = bearer if ret
  next ret
end

#===============================================================================
# Method hooks for the abilities above
#===============================================================================
class PokeBattle_Battler
  # Pure Power
  alias dd_pbCanConfuse? pbCanConfuse? unless method_defined?(:dd_pbCanConfuse?)
  def pbCanConfuse?(user = nil, showMessages = true, move = nil, selfInflicted = false)
    if !fainted? && @effects[PBEffects::Confusion] == 0 && (selfInflicted || !@battle.moldBreaker) &&
       hasActiveAbility?(:PUREPOWER) && DiffDupes.ability_on?(:PUREPOWER)
      if showMessages
        @battle.pbShowAbilitySplash(self)
        @battle.pbDisplay(_INTL("{1} doesn't become confused!", pbThis))
        @battle.pbHideAbilitySplash(self)
      end
      return false
    end
    return dd_pbCanConfuse?(user, showMessages, move, selfInflicted)
  end

  # White Smoke
  alias dd_pbCanLowerStatStage? pbCanLowerStatStage? unless method_defined?(:dd_pbCanLowerStatStage?)
  def pbCanLowerStatStage?(stat, user = nil, move = nil, showFailMsg = false, ignoreContrary = false)
    @dd_ws_blocked = false
    ret = dd_pbCanLowerStatStage?(stat, user, move, showFailMsg, ignoreContrary)
    if !ret && @dd_ws_blocked
      @dd_ws_blocked = false
      DiffDupes::Abilities.white_smoke(self, user)
    end
    return ret
  end

  # White Smoke: side-effect and on-hit ability drops happen in here
  alias dd_pbProcessMoveHit pbProcessMoveHit unless method_defined?(:dd_pbProcessMoveHit)
  def pbProcessMoveHit(*args)
    return @battle.dd_ws_live { dd_pbProcessMoveHit(*args) }
  end

  # Queenly Majesty: runs right after the "cannot use" message
  alias dd_pbCancelMoves pbCancelMoves unless method_defined?(:dd_pbCancelMoves)
  def pbCancelMoves(full_cancel = false)
    dd_pbCancelMoves(full_cancel)
    by = @dd_qm_by
    return unless by
    @dd_qm_by = nil
    pbLowerStatStageByAbility(:ATTACK, 1, by) unless fainted?
  end
end

class PokeBattle_Battle
  # White Smoke: true while a move is really hitting (not an AI estimate)
  def dd_ws_live?
    return (@dd_ws_live || 0) > 0
  end

  def dd_ws_live
    @dd_ws_live = (@dd_ws_live || 0) + 1
    return yield
  ensure
    @dd_ws_live -= 1
  end

  # Tangling Hair
  alias dd_pbCanSwitch? pbCanSwitch? unless method_defined?(:dd_pbCanSwitch?)
  def pbCanSwitch?(idxBattler, idxParty = -1, partyScene = nil)
    ret = dd_pbCanSwitch?(idxBattler, idxParty, partyScene)
    return ret unless ret
    b = @battlers[idxBattler]
    return ret unless b && b.dd_tangle_turn == @turnCount && DiffDupes.ability_on?(:TANGLINGHAIR)
    return ret if b.hasActiveItem?(:SHEDSHELL)
    return ret if Settings::MORE_TYPE_EFFECTS && b.pbHasType?(:GHOST)
    partyScene.pbDisplay(_INTL("{1} is tangled up and can't be switched out!", b.pbThis)) if partyScene
    return false
  end
end
