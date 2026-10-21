#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch D)
#   Mechanics follow Elite Redux 2.65 (its C source, its 2.65 move data and
#   in-game texts; where the public C source is older than 2.65, the 2.65
#   numbers are used).
#
#   Field Explorer   – field moves x1.5 (ER 2.65's "field based" moves)
#   Poison Absorb    – draws in Poison moves; they heal 1/4 of its max HP
#                      instead (its 1/8 heal each turn in Toxic Terrain is in
#                      033)
#   Guilt Trip       – fainting from an attack: attacker's Attack and Sp. Atk -2
#   Liquified        – contact moves x0.5 on it, Water moves x2 on it
#   Electric Burst   – Electric moves x1.35 (while above 1 HP); after hitting,
#                      10% of the damage dealt as recoil, never below 1 HP
#   Avenger          – moves x1.5 on the turn after a party Pokémon fainted
#                      (same timing as Retaliate)
#   Self Repair      – heals 1/16 at the end of each turn (not on the turn it
#                      came in) and cures its status when it switches out
#   Pastel Veil      – on entry: Safeguard for its side (5 turns) and cures
#                      its allies' poison. It and its allies can't be
#                      poisoned (Mold Breaker gets past it, then it cures
#                      its own poison at once)
#   Sea Guardian     – on entry in rain (any rain): its highest stat +1, on
#                      every entry
#   Guard Dog        – can't be forced out (Roar, Whirlwind, Dragon Tail,
#                      Circle Throw, Red Card); Intimidate raises its Attack and
#                      Scare its Sp. Atk instead of lowering them
#   Scavenger        – a KO with its attack heals 1/4 of its max HP
#   Cheap Tactics    – on entry: uses Scratch on a random foe
#   Loose Rocks      – hit by contact: Stealth Rock on the attacker's side
#   Rite of Spring   – in sun: Speed x1.5 and its higher attacking stat x1.5
#   Aftershock       – after hitting with an attack: Magnitude 4-7 (10, 30, 50
#                      or 70 power, Magnitude's own odds) on everyone next to it
#   Intoxicate       – Normal moves become Poison. A Poison-type user's Poison
#                      moves get a 10% chance to badly poison; any other user
#                      gets the same-type boost on Poison moves
#   Perish Body      – hit by contact: it and the attacker faint in 3 turns
#                      (not if the attacker already has a perish count)
#   Soothing Aroma   – on entry: cures the status of its whole party
#   Tipping Point    – each hit taken: Sp. Atk +1, a critical hit maxes it
#   Breakwater       – in rain: Speed x1.5; takes x0.7 damage before it has
#                      moved this turn (Swift Swim + ER's Stall)
#   Deadeye          – arrow and cannon (ball/bomb) moves never miss; its
#                      critical hits use the target's weaker defense
#   Monkey Business  – on entry: uses Tickle on a random foe
#   Screen Cleaner   – on entry: removes Reflect, Light Screen and Aurora Veil
#                      from both sides; it can use those moves while they are
#                      up (restarting them)
#   Thick Skin       – super-effective moves x0.65 on it
#
#   Moves an ability uses for it (Cheap Tactics, Monkey Business, Aftershock)
#   follow ER's "extra move" rules: once per turn, not while asleep or frozen,
#   no PP used.
#
# Left out at first, now coded in 030-035 (fog, frostbite/bleeding,
# fear, Toxic Terrain/enrage, one-offs).
#===============================================================================
KIFER.er_code(:FIELDEXPLORER, :POISONABSORB, :GUILTTRIP, :LIQUIFIED, :ELECTRICBURST,
                :AVENGER, :SELFREPAIR, :PASTELVEIL, :SEAGUARDIAN, :GUARDDOG, :SCAVENGER,
                :CHEAPTACTICS, :LOOSEROCKS, :RITEOFSPRING, :AFTERSHOCK, :INTOXICATE,
                :PERISHBODY, :SOOTHINGAROMA, :TIPPINGPOINT, :BREAKWATER, :DEADEYE,
                :MONKEYBUSINESS, :SCREENCLEANER, :THICKSKIN)

