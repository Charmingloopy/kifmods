#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch E)
#   Mechanics follow Elite Redux 2.65 (its C source and in-game texts).
#
#   Multi-Headed   – 2-headed: 2 hits (2nd 25%); 3-headed: 3 hits (2nd 20%,
#                    3rd 15%). Head count from ER's species list (a fusion
#                    uses its head or body, whichever has more). Flinch only
#                    on the 1st hit.
#   Pyromancy      – burn chance x5 on every move that can burn (max 100%)
#   Haunted Spirit – KO'd by an attack: curses the attacker (not Ghosts)
#   Power Fists    – punching moves x1.3 and hit Sp. Def instead of Defense
#   Giant Wings    – wing, wind and air moves x1.3
#   Dreamcatcher   – moves x2 while any Pokemon on the field is asleep
#   Transistor     – Electric moves x1.5
#   Permafrost     – super-effective hits on it x0.65
#   Loose Quills   – hit by a contact move: a layer of Spikes on the foe's side
#   Toxic Debris   – hit by a contact move: a layer of Toxic Spikes on the foe's side
#   Dragon's Maw   – Dragon moves x1.5
#   Ill Will       – the move that KOs it loses all its PP
#   Lullaby        – Sing's accuracy is 90%
#   Scrapyard      – same as Loose Quills
#   Ancient Idol   – attacks with Defense (physical) / Sp. Def (special)
#   Fae Hunter     – x1.5 against Fairy-type Pokemon; x0.5 from Fairy-type attackers
#   Jaws of Carnage – a KO heals 1/2 of its max HP with a biting move, else 1/4
#   Phantom Pain   – its Ghost moves hit Normal types (1x)
#   Web Spinner    – on entry: Speed -2 to the foes next to it
#   Catastrophe    – Water moves in sun and Fire moves in rain get x1.5
#                    (the weather's boost instead of its cut)
#   Doombringer    – on entry: Doom Desire on the foe in front of it
#   Gravity Well   – on entry: Gravity for 5 turns
#   Monster Mash   – on entry: Trick-or-Treat on the foe in front of it
#                    (one added-type slot, as ER: it replaces a type another
#                    ability added, e.g. Metallic's Steel)
#   Propeller Tail – Speed x1.5 in rain; its moves can't be redirected
#   Readied Action – Attack x2 on its first turn in battle (again after each switch-in)
#   Shocking Jaws  – biting moves: 50% chance to paralyze
#   Toxic Spill    – end of each turn: non-Poison Pokemon lose 1/8 HP
#                    (Poison Heal: gain 1/8 instead; Toxic Boost: nothing),
#                    while it is on the field
#
# Left out at first, now coded in 030-035 (fog, frostbite/bleeding,
# fear, Toxic Terrain/enrage, one-offs).
#===============================================================================
KIFER.er_code(:MULTIHEADED, :PYROMANCY, :HAUNTEDSPIRIT, :POWERFISTS, :GIANTWINGS,
                :DREAMCATCHER, :TRANSISTOR, :PERMAFROST, :LOOSEQUILLS, :TOXICDEBRIS,
                :DRAGONSMAW, :ILLWILL, :LULLABY, :SCRAPYARD, :ANCIENTIDOL, :FAEHUNTER,
                :JAWSOFCARNAGE, :PHANTOMPAIN, :WEBSPINNER, :CATASTROPHE, :DOOMBRINGER,
                :GRAVITYWELL, :MONSTERMASH, :PROPELLERTAIL, :READIEDACTION,
                :SHOCKINGJAWS, :TOXICSPILL)

