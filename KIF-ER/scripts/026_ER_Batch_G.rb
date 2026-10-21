#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch G)
#   Mechanics follow Elite Redux 2.65 (its C source and in-game texts). Where
#   the 2.65 text describes a newer version than the source, the text is used.
#
#   Violent Rush     – on its first turn: Speed x1.5 and Attack x1.2
#   Coward           – Protect on entry, once per battle
#   Flaming Soul     – Fire moves +1 priority at full HP
#   Vengeance        – Ghost moves x1.2, x1.5 at 1/3 HP or less
#   Inflatable       – hit by Fire or Flying: Defense and Sp. Def +1
#   Immolate         – Normal moves become Fire. Fire-type user: its Fire moves
#                      have a 10% burn chance. Otherwise: Fire moves get STAB
#   Electrocytes     – Electric moves x1.25
#   Prism Scales     – special attacks hit it for x0.7
#   Majestic Bird    – Sp. Atk x1.5
#   Wind Rider       – wind moves don't hurt it and raise its higher attacking
#                      stat; entering under Tailwind raises it too (also
#                      its own Air Blower's Tailwind, whatever the order),
#                      and so does its side's Tailwind move (its own or a
#                      partner's)
#   Equinox          – every attack uses its higher attacking stat (after
#                      stat stages)
#   Moon Spirit      – Fairy and Dark moves get STAB; Moonlight heals 75%
#   Egoist           – when a foe's stat rises, its own stat rises as much
#   Metallic         – on entry: adds the Steel type (stays until it switches;
#                      one added-type slot as in ER, see 022's Grounded)
#   Artillery        – Mega Launcher moves can't miss and aimed ones hit both
#                      foes
#   Fortitude        – hit: Sp. Def +1, or maxed by a critical hit
#   Mirror Armor     – stat drops from others bounce back to them
#   Raw Wood         – Grass moves x1.2; Grass moves hit it for x0.5
#   Sun's Bounty     – in sun: cures its status at the end of the turn; Harvest
#                      (50% a turn, 100% in sun)
#   Adrenaline Rush  – knocking out a foe: Speed +1
#   Chrome Coat      – special attacks hit it for x0.6; Speed x0.9; weight x3
#   Flourish         – Grass moves x1.5 in Grassy Terrain
#   Heaven Asunder   – Spacial Rend always crits; other moves +1 crit stage
#   Subdue           – stat drops from its moves are doubled
#   Well Baked Body  – Fire moves don't hurt it and raise its Defense by 2
#
#   Left out at first, now coded in 030-035 (fog, frostbite/bleeding,
#   fear, Toxic Terrain/enrage, one-offs).
#===============================================================================
KIFER.er_code(:VIOLENTRUSH, :COWARD, :FLAMINGSOUL, :VENGEANCE, :INFLATABLE,
                :IMMOLATE, :ELECTROCYTES, :PRISMSCALES, :MAJESTICBIRD, :WINDRIDER,
                :EQUINOX, :MOONSPIRIT, :EGOIST, :METALLIC, :ARTILLERY, :FORTITUDE,
                :MIRRORARMOR, :RAWWOOD, :SUNSBOUNTY, :ADRENALINERUSH, :CHROMECOAT,
                :FLOURISH, :HEAVENASUNDER, :SUBDUE, :WELLBAKEDBODY)