module KIFER
  module BatchD
    # ER 2.65's "field based" moves (Field Explorer)
    FIELD_MOVES = [
      :CUT, :FLY, :HEADBUTT, :SURF, :STRENGTH, :DIG, :WATERFALL, :FLASH,
      :HIDDENPOWER, :WHIRLPOOL, :SECRETPOWER, :DIVE, :ZENHEADBUTT, :ROCKCLIMB,
      :STEELROLLER, :ICESPINNER, :TRIPLEDIVE
    ].freeze

    # ER 2.65's arrow moves and "bullet" (cannon) moves (Deadeye). Moves PIF
    # doesn't have never match.
    DEADEYE_MOVES = [
      :SPIRITSHACKLE, :ARCHERSHOT, :FROSTBOLT, :SUPERSONICSHOT, :LIGHTNINGSTRIKE,
      :VOLTBOLT, :BRAMBLEBLAST, :CUPIDSHOT, :CLAYDART, :DIAMONDARROW, :VENOMBOLT,
      :BLAZINGARROW, :WEBSHOT, :DRAKEMISSILE, :HOMINGFLETCH, :DEVIOUSSHOT,
      :TRIPLEARROWS, :SPARKLINGBARRAGE, :BLITZARROW,
      :WATERGUN, :EGGBOMB, :SPIKECANNON, :BARRAGE, :SLUDGEBOMB, :OCTAZOOKA,
      :ZAPCANNON, :SHADOWBALL, :MISTBALL, :ICEBALL, :WEATHERBALL, :BULLETSEED,
      :MUDSHOT, :ROCKBLAST, :GYROBALL, :AURASPHERE, :SEEDBOMB, :FOCUSBLAST,
      :ENERGYBALL, :MUDBOMB, :FLASHCANNON, :ROCKWRECKER, :GUNKSHOT, :MAGNETBOMB,
      :ELECTROBALL, :ACIDSPRAY, :SEARINGSHOT, :POLLENPUFF, :ANCHORSHOT,
      :BEAKBLAST, :SNIPESHOT, :TARSHOT, :PYROBALL, :STEELBEAM, :SCALESHOT,
      :WYRMWIND, :SYRUPBOMB, :ELECTROSHOT, :POPMAYHEM, :PRISMBLAST
    ].freeze

    # Magnitude 4-7 with Magnitude's own odds, and their power (Aftershock)
    AFTERSHOCK_MAGNITUDES = [4, 5, 5, 6, 6, 6, 6, 7, 7, 7, 7, 7, 7]
    MAGNITUDE_POWER = { 4 => 10, 5 => 30, 6 => 50, 7 => 70 }

    # A stat with its stat stage applied (stages above max_stage don't count);
    # every batch uses this one
    def self.staged(battler, stat, max_stage = 6)
      raw = case stat
            when :ATTACK          then battler.attack
            when :DEFENSE         then battler.defense
            when :SPECIAL_ATTACK  then battler.spatk
            when :SPECIAL_DEFENSE then battler.spdef
            else                       battler.speed
            end
      s = [battler.stages[stat], max_stage].min + 6
      return raw * KIFER::STAGE_MUL[s] / KIFER::STAGE_DIV[s]
    end

    # Highest stat (ER order on ties: Atk, Def, SpAtk, SpDef, Speed)
    def self.highest_stat(battler, stats = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED])
      best = nil
      best_val = -1
      stats.each do |s|
        v = staged(battler, s)
        next if v <= best_val
        best = s
        best_val = v
      end
      return best
    end

    def self.sun?(battle)
      return [:Sun, :HarshSun].include?(battle.pbWeather)
    end

    def self.rain?(battle)
      return [:Rain, :HeavyRain].include?(battle.pbWeather)
    end

    # A random foe that can be hit (Cheap Tactics skips foes at 1 HP, as ER does)
    def self.random_foe(battler, skip_one_hp = false)
      foes = []
      battler.battle.eachOtherSideBattler(battler.index) do |b|
        next if b.fainted?
        next if skip_one_hp && b.hp == 1
        foes << b
      end
      return nil if foes.empty?
      return foes[battler.battle.pbRandom(foes.length)]
    end

    # ER's "extra move": the battler uses a move outside its turn. Once per
    # turn, not while asleep or frozen, no PP. Its own turn this round is kept.
    # once: false for the on-entry uses (Cheap Tactics, Monkey Business): they
    # can only fire once per entry, and battle-start entries share turnCount 0
    # with round 1
    def self.extra_used?(user)
      last = user.instance_variable_get(:@kifer_d_extra)
      return last && last[0] == user.battle.turnCount && last[1].equal?(user.pokemon)
    end

    def self.extra_move(user, move_id, target_index, power = nil, once: true)
      battle = user.battle
      return false if user.fainted? || [:SLEEP, :FROZEN].include?(user.status)
      return false unless GameData::Move.exists?(move_id)
      if once
        return false if extra_used?(user)
        user.instance_variable_set(:@kifer_d_extra, [battle.turnCount, user.pokemon])
      end
      move = PokeBattle_Move.from_pokemon_move(battle, Pokemon::Move.new(move_id))
      move.pp = -1
      if power
        if move_id == :MAGNITUDE
          mag = MAGNITUDE_POWER.key(power)
          move.define_singleton_method(:pbOnStartUse) do |_u, _t|
            @magnitudeDmg = power
            @battle.pbDisplay(_INTL("Magnitude {1}!", mag))
          end
        else
          move.define_singleton_method(:pbBaseDamage) { |_b, _u, _t| power }
        end
      end
      old_moved   = user.lastRoundMoved
      old_outrage = user.effects[PBEffects::Outrage]
      saved = [user.lastMoveUsed, user.lastMoveUsedType, battle.lastMoveUsed,
               battle.lastMoveUser, battle.moldBreaker, user.currentMove, user.lastMoveFailed]
      user.instance_variable_set(:@kifer_d_in_extra, true)
      begin
        KIFER.with_extra_move(user, move) do
          user.pbUseMove([:UseMove, -1, move, target_index], true)
        end
      ensure
        user.instance_variable_set(:@kifer_d_in_extra, false)
        user.lastRoundMoved = old_moved
        user.effects[PBEffects::Outrage] = old_outrage
        user.lastMoveUsed, user.lastMoveUsedType, battle.lastMoveUsed,
          battle.lastMoveUser, battle.moldBreaker = saved[0..4]
        user.instance_variable_set(:@currentMove, saved[5])
        user.lastMoveFailed = saved[6]   # Stomping Tantrum, Coil Up... see the real move's result
      end
      battle.pbJudge
      return true
    end
  end