module KIFER
  module BatchE
    # Moves whose added effect is a burn (Pyromancy): Ember, Scald & co., Ice
    # Burn, Flare Blitz, Secret Power on volcano ground. Fire Fang and Tri
    # Attack, whose roll also flinches / freezes / paralyzes, are below.
    BURN_FUNCTIONS = ["00A", "0C6", "0FE"]
    def self.burn_move?(move)
      return true if BURN_FUNCTIONS.include?(KIFER.pif_function(move))
      return move.function == "0A4" && move.instance_variable_get(:@secretPower) == 10
    end

    # ER's wing, wind and air moves (Giant Wings; the same list as Imposing Wings)
    AIR_MOVES = KIFER::BatchC::AIR_MOVES

    # ER's two- and three-headed species (Multi-Headed)
    HEADS = {
      :DODUO => 2, :WEEZING => 2, :GIRAFARIG => 2, :MAWILE => 2, :VANILLUXE => 2,
      :KLINK => 2, :ZWEILOUS => 2, :DOUBLADE => 2, :BINACLE => 2,
      :DUGTRIO => 3, :MAGNETON => 3, :DODRIO => 3, :EXEGGUTOR => 3, :COMBEE => 3,
      :MAGNEZONE => 3, :PROBOPASS => 3, :KLANG => 3, :KLINKLANG => 3,
      :HYDREIGON => 3, :BARBARACLE => 3
    }

    # How many heads a battler's Pokemon has (0 = not a multi-headed species)
    def self.heads(battler)
      pkmn = battler.pokemon
      return 0 unless pkmn
      if pkmn.respond_to?(:isFusion?) && pkmn.isFusion?
        return [HEADS[pkmn.get_head_species.id] || 0, HEADS[pkmn.get_body_species.id] || 0].max
      end
      return HEADS[pkmn.species] || 0
    rescue StandardError
      return 0
    end

    # A hit after the first one that can't flinch: Multi-Headed's extra heads,
    # and the 2nd hit of Hyper Aggressive (008) and Raging Boxer (022)
    def self.no_flinch_hit?(user)
      hit = head_hit(user)
      return true if hit && hit > 1
      return user.instance_variable_get(:@kifer_e_nf2) == true &&
             user.effects[PBEffects::ParentalBond] == 1
    end

    # Hit number (1, 2, 3) of the move it is using now, or nil when the extra
    # hits aren't from Multi-Headed
    def self.head_hit(user)
      heads = user.instance_variable_get(:@kifer_e_heads)
      return nil unless heads
      pb = user.effects[PBEffects::ParentalBond]
      return nil if pb <= 0
      return heads + 1 - pb
    end
  end
end