module KIFER
  module BatchG
    # Elite Redux's Mega Launcher moves (Artillery). Moves PIF lacks never match.
    ARTILLERY_MOVES = KIFER::BatchF::MEGA_LAUNCHER_MOVES

    # Wind moves (Wind Rider). ER has no wind flag; this is the usual wind list.
    WIND_MOVES = [
      :AEROBLAST, :AIRCUTTER, :BLEAKWINDSTORM, :BLIZZARD, :FAIRYWIND, :GUST,
      :HEATWAVE, :HURRICANE, :ICYWIND, :PETALBLIZZARD, :SANDSEARSTORM,
      :SANDSTORM, :SPRINGTIDESTORM, :TAILWIND, :TWISTER, :WHIRLWIND,
      :WILDBOLTSTORM
    ].freeze

    # Artillery: an aimed move hits both foes instead
    ARTILLERY_TARGETS = { :NearOther => :AllNearFoes, :Other => :AllFoes }

    @egoist     = false   # true while Egoist copies a boost (not copied again)
    @reflecting = false   # true while Mirror Armor bounces a drop back
    @ability_drop = 0     # >0 while an ability lowers a stat (not Subdue)

    def self.first_turn?(battler)
      return KIFER::BatchC.first_turn?(battler)
    end

    # Egoist: a foe's stat rose by delta stages
    def self.egoist_copy(battler, stat, delta)
      return if delta <= 0 || @egoist
      battle = battler.battle
      battle.eachOtherSideBattler(battler.index) do |b|
        next if b.fainted? || !b.hasActiveAbility?(:EGOIST)
        next if !b.pbCanRaiseStatStage?(stat, b)
        @egoist = true
        begin
          b.pbRaiseStatStageByAbility(stat, delta, b, true, KIFER.ability_name(:EGOIST))
        ensure
          @egoist = false
        end
      end
    end

    # Mirror Armor works against this drop
    def self.mirror_armor?(target, user, ignoreContrary)
      return false if @reflecting || ignoreContrary
      return false if !user || user.index == target.index || user.fainted?
      return false if target.battle.moldBreaker
      return target.hasActiveAbility?(:MIRRORARMOR)
    end

    # Bounces the drop back to user (its immunities don't stop it)
    def self.mirror_armor(target, stat, increment, user)
      battle = target.battle
      battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(:MIRRORARMOR))
      @reflecting = true
      begin
        if user.statStageAtMin?(stat)
          battle.pbDisplay(_INTL("{1}'s {2} won't go any lower!", user.pbThis, GameData::Stat.get(stat).name))
        else
          user.pbLowerStatStage(stat, increment, target)
        end
      ensure
        @reflecting = false
      end
      battle.pbHideAbilitySplash(target)
    end

    # Subdue: drops from the user's moves on another battler are doubled
    def self.subdue(target, increment, user, ignoreContrary)
      return increment if ignoreContrary || @reflecting || @ability_drop > 0
      return increment if !user || user.index == target.index
      return increment unless user.hasActiveAbility?(:SUBDUE)
      return increment * 2
    end

    def self.ability_drop
      @ability_drop += 1
      begin
        return yield
      ensure
        @ability_drop -= 1
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Violent Rush – first turn after it comes in (the turns Fake Out works):
# Speed x1.5 and Attack x1.2
#-------------------------------------------------------------------------------
BattleHandlers::SpeedCalcAbility.add(:VIOLENTRUSH,
  proc { |ability, battler, mult|
    next KIFER::BatchG.first_turn?(battler) ? mult * 1.5 : mult
  }
)

BattleHandlers::DamageCalcUserAbility.add(:VIOLENTRUSH,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if !KIFER::BatchG.first_turn?(user)
    mults[:attack_multiplier] *= 1.2 if move.physicalMove?(type)
  }
)

#-------------------------------------------------------------------------------
# Coward – Protect on entry, once per battle for each Pokémon
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:COWARD,
  proc { |ability, battler, battle|
    used = battle.instance_variable_get(:@kifer_g_coward)
    used = battle.instance_variable_set(:@kifer_g_coward, {}) if !used
    key = [battler.idxOwnSide, battler.pokemonIndex]
    next if used[key]
    used[key] = true
    battler.effects[PBEffects::Protect] = true
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("{1} protected itself!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Flaming Soul – Fire moves +1 priority at full HP (like PIF's Gale Wings)
#-------------------------------------------------------------------------------
BattleHandlers::PriorityChangeAbility.add(:FLAMINGSOUL,
  proc { |ability, battler, move, pri|
    next pri + 1 if battler.hp == battler.totalhp && move.type == :FIRE
    next pri
  }
)

#-------------------------------------------------------------------------------
# Vengeance – Ghost moves x1.2, x1.5 at 1/3 HP or less
# Electrocytes – Electric moves x1.25
# Majestic Bird – Sp. Atk x1.5
# (ER changes the attacking stat for these)
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:VENGEANCE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :GHOST
    mults[:attack_multiplier] *= KIFER::BatchA.pinch_boost(user)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:ELECTROCYTES,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 1.25 if type == :ELECTRIC
  }
)