end

class PokeBattle_Battler
  # An extra move doesn't lock a Choice item holder into it
  alias kifer_d_pbEndTurn pbEndTurn unless method_defined?(:kifer_d_pbEndTurn)
  def pbEndTurn(choice)
    return kifer_d_pbEndTurn(choice) if !KIFER.in_extra_move?(self)
    old = @effects[PBEffects::ChoiceBand]
    kifer_d_pbEndTurn(choice)
    @effects[PBEffects::ChoiceBand] = old
  end
end

#-------------------------------------------------------------------------------
# Field Explorer – field moves x1.5
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:FIELDEXPLORER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if KIFER::BatchD::FIELD_MOVES.include?(move.id)
  }
)

#-------------------------------------------------------------------------------
# Poison Absorb – Poison moves heal 1/4 instead, and are drawn to it
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:POISONABSORB,
  proc { |ability, user, target, move, type, battle|
    next pbBattleMoveImmunityHealAbility(user, target, move, type, :POISON, battle)
  }
)

class PokeBattle_Battler
  alias kifer_d_pbChangeTargets pbChangeTargets unless method_defined?(:kifer_d_pbChangeTargets)
  def pbChangeTargets(move, user, targets)
    targets = kifer_d_pbChangeTargets(move, user, targets)
    return targets if @battle.switching || move.cannotRedirect? || targets.length != 1
    return targets if move.calcType != :POISON || !@battle.pbCheckGlobalAbility(:POISONABSORB)
    target_data = move.pbTarget(user)
    return targets if !target_data.can_target_one_foe?
    t = targets[0]
    # Spotlight / Follow Me / Rage Powder come first
    return targets if t.effects[PBEffects::Spotlight] > 0 || t.effects[PBEffects::FollowMe] > 0
    return pbChangeTargetByAbility(:POISONABSORB, :POISON, move, user, targets,
                                   @battle.pbPriority(true), !target_data.can_choose_distant_target?)
  end