class PokeBattle_Move
  #-----------------------------------------------------------------------------
  # Multi-Headed – extra hits. PIF's Parental Bond counter marks the hits:
  # it is set to heads + 1 and goes down by 1 before each hit.
  #-----------------------------------------------------------------------------
  alias kifer_e_pbNumHits pbNumHits unless method_defined?(:kifer_e_pbNumHits)
  def pbNumHits(user, targets)
    user.instance_variable_set(:@kifer_e_nf2, false)
    n = kifer_e_pbNumHits(user, targets)
    user.instance_variable_set(:@kifer_e_heads, nil)
    # Hyper Aggressive / Raging Boxer made it hit twice (not PIF's Parental
    # Bond, which runs first and can flinch on both hits)
    if n == 2 && user.effects[PBEffects::ParentalBond] == 3 &&
       !user.hasActiveAbility?(:PARENTALBOND) &&
       (user.instance_variable_get(:@kifer_c_boxer) || user.hasActiveAbility?(:HYPERAGGRESSIVE))
      user.instance_variable_set(:@kifer_e_nf2, true)
    end
    if n == 1 && pbDamagingMove? && !chargingTurnMove? && targets.length == 1 &&
       user.hasActiveAbility?(:MULTIHEADED)
      heads = KIFER::BatchE.heads(user)
      if heads >= 2
        user.effects[PBEffects::ParentalBond] = heads + 1
        user.instance_variable_set(:@kifer_e_heads, heads)
        return heads
      end
    end
    return n
  end

  alias kifer_e_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_e_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    kifer_e_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    # Multi-Headed: 2 heads: 100% / 25%; 3 heads: 100% / 20% / 15%
    hit = KIFER::BatchE.head_hit(user)
    if hit && hit > 1
      heads = user.instance_variable_get(:@kifer_e_heads)
      # the game already quartered the last hit (Parental Bond); undo that
      multipliers[:base_damage_multiplier] *= 4 if hit == heads
      multipliers[:final_damage_multiplier] *= (heads == 2) ? 0.25 : (hit == 2 ? 0.2 : 0.15)
    end
    # Catastrophe: Water in sun / Fire in rain are boosted x1.5 instead of halved
    if type && user.hasActiveAbility?(:CATASTROPHE)
      w = @battle.pbWeather
      if (type == :WATER && [:Sun, :HarshSun].include?(w)) ||
         (type == :FIRE && [:Rain, :HeavyRain].include?(w))
        multipliers[:final_damage_multiplier] *= 3
      end
    end
  end

  #-----------------------------------------------------------------------------
  # Pyromancy – burn chance x5 on moves that can burn (max 100%)
  # Multi-Headed – flinch only on the 1st hit
  #-----------------------------------------------------------------------------
  alias kifer_e_pbAdditionalEffectChance pbAdditionalEffectChance unless method_defined?(:kifer_e_pbAdditionalEffectChance)
  def pbAdditionalEffectChance(user, target, effectChance = 0)
    ret = kifer_e_pbAdditionalEffectChance(user, target, effectChance)
    return ret if ret <= 0
    if user.hasActiveAbility?(:PYROMANCY)
      if KIFER::BatchE.burn_move?(self)
        ret = [ret * 5, 100].min
      elsif @function == "017"   # Tri Attack: burn's third x5 (5 + 1 + 1 thirds)
        ret = [(ret * 7 / 3.0).round, 100].min
      end
    end
    return 0 if flinchingMove? && KIFER::BatchE.no_flinch_hit?(user)
    return ret
  end

  alias kifer_e_pbFlinchChance pbFlinchChance unless method_defined?(:kifer_e_pbFlinchChance)
  def pbFlinchChance(user, target)
    return 0 if KIFER::BatchE.no_flinch_hit?(user)
    return kifer_e_pbFlinchChance(user, target)
  end

  #-----------------------------------------------------------------------------
  # Ancient Idol – attacks with Defense / Sp. Def
  #-----------------------------------------------------------------------------
  alias kifer_e_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_e_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    if KIFER.on_field?(@battle, :ANCIENTIDOL) && user.hasActiveAbility?(:ANCIENTIDOL)
      return user.spdef, user.stages[:SPECIAL_DEFENSE] + 6 if specialMove?
      return user.defense, user.stages[:DEFENSE] + 6
    end
    return kifer_e_pbGetAttackStats(user, target)
  end

  #-----------------------------------------------------------------------------
  # Power Fists – punching moves hit Sp. Def
  #-----------------------------------------------------------------------------
  alias kifer_e_pbGetDefenseStats pbGetDefenseStats unless method_defined?(:kifer_e_pbGetDefenseStats)
  def pbGetDefenseStats(user, target)
    if KIFER.punch_move?(self) && user.hasActiveAbility?(:POWERFISTS)
      return KIFER::BatchA.def_stat(self, :SPECIAL_DEFENSE) { kifer_e_pbGetDefenseStats(user, target) }
    end
    return kifer_e_pbGetDefenseStats(user, target)
  end

  #-----------------------------------------------------------------------------
  # Phantom Pain – Ghost moves hit Normal types for 1x
  #-----------------------------------------------------------------------------
  alias kifer_e_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_e_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_e_pbCalcTypeModSingle(moveType, defType, user, target)
    if moveType == :GHOST && defType == :NORMAL && user &&
       Effectiveness.ineffective_type?(moveType, defType) && user.hasActiveAbility?(:PHANTOMPAIN)
      ret = Effectiveness::NORMAL_EFFECTIVE_ONE
    end
    return ret
  end
end

#-------------------------------------------------------------------------------
# Propeller Tail – its moves can't be redirected (Follow Me, Rage Powder,
# Spotlight, Lightning Rod, Storm Drain)
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_e_pbChangeTargets pbChangeTargets unless method_defined?(:kifer_e_pbChangeTargets)
  def pbChangeTargets(move, user, targets)
    return targets if user && user.hasActiveAbility?(:PROPELLERTAIL)
    return kifer_e_pbChangeTargets(move, user, targets)
  end