BattleHandlers::DamageCalcUserAbility.add(:MAJESTICBIRD,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 1.5 if move.specialMove?(type)
  }
)

#-------------------------------------------------------------------------------
# Inflatable – hit by a Fire or Flying move: Defense and Sp. Def +1 (each hit)
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:INFLATABLE,
  proc { |ability, user, target, move, battle|
    next if target.fainted?
    next unless [:FIRE, :FLYING].include?(move.calcType)
    stats = [:DEFENSE, :SPECIAL_DEFENSE].select { |s| target.pbCanRaiseStatStage?(s, target) }
    next if stats.empty?
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    stats.each { |s| target.pbRaiseStatStage(s, 1, target) }
    battle.pbHideAbilitySplash(target)
  }
)

#-------------------------------------------------------------------------------
# Immolate – Normal moves become Fire. A Fire-type user's Fire moves have a 10%
# chance to burn; any other user gets STAB on Fire moves.
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.add(:IMMOLATE,
  proc { |ability, user, move, type|
    next type if type != :NORMAL
    next :FIRE
  }
)

BattleHandlers::DamageCalcUserAbility.add(:IMMOLATE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :FIRE || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

BattleHandlers::UserAbilityOnHit.add(:IMMOLATE,
  proc { |ability, user, target, move, battle|
    next if move.calcType != :FIRE || !user.pbHasType?(:FIRE)
    next if target.fainted? || battle.pbRandom(100) >= 10
    next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
    next if !target.pbCanBurn?(user, false)
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    target.pbBurn(user)
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Prism Scales – special attacks hit it for x0.7
# Chrome Coat – special attacks hit it for x0.6; Speed x0.9; weight x3
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:PRISMSCALES,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.7 if move.specialMove?(type)
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:CHROMECOAT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.6 if move.specialMove?(type)
  }
)

BattleHandlers::SpeedCalcAbility.add(:CHROMECOAT,
  proc { |ability, battler, mult|
    next mult * 0.9
  }
)

BattleHandlers::WeightCalcAbility.add(:CHROMECOAT,
  proc { |ability, battler, w|
    next w * 3
  }
)

#-------------------------------------------------------------------------------
# Wind Rider – wind moves from others don't hurt it and raise its higher
# attacking stat; coming in under its side's Tailwind raises it too
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:WINDRIDER,
  proc { |ability, user, target, move, type, battle|
    next false if user.index == target.index
    next false if !KIFER::BatchG::WIND_MOVES.include?(move.id)
    stat = KIFER::BatchF.highest_attack_stat(target)
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    if target.pbCanRaiseStatStage?(stat, target)
      target.pbRaiseStatStage(stat, 1, target)
    else
      battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
    end
    battle.pbHideAbilitySplash(target)
    next true
  }
)

BattleHandlers::AbilityOnSwitchIn.add(:WINDRIDER,
  proc { |ability, battler, battle|
    next if battler.pbOwnSide.effects[PBEffects::Tailwind] <= 0
    KIFER::BatchG.wind_rider_boost(battler)
  }
)

module KIFER
  module BatchG
    def self.wind_rider_boost(battler)
      stat = KIFER::BatchF.highest_attack_stat(battler)
      return if !battler.pbCanRaiseStatStage?(stat, battler)
      battler.pbRaiseStatStageByAbility(stat, 1, battler, true, KIFER.ability_name(:WINDRIDER))
    end

    # Its Wind Rider ran before this ability on the same entry (main ability
    # first, then innates in order), so it didn't see the Tailwind yet
    def self.wind_rider_before?(battler, ability)
      return false if !battler.hasActiveAbility?(:WINDRIDER)
      order = [battler.ability_id] + (battler.respond_to?(:active_innates) ? battler.active_innates : [])
      wr = order.index(:WINDRIDER)
      me = order.index(KIFER.ability_id(ability))
      return wr && me && wr < me
    end
  end
end