end

#-------------------------------------------------------------------------------
# Guilt Trip – fainting from an attack lowers the attacker's Attack and Sp. Atk
# by 2
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:GUILTTRIP,
  proc { |ability, user, target, move, battle|
    next if !user || !move || !target.fainted? || user.fainted? || user.index == target.index
    name = KIFER.ability_name(ability)
    battle.pbShowAbilitySplash(target, false, true, name)
    user.pbLowerStatStageByAbility(:ATTACK, 2, target, false, false, name)
    user.pbLowerStatStageByAbility(:SPECIAL_ATTACK, 2, target, false, false, name)
    battle.pbHideAbilitySplash(target)
  }
)

#-------------------------------------------------------------------------------
# Liquified – contact moves x0.5 on it, Water moves x2 on it
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:LIQUIFIED,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 0.5 if move.pbContactMove?(user)
    mults[:base_damage_multiplier] *= 2 if type == :WATER
  }
)

#-------------------------------------------------------------------------------
# Electric Burst – Electric moves x1.35; 10% of the damage dealt as recoil
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:ELECTRICBURST,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 1.35 if type == :ELECTRIC && user.hp > 1
  }
)

BattleHandlers::UserAbilityEndOfMove.add(:ELECTRICBURST,
  proc { |ability, user, targets, move, battle|
    next if user.fainted? || user.hp <= 1 || !move.damagingMove? || move.calcType != :ELECTRIC
    dealt = 0
    targets.each do |b|
      next if b.damageState.unaffected || b.damageState.substitute
      dealt += b.damageState.totalHPLost
    end
    next if dealt <= 0
    amt = [dealt / 10, 1].max
    amt = user.hp - 1 if amt >= user.hp
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    user.pbReduceHP(amt, false)
    battle.pbDisplay(_INTL("{1} is damaged by recoil!", user.pbThis))
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Avenger – moves x1.5 on the turn after a party Pokémon fainted
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:AVENGER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    lrf = user.pbOwnSide.effects[PBEffects::LastRoundFainted]
    mults[:base_damage_multiplier] *= 1.5 if lrf >= 0 && lrf == user.battle.turnCount - 1
  }
)

