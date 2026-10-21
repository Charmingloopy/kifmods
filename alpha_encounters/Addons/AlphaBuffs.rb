# ============================================================
# AlphaSTAB - Alpha damage bonuses
#
# 1. Natural Adaptability: STAB moves hit at 2x instead of 1.5x.
#    Stacks with Adaptability (Adaptability alpha = ~2.67x STAB).
#
# 2. Weak Technician: moves with 60 BP or less get a 1.2x boost.
#    Stacks with Technician (Technician alpha = 1.5x * 1.2x = 1.8x).
# ============================================================

class PokeBattle_Move
  alias alpha_stab_pbCalcDamageMultipliers pbCalcDamageMultipliers
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    alpha_stab_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    return if !user.alpha?

    # ---- Natural Adaptability ------------------------------------------
    if !type.nil? && type != :NONE && user.pbHasType?(type)
      multipliers[:final_damage_multiplier] *= 4.0 / 3.0
    end

    # ---- Weak Technician -----------------------------------------------
    if baseDmg <= 60
      multipliers[:base_damage_multiplier] *= 1.2
    end
  end
end


# ============================================================
# AlphaStatBoost - Alpha Pokemon get a 10% boost to base stats
# Boosts the base value before the stat formula runs, so IVs,
# EVs, and natures all scale off the boosted base correctly.
# HP also receives the existing 35% final boost from core on
# top of this — the two stack independently.
# ============================================================

class Pokemon
  alias alpha_statboost_calcStat calcStat
  def calcStat(base, level, iv, ev, nature)
    base = (base * 1.25).floor if alpha?
    alpha_statboost_calcStat(base, level, iv, ev, nature)
  end

  alias alpha_statboost_calcHP calcHP
  def calcHP(base, level, iv, ev)
    base = (base * 1.45).floor if alpha?
    alpha_statboost_calcHP(base, level, iv, ev)
  end
end