# Air Blower's Tailwind (020) also counts for its own Wind Rider when the
# Wind Rider comes first (e.g. Wind Rider main ability, Air Blower innate)
if BattleHandlers::AbilityOnSwitchIn[:AIRBLOWER]
  kifer_g_airblower = BattleHandlers::AbilityOnSwitchIn[:AIRBLOWER]
  BattleHandlers::AbilityOnSwitchIn.add(:AIRBLOWER,
    proc { |ability, battler, battle|
      had = battler.pbOwnSide.effects[PBEffects::Tailwind] > 0
      kifer_g_airblower.call(ability, battler, battle)
      next if had || battler.pbOwnSide.effects[PBEffects::Tailwind] <= 0
      next if !KIFER::BatchG.wind_rider_before?(battler, ability)
      KIFER::BatchG.wind_rider_boost(battler)
    }
  )
end

# Tailwind used by it or a partner raises every Wind Rider on that side
class PokeBattle_Move_05B < PokeBattle_Move
  alias kifer_g_pbEffectGeneral pbEffectGeneral unless method_defined?(:kifer_g_pbEffectGeneral)
  def pbEffectGeneral(user)
    had = user.pbOwnSide.effects[PBEffects::Tailwind] > 0
    kifer_g_pbEffectGeneral(user)
    return if had || user.pbOwnSide.effects[PBEffects::Tailwind] <= 0
    @battle.battlers.each do |b|
      next if !b || b.fainted? || b.opposes?(user) || !b.hasActiveAbility?(:WINDRIDER)
      KIFER::BatchG.wind_rider_boost(b)
    end
  end
end

#-------------------------------------------------------------------------------
# Moon Spirit – Fairy and Dark moves get STAB (not twice); Moonlight heals 75%
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:MOONSPIRIT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if (type != :FAIRY && type != :DARK) || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

if defined?(PokeBattle_Move_0D8)
  class PokeBattle_Move_0D8
    alias kifer_g_pbHealAmount pbHealAmount unless method_defined?(:kifer_g_pbHealAmount)
    def pbHealAmount(user)
      if @id == :MOONLIGHT && user.hasActiveAbility?(:MOONSPIRIT)
        return (user.totalhp * 3 / 4.0).round
      end
      return kifer_g_pbHealAmount(user)
    end
  end
end

#-------------------------------------------------------------------------------
# Metallic – on entry: adds the Steel type (like Trick-or-Treat adds Ghost).
# It stays until it switches out, even if the ability is lost.
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:METALLIC,
  proc { |ability, battler, battle|
    KIFER::BatchH.add_type(ability, battler, battle, :STEEL)
  }
)

#-------------------------------------------------------------------------------
# Artillery – Mega Launcher moves can't miss, and ones aimed at one Pokémon
# hit both foes
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcUserAbility.add(:ARTILLERY,
  proc { |ability, mods, user, target, move, type|
    next if !KIFER::BatchG::ARTILLERY_MOVES.include?(move.id)
    mods[:base_accuracy] = 0   # never misses (as Sighting System / Deadeye)
  }
)

class PokeBattle_Move
  alias kifer_g_pbTarget pbTarget unless method_defined?(:kifer_g_pbTarget)
  def pbTarget(user)
    t = kifer_g_pbTarget(user)
    if t && user.is_a?(PokeBattle_Battler) && damagingMove? && KIFER::BatchG::ARTILLERY_MOVES.include?(@id)   # not Heal Pulse
      to = KIFER::BatchG::ARTILLERY_TARGETS[t.id]
      return GameData::Target.get(to) if to && user.hasActiveAbility?(:ARTILLERY)
    end
    return t
  end

  #-----------------------------------------------------------------------------
  # Equinox – attacks use Attack or Sp. Atk, whichever is higher after stat
  # stages (with that stat's stages). As in ER it comes before every other
  # attacking-stat ability (Speed Force, Ancient Idol...); Foul Play and Body
  # Press keep their own stat.
  #-----------------------------------------------------------------------------
  alias kifer_g_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_g_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    if KIFER.on_field?(@battle, :EQUINOX) && user.hasActiveAbility?(:EQUINOX)
      # the higher of Attack and Sp. Atk after stat stages (Attack on a tie)
      return user.attack, user.stages[:ATTACK] + 6 if KIFER::BatchD.highest_stat(user, [:ATTACK, :SPECIAL_ATTACK]) == :ATTACK
      return user.spatk, user.stages[:SPECIAL_ATTACK] + 6
    end
    return kifer_g_pbGetAttackStats(user, target)
  end

  #-----------------------------------------------------------------------------
  # Heaven Asunder – Spacial Rend always crits (Battle Armor and Lucky Chant
  # still stop it)
  #-----------------------------------------------------------------------------
  alias kifer_g_pbCritialOverride pbCritialOverride unless method_defined?(:kifer_g_pbCritialOverride)
  def pbCritialOverride(user, target)
    ret = kifer_g_pbCritialOverride(user, target)
    return 1 if ret == 0 && @id == :SPACIALREND && user.hasActiveAbility?(:HEAVENASUNDER)
    return ret
  end