#-------------------------------------------------------------------------------
# Self Repair – heals 1/16 each turn; cures its status when it switches out
#-------------------------------------------------------------------------------
BattleHandlers::EORHealingAbility.add(:SELFREPAIR,
  proc { |ability, battler, battle|
    next if battler.turnCount == 0 || !battler.canHeal?
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.pbRecoverHP([battler.totalhp / 16, 1].max)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

BattleHandlers::AbilityOnSwitchOut.add(:SELFREPAIR,
  proc { |ability, battler, endOfBattle|
    PBDebug.log("[Ability triggered] #{battler.pbThis}'s #{KIFER.ability_name(ability)}")
    battler.status = :NONE
  }
)

#-------------------------------------------------------------------------------
# Pastel Veil – on entry: Safeguard for its side, and its allies' poison is
# cured. It and its allies can't be poisoned.
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:PASTELVEIL,
  proc { |ability, battler, battle|
    name = KIFER.ability_name(ability)
    if battler.pbOwnSide.effects[PBEffects::Safeguard] <= 0
      battle.pbShowAbilitySplash(battler, false, true, name)
      battler.pbOwnSide.effects[PBEffects::Safeguard] = 5
      battle.pbDisplay(_INTL("{1} became cloaked in a mystical veil!", battler.pbTeam))
      battle.pbHideAbilitySplash(battler)
    end
    sick = []
    battler.eachAlly { |b| sick << b if b.status == :POISON }
    next if sick.empty?
    battle.pbShowAbilitySplash(battler, false, true, name)
    sick.each do |b|
      b.pbCureStatus(false)
      battle.pbDisplay(_INTL("{1} was cured of its poisoning!", b.pbThis))
    end
    battle.pbHideAbilitySplash(battler)
  }
)

BattleHandlers::StatusImmunityAbility.add(:PASTELVEIL,
  proc { |ability, battler, status|
    next true if status == :POISON
  }
)

BattleHandlers::StatusImmunityAllyAbility.add(:PASTELVEIL,
  proc { |ability, battler, status|
    next true if status == :POISON
  }
)

# Poisoned anyway (Mold Breaker): cured at once, as Immunity does
BattleHandlers::StatusCureAbility.add(:PASTELVEIL,
  proc { |ability, battler|
    next if battler.status != :POISON
    battle = battler.battle
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.pbCureStatus(false)
    battle.pbDisplay(_INTL("{1} was cured of its poisoning!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Sea Guardian – on entry in rain: highest stat +1
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:SEAGUARDIAN,
  proc { |ability, battler, battle|
    next if !KIFER::BatchD.rain?(battle)
    stat = KIFER::BatchD.highest_stat(battler)
    next if !battler.pbCanRaiseStatStage?(stat, battler)
    battler.pbRaiseStatStageByAbility(stat, 1, battler, true, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Guard Dog – can't be forced out; Intimidate and Scare raise instead
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_d_pbLowerAttackStatStageIntimidate pbLowerAttackStatStageIntimidate unless method_defined?(:kifer_d_pbLowerAttackStatStageIntimidate)
  def pbLowerAttackStatStageIntimidate(user)
    if !fainted? && @effects[PBEffects::Substitute] == 0 && hasActiveAbility?(:GUARDDOG)
      return false if kifer_d_guard_dog_blocked?(user, :ATTACK)
      return false if !pbCanRaiseStatStage?(:ATTACK, self)
      return pbRaiseStatStageByAbility(:ATTACK, 1, self, true, KIFER.ability_name(:GUARDDOG))
    end
    return kifer_d_pbLowerAttackStatStageIntimidate(user)
  end

  # Scare (batch 1) lowers Sp. Atk through this method with its own name
  alias kifer_d_pbLowerStatStageByAbility pbLowerStatStageByAbility unless method_defined?(:kifer_d_pbLowerStatStageByAbility)
  def pbLowerStatStageByAbility(stat, increment, user, splashAnim = true, checkContact = false, ability_name = nil)
    if stat == :SPECIAL_ATTACK && user && !user.equal?(self) && !fainted? &&
       ability_name && ability_name == KIFER.ability_name(:SCARE) && hasActiveAbility?(:GUARDDOG)
      return false if kifer_d_guard_dog_blocked?(user, :SPECIAL_ATTACK)
      return false if !pbCanRaiseStatStage?(:SPECIAL_ATTACK, self)
      return pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 1, self, true, KIFER.ability_name(:GUARDDOG))
    end
    return kifer_d_pbLowerStatStageByAbility(stat, increment, user, splashAnim, checkContact, ability_name)
  end

  # Guard Dog only turns around a drop that would have happened: Mist on its
  # side and an ally's Flower Veil stop it first (as with PIF's Intimidate)
  def kifer_d_guard_dog_blocked?(user, stat)
    return false if hasActiveAbility?(:CONTRARY) && !@battle.moldBreaker
    if pbOwnSide.effects[PBEffects::Mist] > 0 && !(user && user.hasActiveAbility?(:INFILTRATOR))
      @battle.pbDisplay(_INTL("{1} is protected by Mist!", pbThis))
      return true
    end
    return false if @battle.moldBreaker
    eachAlly do |b|
      next if !b.abilityActive?
      return true if BattleHandlers.triggerStatLossImmunityAllyAbility(b.ability, b, self, stat, @battle, true)
    end
    return false
  end
end

class PokeBattle_Battle
  # Roar, Whirlwind, Dragon Tail, Circle Throw and Red Card pick a random
  # replacement here. Mold Breaker gets past it, but not the holder's own.
  alias kifer_d_pbGetReplacementPokemonIndex pbGetReplacementPokemonIndex unless method_defined?(:kifer_d_pbGetReplacementPokemonIndex)
  def pbGetReplacementPokemonIndex(idxBattler, random = false)
    if random
      b = @battlers[idxBattler]
      if b && !b.fainted? && b.hasActiveAbility?(:GUARDDOG) && !(@moldBreaker && @lastMoveUser != idxBattler)
        return -1
      end
    end
    return kifer_d_pbGetReplacementPokemonIndex(idxBattler, random)
  end
end

class PokeBattle_Move_0EB
  alias kifer_d_roar_fails pbFailsAgainstTarget? unless method_defined?(:kifer_d_roar_fails)
  def pbFailsAgainstTarget?(user, target)
    if target.hasActiveAbility?(:GUARDDOG) && !@battle.moldBreaker
      @battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(:GUARDDOG))
      @battle.pbDisplay(_INTL("{1} anchors itself!", target.pbThis))
      @battle.pbHideAbilitySplash(target)
      return true
    end
    return kifer_d_roar_fails(user, target)
  end
end

class PokeBattle_Move_0EC
  # Wild Pokémon flee from Dragon Tail / Circle Throw here
  alias kifer_d_dragontail_effect pbEffectAgainstTarget unless method_defined?(:kifer_d_dragontail_effect)
  def pbEffectAgainstTarget(user, target)
    return if @battle.wildBattle? && target.hasActiveAbility?(:GUARDDOG) && !@battle.moldBreaker
    kifer_d_dragontail_effect(user, target)
  end
end

#-------------------------------------------------------------------------------
# Scavenger – a KO heals 1/4 of its max HP
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.copy(:PREDATOR, :SCAVENGER)

#-------------------------------------------------------------------------------
# Cheap Tactics – on entry: Scratch on a random foe
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:CHEAPTACTICS,
  proc { |ability, battler, battle|
    foe = KIFER::BatchD.random_foe(battler, true)
    next if !foe
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbHideAbilitySplash(battler)
    KIFER::BatchD.extra_move(battler, :SCRATCH, foe.index, once: false)
  }
)

#-------------------------------------------------------------------------------
# Loose Rocks – hit by contact: Stealth Rock on the attacker's side
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:LOOSEROCKS,
  proc { |ability, user, target, move, battle|
    next if !user || !move || !move.pbContactMove?(user)   # works on a KO hit too
    next if !user.affectedByContactEffect?
    side = target.pbOpposingSide
    next if side.effects[PBEffects::StealthRock]
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    side.effects[PBEffects::StealthRock] = true
    battle.pbDisplay(_INTL("Pointed stones float in the air around {1}!", target.pbOpposingTeam(true)))
    battle.pbHideAbilitySplash(target)
  }
)

#-------------------------------------------------------------------------------
# Rite of Spring – in sun: Speed x1.5, higher attacking stat x1.5
#-------------------------------------------------------------------------------
BattleHandlers::SpeedCalcAbility.add(:RITEOFSPRING,
  proc { |ability, battler, mult|
    next KIFER::BatchD.sun?(battler.battle) ? mult * 1.5 : mult
  }
)

BattleHandlers::DamageCalcUserAbility.add(:RITEOFSPRING,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if !KIFER::BatchD.sun?(user.battle)
    best = KIFER::BatchF.highest_attack_stat(user)
    used = move.specialMove? ? :SPECIAL_ATTACK : :ATTACK
    mults[:attack_multiplier] *= 1.5 if best == used
  }
)

#-------------------------------------------------------------------------------
# Aftershock – after hitting with an attack: Magnitude 4-7
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:AFTERSHOCK,
  proc { |ability, user, targets, move, battle|
    next if user.fainted? || !move.damagingMove? || KIFER.in_extra_move?(user)
    next if !targets.any? { |b| !b.damageState.unaffected && b.damageState.calcDamage > 0 }
    next if !battle.battlers.any? { |b| b && !b.fainted? && b.index != user.index && b.near?(user) }
    next if !GameData::Move.exists?(:MAGNITUDE) || [:SLEEP, :FROZEN].include?(user.status)
    next if KIFER::BatchD.extra_used?(user)   # no splash or roll for a use that won't happen
    mags = KIFER::BatchD::AFTERSHOCK_MAGNITUDES
    power = KIFER::BatchD::MAGNITUDE_POWER[mags[battle.pbRandom(mags.length)]]
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    battle.pbHideAbilitySplash(user)
    KIFER::BatchD.extra_move(user, :MAGNITUDE, -1, power)
  }
)

#-------------------------------------------------------------------------------
# Intoxicate – Normal moves become Poison; Poison moves get STAB, or (for a
# Poison-type user) a 10% chance to badly poison
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.add(:INTOXICATE,
  proc { |ability, user, move, type|
    next if type != :NORMAL || !GameData::Type.exists?(:POISON)
    next :POISON
  }
)

BattleHandlers::DamageCalcUserAbility.add(:INTOXICATE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :POISON || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

BattleHandlers::UserAbilityOnHit.add(:INTOXICATE,
  proc { |ability, user, target, move, battle|
    next if move.calcType != :POISON || !user.pbHasType?(:POISON) || target.fainted?
    next if battle.pbRandom(100) >= 10
    next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
    next if !target.pbCanPoison?(user, false, move)
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    target.pbPoison(user, nil, true)
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Perish Body – hit by contact: it and the attacker faint in 3 turns
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:PERISHBODY,
  proc { |ability, user, target, move, battle|
    next if !user || !move || target.fainted? || user.fainted? || !move.pbContactMove?(user)
    next if !user.affectedByContactEffect?
    next if user.effects[PBEffects::PerishSong] > 0
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    if target.effects[PBEffects::PerishSong] == 0
      target.effects[PBEffects::PerishSong]     = 4
      target.effects[PBEffects::PerishSongUser] = target.index
    end
    user.effects[PBEffects::PerishSong]     = 4
    user.effects[PBEffects::PerishSongUser] = target.index
    battle.pbDisplay(_INTL("Both Pokémon will faint in three turns!"))
    battle.pbHideAbilitySplash(target)
  }
)

#-------------------------------------------------------------------------------
# Soothing Aroma – on entry: cures the status of its whole party
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:SOOTHINGAROMA,
  proc { |ability, battler, battle|
    active = []
    battle.eachSameSideBattler(battler.index) { |b| active << b if b.status != :NONE }
    benched = battle.pbParty(battler.index).select do |pkmn|
      pkmn && pkmn.able? && pkmn.status != :NONE && !battle.battlers.any? { |b| b && b.pokemon && b.pokemon.equal?(pkmn) }
    end
    next if active.empty? && benched.empty?
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("A soothing aroma wafted through the area!"))
    active.each { |b| b.pbCureStatus(false) }
    benched.each do |pkmn|
      pkmn.status      = :NONE
      pkmn.statusCount = 0
    end
    battle.pbDisplay(_INTL("{1}'s team was cured of its status problems!", battler.pbTeam))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Tipping Point – each hit: Sp. Atk +1; a critical hit maxes it
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:TIPPINGPOINT,
  proc { |ability, user, target, move, battle|
    next if !user || !move || target.fainted?
    next if !target.pbCanRaiseStatStage?(:SPECIAL_ATTACK, target)
    name = KIFER.ability_name(ability)
    if target.damageState.critical
      battle.pbShowAbilitySplash(target, false, true, name)
      target.stages[:SPECIAL_ATTACK] = 6
      battle.pbCommonAnimation("StatUp", target)
      battle.pbDisplay(_INTL("{1} maxed its {2}!", target.pbThis, GameData::Stat.get(:SPECIAL_ATTACK).name))
      battle.pbHideAbilitySplash(target)
    else
      target.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, 1, target, true, name)
    end
  }
)

#-------------------------------------------------------------------------------
# Breakwater – in rain: Speed x1.5; x0.7 damage taken before it has moved
#-------------------------------------------------------------------------------
BattleHandlers::SpeedCalcAbility.add(:BREAKWATER,
  proc { |ability, battler, mult|
    next KIFER::BatchD.rain?(battler.battle) ? mult * 1.5 : mult
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:BREAKWATER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.7 if !target.movedThisRound?
  }
)

#-------------------------------------------------------------------------------
# Deadeye – arrow and cannon moves never miss; crits use the weaker defense
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcUserAbility.add(:DEADEYE,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0 if KIFER::BatchD::DEADEYE_MOVES.include?(move.id)
  }
)