end

BattleHandlers::SpeedCalcAbility.add(:PROPELLERTAIL,
  proc { |ability, battler, mult|
    next mult * 1.5 if [:Rain, :HeavyRain].include?(battler.battle.pbWeather)
  }
)

#-------------------------------------------------------------------------------
# Damage boosts
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:POWERFISTS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER.punch_move?(move)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:GIANTWINGS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER::BatchE::AIR_MOVES.include?(move.id)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:DREAMCATCHER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    asleep = false
    user.battle.eachBattler { |b| asleep = true if b.status == :SLEEP }   # not Comatose
    mults[:base_damage_multiplier] *= 2 if asleep
  }
)

BattleHandlers::DamageCalcUserAbility.add(:TRANSISTOR,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if type == :ELECTRIC
  }
)

BattleHandlers::DamageCalcUserAbility.add(:DRAGONSMAW,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if type == :DRAGON
  }
)

BattleHandlers::DamageCalcUserAbility.add(:FAEHUNTER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if target.pbHasType?(:FAIRY)
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:FAEHUNTER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.5 if user.pbHasType?(:FAIRY)
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:PERMAFROST,
  proc { |ability, user, target, move, mults, baseDmg, type|
    if Effectiveness.super_effective?(move.pbCalcTypeMod(type, user, target))
      mults[:final_damage_multiplier] *= 0.65
    end
  }
)

# Readied Action – its turn count is 1 (or 0) until its first turn ends
BattleHandlers::DamageCalcUserAbility.add(:READIEDACTION,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 2 if move.physicalMove? && user.turnCount <= 1
  }
)

#-------------------------------------------------------------------------------
# Lullaby – Sing's base accuracy is 90 (stages still count)
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcUserAbility.add(:LULLABY,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 90 if move.id == :SING && mods[:base_accuracy] > 0 && mods[:base_accuracy] < 90
  }
)

#-------------------------------------------------------------------------------
# Pyromancy on Fire Fang (burn x5, flinch unchanged) and Tri Attack (the burn
# share of its roll x5; the chance above already counts it)
#-------------------------------------------------------------------------------
class PokeBattle_Move_00B
  alias kifer_e_00B_pbAdditionalEffect pbAdditionalEffect unless method_defined?(:kifer_e_00B_pbAdditionalEffect)
  def pbAdditionalEffect(user, target)
    return kifer_e_00B_pbAdditionalEffect(user, target) if !user.hasActiveAbility?(:PYROMANCY)
    return if target.damageState.substitute
    chance = pbAdditionalEffectChance(user, target, 10)
    return if chance == 0
    if @battle.pbRandom(100) < [chance * 5, 100].min
      target.pbBurn(user) if target.pbCanBurn?(user, false, self)
    end
    target.pbFlinch(user) if @battle.pbRandom(100) < chance
  end
end

class PokeBattle_Move_017
  alias kifer_e_017_pbAdditionalEffect pbAdditionalEffect unless method_defined?(:kifer_e_017_pbAdditionalEffect)
  def pbAdditionalEffect(user, target)
    return kifer_e_017_pbAdditionalEffect(user, target) if !user.hasActiveAbility?(:PYROMANCY)
    return if target.damageState.substitute
    case @battle.pbRandom(7)
    when 0..4 then target.pbBurn(user) if target.pbCanBurn?(user, false, self)
    when 5    then target.pbFreeze if target.pbCanFreeze?(user, false, self)
    else           target.pbParalyze(user) if target.pbCanParalyze?(user, false, self)
    end
  end
end

#-------------------------------------------------------------------------------
# Haunted Spirit – a KO by an attack curses the attacker
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:HAUNTEDSPIRIT,
  proc { |ability, user, target, move, battle|
    next if !target.fainted? || user.fainted?
    next if user.pbHasType?(:GHOST) || user.effects[PBEffects::Curse]
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    user.effects[PBEffects::Curse] = true
    battle.pbDisplay(_INTL("{1} laid a curse on {2}!", target.pbThis, user.pbThis(true)))
    battle.pbHideAbilitySplash(target)
  }
)

