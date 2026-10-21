#===============================================================================
# KIF: Elite Redux – effects for Elite Redux moves PIF doesn't have (moves
# step 3, first batch). The moves are in the game through 064 once coded here.
#   Blood Shot     – makes the target bleed (fails with New features > Bleeding Off)
#   Flash Freeze   – frostbites the target; never misses from an Ice-type user
#                    (fails with New features > Frostbite Off)
#   Body Press     – uses the user's Defense (and its stages) as its attack
#   Poltergeist    – fails if the target holds no item
#   Lash Out       – +20 power for each of the user's lowered stat stages; its
#                    Attack drops don't count
#   Lovely Bite    – its effect chance infatuates the target
#   Rising Voltage – x2 power on Electric Terrain against a grounded target
#   Battle AI (both): Blood Shot / Flash Freeze score 0 when the status can't
#   land; Poltergeist 0 against a foe without an item; the damage estimate
#   knows Body Press, Lash Out and Rising Voltage.
#===============================================================================
module KIFER
  module NewMoveFx
    module_function

    def lowered_stages(b)
      return b.stages.values.sum { |v| v < 0 ? -v : 0 }
    end

    def rising?(battle, target)
      return battle.field.terrain == :Electric && target && !target.airborne?
    end

    # the AI's damage estimate for the rules it can't see
    def ai_damage(battle, ret, code, move, user, target)
      case code
      when "KERD03"   # Body Press: Defense instead of Attack
        atk = user.attack.to_f
        return atk > 0 ? (ret * user.defense / atk).round : ret
      when "KERD04" then return 0 if target && !target.item
      end
      return ret
    end

    def ai_base_damage(battle, ret, code, move, user, target)
      case code
      when "KERD05" then return ret + 20 * lowered_stages(user)
      when "KERD07" then return ret * 2 if rising?(battle, target)
      end
      return ret
    end

    # 0 when the status move can't work
    def ai_useless?(code, move, user, target)
      return false if !target
      case code
      when "KERD01" then return !KIFER.feature_on?(:bleeding) || !target.pbCanBleed?(user, false, move)
      when "KERD02" then return !KIFER.feature_on?(:frostbite) || !target.pbCanFrostbite?(user, false, move)
      when "KERD04" then return !target.item
      end
      return false
    end
  end
end

class PokeBattle_Move_KERD01 < PokeBattle_Move   # Blood Shot
  def pbFailsAgainstTarget?(user, target)
    if !KIFER.feature_on?(:bleeding)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return !target.pbCanBleed?(user, true, self)
  end

  def pbEffectAgainstTarget(user, target)
    target.pbBleed(user)
  end
end

class PokeBattle_Move_KERD02 < PokeBattle_Move   # Flash Freeze
  def pbBaseAccuracy(user, target)
    return 0 if user.pbHasType?(:ICE)
    return super
  end

  def pbFailsAgainstTarget?(user, target)
    if !KIFER.feature_on?(:frostbite)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return !target.pbCanFrostbite?(user, true, self)
  end

  def pbEffectAgainstTarget(user, target)
    target.pbFrostbite(user)
  end
end

class PokeBattle_Move_KERD03 < PokeBattle_Move   # Body Press
  def pbGetAttackStats(user, target)
    return user.defense, user.stages[:DEFENSE] + 6
  end
end

class PokeBattle_Move_KERD04 < PokeBattle_Move   # Poltergeist
  def pbFailsAgainstTarget?(user, target)
    if !target.item
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    @battle.pbDisplay(_INTL("{1} is about to be attacked by its {2}!", target.pbThis, target.itemName))
    return false
  end
end

class PokeBattle_Move_KERD05 < PokeBattle_Move   # Lash Out
  def pbBaseDamage(baseDmg, user, target)
    return baseDmg + 20 * KIFER::NewMoveFx.lowered_stages(user)
  end

  def pbGetAttackStats(user, target)
    stat, stage = super
    return stat, [stage, 6].max
  end
end

class PokeBattle_Move_KERD06 < PokeBattle_Move   # Lovely Bite
  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    target.pbAttract(user) if target.pbCanAttract?(user, false)
  end
end

class PokeBattle_Move_KERD07 < PokeBattle_Move   # Rising Voltage
  def pbBaseDamage(baseDmg, user, target)
    return KIFER::NewMoveFx.rising?(@battle, target) ? baseDmg * 2 : baseDmg
  end
end

KIFER::NewMoveFx::CODES = %w[KERD01 KERD02 KERD03 KERD04 KERD05 KERD06 KERD07].freeze

class PokeBattle_AI
  alias kifer_nmf_pbGetMoveScoreFunctionCode pbGetMoveScoreFunctionCode unless method_defined?(:kifer_nmf_pbGetMoveScoreFunctionCode)
  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
    f = move && move.function
    if f && KIFER::NewMoveFx::CODES.include?(f) && KIFER::NewMoveFx.ai_useless?(f, move, user, target)
      return KIFER::AI.demice_on? ? -score : 0
    end
    return kifer_nmf_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
  end

  alias kifer_nmf_pbMoveBaseDamage pbMoveBaseDamage unless method_defined?(:kifer_nmf_pbMoveBaseDamage)
  def pbMoveBaseDamage(move, user, target, *rest)
    ret = kifer_nmf_pbMoveBaseDamage(move, user, target, *rest)
    f = move && move.function
    return ret if !f || !KIFER::NewMoveFx::CODES.include?(f) || !ret.is_a?(Numeric)
    return KIFER::NewMoveFx.ai_base_damage(@battle, ret, f, move, user, target)
  end

  alias kifer_nmf_pbRoughDamage pbRoughDamage unless method_defined?(:kifer_nmf_pbRoughDamage)
  def pbRoughDamage(move, user, target, *args)
    ret = kifer_nmf_pbRoughDamage(move, user, target, *args)
    f = move && move.function
    return ret if !f || !KIFER::NewMoveFx::CODES.include?(f) || !ret.is_a?(Numeric)
    return KIFER::NewMoveFx.ai_damage(@battle, ret, f, move, user, target)
  end
end

# the new classes get 031's and 033's per-class hooks too
KIFER::NewMoveFx::CODES.each do |c|
  k = Object.const_get("PokeBattle_Move_#{c}")
  KIFER::TerrainEnrage.wrap_move_class(k) if defined?(KIFER::TerrainEnrage) && KIFER::TerrainEnrage.respond_to?(:wrap_move_class)
end
KIFER::Statuses.hook_heal_moves if defined?(KIFER::Statuses) && KIFER::Statuses.respond_to?(:hook_heal_moves)

KIFER::Moves.coded(:BLOODSHOT, function_code: "KERD01")
KIFER::Moves.coded(:FLASHFREEZE, function_code: "KERD02")
KIFER::Moves.coded(:BODYPRESS, function_code: "KERD03")
KIFER::Moves.coded(:POLTERGEIST, function_code: "KERD04")
KIFER::Moves.coded(:LASHOUT, function_code: "KERD05")
KIFER::Moves.coded(:LOVELYBITE, function_code: "KERD06")
KIFER::Moves.coded(:RISINGVOLTAGE, function_code: "KERD07")
KIFER::NewMoves.register   # in the game now (064)