class PokeBattle_Move
  # The crit flag is only this hit's inside the real damage calc (the AI's
  # estimate would read the last real hit's)
  alias kifer_d_pbCalcDamage pbCalcDamage unless method_defined?(:kifer_d_pbCalcDamage)
  def pbCalcDamage(user, target, numTargets = 1)
    old, @kifer_d_real = @kifer_d_real, true
    begin
      return kifer_d_pbCalcDamage(user, target, numTargets)
    ensure
      @kifer_d_real = old
    end
  end

  alias kifer_d_pbGetDefenseStats pbGetDefenseStats unless method_defined?(:kifer_d_pbGetDefenseStats)
  def pbGetDefenseStats(user, target)
    stat, stage = kifer_d_pbGetDefenseStats(user, target)
    if @kifer_d_real && target.damageState.critical && user.hasActiveAbility?(:DEADEYE)
      # A critical hit ignores the target's raised defenses
      d  = KIFER::BatchD.staged(target, :DEFENSE, 0)
      sd = KIFER::BatchD.staged(target, :SPECIAL_DEFENSE, 0)
      s  = (sd < d) ? :SPECIAL_DEFENSE : :DEFENSE
      st = [stage, 6].min
      if [d, sd].min < stat * KIFER::STAGE_MUL[st] / KIFER::STAGE_DIV[st]
        stat, stage = ((s == :DEFENSE) ? target.defense : target.spdef), target.stages[s] + 6
      end
    end
    return stat, stage
  end