#-------------------------------------------------------------------------------
# Ill Will – the move that KOs it loses all its PP
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:ILLWILL,
  proc { |ability, user, target, move, battle|
    next if !target.fainted? || !move.damagingMove?
    m = nil
    user.eachMove { |um| m = um if um.id == move.id }
    m ||= move
    next if m.pp <= 0
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    user.pbSetPP(m, 0)
    battle.pbDisplay(_INTL("{1}'s {2} lost all of its PP!", user.pbThis, m.name))
    battle.pbHideAbilitySplash(target)
  }
)

#-------------------------------------------------------------------------------
# Loose Quills / Scrapyard / Toxic Debris – hit by a contact move: a hazard
# layer on its foes' side (also when an ally hits it), once per hit, even
# when the hit knocks it out. Protective Pads on the attacker stop it.
#-------------------------------------------------------------------------------
module KIFER
  module BatchE
    def self.hazard_on_hit(ability, user, target, move, battle, effect, max, msg)
      return if !move.pbContactMove?(user) || !user.affectedByContactEffect?
      side = target.pbOpposingSide
      return if side.effects[effect] >= max
      battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
      side.effects[effect] += 1
      battle.pbDisplay(_INTL(msg, target.pbOpposingTeam(true)))
      battle.pbHideAbilitySplash(target)
    end
  end
end

BattleHandlers::TargetAbilityOnHit.add(:LOOSEQUILLS,
  proc { |ability, user, target, move, battle|
    KIFER::BatchE.hazard_on_hit(ability, user, target, move, battle, PBEffects::Spikes, 3,
                                  "Spikes were scattered all around {1}'s feet!")
  }
)

BattleHandlers::TargetAbilityOnHit.copy(:LOOSEQUILLS, :SCRAPYARD)

BattleHandlers::TargetAbilityOnHit.add(:TOXICDEBRIS,
  proc { |ability, user, target, move, battle|
    KIFER::BatchE.hazard_on_hit(ability, user, target, move, battle, PBEffects::ToxicSpikes, 2,
                                  "Poison spikes were scattered all around {1}'s feet!")
  }
)