end

BattleHandlers::CriticalCalcUserAbility.add(:HEAVENASUNDER,
  proc { |ability, user, target, c|
    next c + 1
  }
)

#-------------------------------------------------------------------------------
# Fortitude – hit by an attack: Sp. Def +1, or maxed by a critical hit
# (each hit of a multi-hit move)
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:FORTITUDE,
  proc { |ability, user, target, move, battle|
    next if !target.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, target)
    name = KIFER.ability_name(ability)
    if target.damageState.critical
      battle.pbShowAbilitySplash(target, false, true, name)
      target.stages[:SPECIAL_DEFENSE] = 6
      battle.pbCommonAnimation("StatUp", target)
      battle.pbDisplay(_INTL("{1} maxed its {2}!", target.pbThis, GameData::Stat.get(:SPECIAL_DEFENSE).name))
      battle.pbHideAbilitySplash(target)
    else
      target.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, target, true, name)
    end
  }
)

#-------------------------------------------------------------------------------
# Raw Wood – Grass moves x1.2; Grass moves hit it for x0.5
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:RAWWOOD,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 1.2 if type == :GRASS
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:RAWWOOD,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 0.5 if type == :GRASS
  }
)

#-------------------------------------------------------------------------------
# Sun's Bounty – in sun: cures its status at the end of the turn. Harvest:
# gets back a used Berry at the end of the turn, 50% (100% in sun).
#-------------------------------------------------------------------------------
BattleHandlers::EORHealingAbility.add(:SUNSBOUNTY,
  proc { |ability, battler, battle|
    next if battler.status == :NONE
    next if ![:Sun, :HarshSun].include?(battle.pbWeather)
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.pbCureStatus(true)
    battle.pbHideAbilitySplash(battler)
  }
)

BattleHandlers::EORGainItemAbility.add(:SUNSBOUNTY,
  proc { |ability, battler, battle|
    next if battler.item
    next if !battler.recycleItem || !GameData::Item.get(battler.recycleItem).is_berry?
    if ![:Sun, :HarshSun].include?(battle.pbWeather)
      next unless battle.pbRandom(100) < 50
    end
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.item = battler.recycleItem
    battler.setRecycleItem(nil)
    battler.setInitialItem(battler.item) if !battler.initialItem
    battle.pbDisplay(_INTL("{1} harvested one {2}!", battler.pbThis, battler.itemName))
    battle.pbHideAbilitySplash(battler)
    battler.pbHeldItemTriggerCheck
  }
)

#-------------------------------------------------------------------------------
# Adrenaline Rush – knocking out foes with a move: Speed +1 each (like Moxie)
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:ADRENALINERUSH,
  proc { |ability, user, targets, move, battle|
    next if battle.pbAllFainted?(user.idxOpposingSide)
    numFainted = targets.count { |b| b.damageState.fainted }
    next if numFainted == 0 || !user.pbCanRaiseStatStage?(:SPEED, user)
    user.pbRaiseStatStageByAbility(:SPEED, numFainted, user, true, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Flourish – Grass moves x1.5 in Grassy Terrain
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:FLOURISH,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if type == :GRASS && user.battle.field.terrain == :Grassy
  }
)

#-------------------------------------------------------------------------------
# Well Baked Body – Fire moves don't hurt it and raise its Defense by 2
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:WELLBAKEDBODY,
  proc { |ability, user, target, move, type, battle|
    next pbBattleMoveImmunityStatAbility(user, target, move, type, :FIRE, :DEFENSE, 2, battle)
  }
)