end

#-------------------------------------------------------------------------------
# Monkey Business – on entry: Tickle on a random foe
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:MONKEYBUSINESS,
  proc { |ability, battler, battle|
    foe = KIFER::BatchD.random_foe(battler)
    next if !foe
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbHideAbilitySplash(battler)
    KIFER::BatchD.extra_move(battler, :TICKLE, foe.index, once: false)
  }
)

#-------------------------------------------------------------------------------
# Screen Cleaner – on entry: removes screens from both sides; can use screen
# moves while they are up (restarting them)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:SCREENCLEANER,
  proc { |ability, battler, battle|
    screens = [PBEffects::Reflect, PBEffects::LightScreen, PBEffects::AuroraVeil]
    sides = [battler.pbOwnSide, battler.pbOpposingSide]
    next if !sides.any? { |s| screens.any? { |e| s.effects[e] > 0 } }
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    sides.each { |s| screens.each { |e| s.effects[e] = 0 } }
    battle.pbDisplay(_INTL("All screens on the field were cleansed!"))
    battle.pbHideAbilitySplash(battler)
  }
)

module KIFER
  module BatchD
    # Runs a screen move's fail check as if its screen were down
    def self.screen_failed?(user, effect)
      side = user.pbOwnSide
      return yield if side.effects[effect] <= 0 || !user.hasActiveAbility?(:SCREENCLEANER)
      old = side.effects[effect]
      side.effects[effect] = 0
      begin
        return yield
      ensure
        side.effects[effect] = old   # the move itself sets the new turns
      end
    end
  end