#-------------------------------------------------------------------------------
# Shocking Jaws – biting moves: 50% chance to paralyze
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:SHOCKINGJAWS,
  proc { |ability, user, target, move, battle|
    next if target.fainted?
    next if !KIFER.bite_move?(move)
    next if battle.pbRandom(100) >= 50
    next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
    next if !target.pbCanParalyze?(user, false)
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    target.pbParalyze(user)
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Jaws of Carnage – a KO heals 1/2 (biting move) or 1/4 of its max HP
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:JAWSOFCARNAGE,
  proc { |ability, user, targets, move, battle|
    next if user.fainted? || user.hp >= user.totalhp
    next unless targets.any? { |b| b.damageState.fainted }
    amt = KIFER.bite_move?(move) ? user.totalhp / 2 : user.totalhp / 4
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    user.pbRecoverHP([amt, 1].max)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", user.pbThis))
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Web Spinner – on entry: Speed -2 to the foes next to it (String Shot)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:WEBSPINNER,
  proc { |ability, battler, battle|
    name = KIFER.ability_name(ability)
    battle.pbShowAbilitySplash(battler, false, true, name)
    battle.eachOtherSideBattler(battler.index) do |b|
      next if !b.near?(battler)
      if b.effects[PBEffects::Substitute] > 0
        battle.pbDisplay(_INTL("{1} is protected by its substitute!", b.pbThis))
        next
      end
      b.pbLowerStatStageByAbility(:SPEED, 2, battler, false, false, name)
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Gravity Well – on entry: Gravity for 5 turns (as the move does)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:GRAVITYWELL,
  proc { |ability, battler, battle|
    KIFER::BatchA.gravity(battler, ability, 5)
  }
)

#-------------------------------------------------------------------------------
# Doombringer – on entry: Doom Desire on the foe in front of it (another foe
# if that spot already has one coming; nothing if every spot has one)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:DOOMBRINGER,
  proc { |ability, battler, battle|
    next if !GameData::Move.exists?(:DOOMDESIRE)
    foes = []
    front = battler.pbDirectOpposing(true)
    foes << front if front && !front.fainted? && front.opposes?(battler)
    battle.eachOtherSideBattler(battler.index) { |b| foes << b if !foes.include?(b) }
    target = foes.find do |b|
      pos = battle.positions[b.index]
      pos && pos.effects[PBEffects::FutureSightCounter] == 0
    end
    next if !target
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    effects = battle.positions[target.index].effects
    effects[PBEffects::FutureSightCounter]        = 3
    effects[PBEffects::FutureSightMove]           = :DOOMDESIRE
    effects[PBEffects::FutureSightUserIndex]      = battler.index
    effects[PBEffects::FutureSightUserPartyIndex] = battler.pokemonIndex
    battle.pbDisplay(_INTL("{1} chose Doom Desire as its destiny!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Monster Mash – on entry: Trick-or-Treat (adds the Ghost type) on the foe in
# front of it, until that foe switches out
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:MONSTERMASH,
  proc { |ability, battler, battle|
    target = battler.pbDirectOpposing(true)
    next if !target || target.fainted? || !target.opposes?(battler)
    KIFER::BatchH.add_type(ability, battler, battle, :GHOST, target)
  }
)

#-------------------------------------------------------------------------------
# Toxic Spill – end of each turn, while one is on the field: every non-Poison
# Pokemon loses 1/8 of its max HP (Poison Heal: heals 1/8 instead). Runs once
# a turn however many Pokemon have it.
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:TOXICSPILL,
  proc { |ability, battler, battle|
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("{1} is spilling toxic waste!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

BattleHandlers::EOREffectAbility.add(:TOXICSPILL,
  proc { |ability, battler, battle|
    next if battle.instance_variable_get(:@kifer_e_toxicspill_turn) == battle.turnCount
    battle.instance_variable_set(:@kifer_e_toxicspill_turn, battle.turnCount)
    name = KIFER.ability_name(ability)
    battle.eachBattler do |b|
      next if b.fainted? || b.pbHasType?(:POISON)
      if b.hasActiveAbility?(:POISONHEAL)
        next if !b.canHeal?
        battle.pbShowAbilitySplash(b)
        b.pbRecoverHP(b.totalhp / 8)
        battle.pbDisplay(_INTL("{1}'s HP was restored.", b.pbThis))
        battle.pbHideAbilitySplash(b)
        next
      end
      next if !b.takesIndirectDamage?
      next if b.hasActiveAbility?(:TOXICBOOST)   # ER skips Toxic Boost too
      battle.pbShowAbilitySplash(battler, false, true, name)
      oldHP = b.hp
      b.pbReduceHP([b.totalhp / 8, 1].max)
      battle.pbDisplay(_INTL("{1} is hurt by the toxic waste!", b.pbThis))
      battle.pbHideAbilitySplash(battler)
      b.pbItemHPHealCheck
      b.pbAbilitiesOnDamageTaken(oldHP)
      b.pbFaint if b.fainted?
    end
  }
)

#-------------------------------------------------------------------------------
# Future attacks (Doombringer's Doom Desire, Future Sight) hit at the end of the
# round with their own priority. The user's choice may have none (it came in
# this round, or Doombringer's user is out of battle), which PIF's Dazzling,
# Queenly Majesty, Psychic Terrain and Quick Guard checks can't handle.
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_e_pbUseMoveSimple pbUseMoveSimple unless method_defined?(:kifer_e_pbUseMoveSimple)
  def pbUseMoveSimple(moveID, target = -1, idxMove = -1, specialUsage = true)
    if !@battle.futureSight || !GameData::Move.exists?(moveID)
      return kifer_e_pbUseMoveSimple(moveID, target, idxMove, specialUsage)
    end
    KIFER.with_priority(self, GameData::Move.get(moveID).priority) do
      kifer_e_pbUseMoveSimple(moveID, target, idxMove, specialUsage)
    end
  end
end