#-------------------------------------------------------------------------------
# Stat stage changes
#   Egoist – when a foe's stat rises, its own stat rises as much (boosts from
#     Egoist itself aren't copied). Stat changes PIF sets directly (Anger
#     Point, Belly Drum) aren't seen.
#   Mirror Armor – a stat drop from another Pokémon (move or ability) bounces
#     back to it; the attacker's immunities don't stop it. Works at -6 too.
#     Mold Breaker ignores it.
#   Subdue – stat drops its moves cause on others are doubled (not its
#     abilities, not drops on itself)
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_g_pbRaiseStatStage pbRaiseStatStage unless method_defined?(:kifer_g_pbRaiseStatStage)
  def pbRaiseStatStage(stat, increment, user, showAnim = true, ignoreContrary = false)
    before = @stages[stat]
    ret = kifer_g_pbRaiseStatStage(stat, increment, user, showAnim, ignoreContrary)
    KIFER::BatchG.egoist_copy(self, stat, @stages[stat] - before)
    return ret
  end

  alias kifer_g_pbRaiseStatStageByCause pbRaiseStatStageByCause unless method_defined?(:kifer_g_pbRaiseStatStageByCause)
  def pbRaiseStatStageByCause(stat, increment, user, cause, showAnim = true, ignoreContrary = false)
    before = @stages[stat]
    ret = kifer_g_pbRaiseStatStageByCause(stat, increment, user, cause, showAnim, ignoreContrary)
    KIFER::BatchG.egoist_copy(self, stat, @stages[stat] - before)
    return ret
  end

  alias kifer_g_pbCanLowerStatStage? pbCanLowerStatStage? unless method_defined?(:kifer_g_pbCanLowerStatStage?)
  def pbCanLowerStatStage?(stat, user = nil, move = nil, showFailMsg = false, ignoreContrary = false)
    if statStageAtMin?(stat) && !hasActiveAbility?(:CONTRARY) &&
       KIFER::BatchG.mirror_armor?(self, user, ignoreContrary)
      old = @stages[stat]
      @stages[stat] = -5   # every other check still applies
      begin
        return kifer_g_pbCanLowerStatStage?(stat, user, move, showFailMsg, ignoreContrary)
      ensure
        @stages[stat] = old
      end
    end
    return kifer_g_pbCanLowerStatStage?(stat, user, move, showFailMsg, ignoreContrary)
  end

  alias kifer_g_pbLowerStatStage pbLowerStatStage unless method_defined?(:kifer_g_pbLowerStatStage)
  def pbLowerStatStage(stat, increment, user, showAnim = true, ignoreContrary = false)
    increment = KIFER::BatchG.subdue(self, increment, user, ignoreContrary)
    if KIFER::BatchG.mirror_armor?(self, user, ignoreContrary)
      KIFER::BatchG.mirror_armor(self, stat, increment, user)
      return false
    end
    return kifer_g_pbLowerStatStage(stat, increment, user, showAnim, ignoreContrary)
  end

  alias kifer_g_pbLowerStatStageByCause pbLowerStatStageByCause unless method_defined?(:kifer_g_pbLowerStatStageByCause)
  def pbLowerStatStageByCause(stat, increment, user, cause, showAnim = true, ignoreContrary = false)
    increment = KIFER::BatchG.subdue(self, increment, user, ignoreContrary)
    if KIFER::BatchG.mirror_armor?(self, user, ignoreContrary)
      KIFER::BatchG.mirror_armor(self, stat, increment, user)
      return false
    end
    return kifer_g_pbLowerStatStageByCause(stat, increment, user, cause, showAnim, ignoreContrary)
  end

  alias kifer_g_pbLowerStatStageByAbility pbLowerStatStageByAbility unless method_defined?(:kifer_g_pbLowerStatStageByAbility)
  def pbLowerStatStageByAbility(*args)
    return KIFER::BatchG.ability_drop { kifer_g_pbLowerStatStageByAbility(*args) }
  end

  alias kifer_g_pbLowerAttackStatStageIntimidate pbLowerAttackStatStageIntimidate unless method_defined?(:kifer_g_pbLowerAttackStatStageIntimidate)
  def pbLowerAttackStatStageIntimidate(user)
    return KIFER::BatchG.ability_drop { kifer_g_pbLowerAttackStatStageIntimidate(user) }
  end
end