end

class PokeBattle_Move_0A2   # Reflect
  alias kifer_d_reflect_failed pbMoveFailed? unless method_defined?(:kifer_d_reflect_failed)
  def pbMoveFailed?(user, targets)
    return KIFER::BatchD.screen_failed?(user, PBEffects::Reflect) { kifer_d_reflect_failed(user, targets) }
  end
end

class PokeBattle_Move_0A3   # Light Screen
  alias kifer_d_lightscreen_failed pbMoveFailed? unless method_defined?(:kifer_d_lightscreen_failed)
  def pbMoveFailed?(user, targets)
    return KIFER::BatchD.screen_failed?(user, PBEffects::LightScreen) { kifer_d_lightscreen_failed(user, targets) }
  end
end

class PokeBattle_Move_167   # Aurora Veil
  alias kifer_d_auroraveil_failed pbMoveFailed? unless method_defined?(:kifer_d_auroraveil_failed)
  def pbMoveFailed?(user, targets)
    return KIFER::BatchD.screen_failed?(user, PBEffects::AuroraVeil) { kifer_d_auroraveil_failed(user, targets) }
  end
end

#-------------------------------------------------------------------------------
# Thick Skin – super-effective moves x0.65 on it
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:THICKSKIN,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.65 if Effectiveness.super_effective?(move.pbCalcTypeMod(type, user, target))
  }
)
