#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch F)
#   Mechanics follow Elite Redux 2.65 (its C source, then its in-game texts).
#   Where the public C source is older than 2.65 and its numbers differ, the
#   2.65 text's numbers are used.
#
#   Psychic Mind      – Psychic moves x1.2, x1.5 at 1/3 HP or less
#   Twist. Dimension  – on entry: Trick Room for 3 turns (ends it if it's up)
#   Lead Coat         – physical hits on it x0.6; its Speed x0.9; weight x3
#   Striker           – kicking moves x1.3 (ER 2.65's kick list)
#   Growing Tooth     – Attack +1 after hitting with a biting move
#   Fighting Spirit   – Normal moves become Fighting. Fighting-type user: its
#                       Fighting moves ignore and break the foe's screens.
#                       Other users: Fighting moves get STAB.
#   Dust Cloud        – on entry: uses Sand Attack on a foe
#   Primal Armor      – super-effective hits on it x0.5
#   Whiteout          – in hail its higher attacking stat x1.5; no hail damage
#   Dual Wield        – single-hit Mega Launcher and Keen Edge moves hit twice,
#                       each hit x0.7 (ER's Mega Launcher list)
#   Lumberjack        – x1.5 damage to Grass-type foes; x0.5 from Grass-type
#                       attackers (by the Pokémon's types, not the move's)
#   Spider Lair       – on entry: Sticky Web on the foe's side for 5 turns
#                       (not if one is already there)
#   Draconize         – Normal moves become Dragon. Dragon-type user: its
#                       Dragon moves hit Fairy for neutral damage. Other users:
#                       Dragon moves get STAB.
#   Magical Fists     – punching moves use Sp. Atk (still hit Defense), x1.3
#   Soul Linker       – the attacker takes the same damage it deals, when it
#                       hits this Pokémon or when this Pokémon is the attacker
#                       (not if both have it or either one fainted)
#   Arctic Fur        – physical and special damage taken x0.65
#   Determination     – Sp. Atk x1.5 while it has a status problem
#   Lunar Eclipse     – Fairy and Dark moves get STAB; Hypnosis 90% accurate
#   Pretentious       – each KO it lands raises its critical hit stage by 1
#   Steely Spirit     – its and its allies' Steel moves x1.3
#   Absorbent         – drain moves heal 50% more and seed the target (Leech
#                       Seed) when they hit
#   Chilling Presence – on entry: uses a 10 power Icy Wind
#   Energy Tap        – heals 1/8 of the damage it deals to foes (min 1)
#   Heat Sink         – draws in Fire moves; immune to them and they raise its
#                       higher attacking stat by 1
#   Nosferatu         – contact moves x1.2 and heal 1/2 of the damage dealt
#   Punk Rock         – its sound moves x1.3; sound moves hit it for x0.5
#   Volcano Rage      – after using a Fire move, uses a 50 power Eruption
#                       (power scales with its HP like Eruption)
#
#   Moves used by an ability (Dust Cloud, Chilling Presence, Volcano Rage) are
#   real move uses: "X used Y!", animation, damage and effects. They don't use
#   PP and don't change the last move it used. They can miss (see use_extra_move).
#
# Left out at first, now coded in 030-035 (fog, frostbite/bleeding,
# fear, Toxic Terrain/enrage, one-offs).
#===============================================================================
KIFER.er_code(:PSYCHICMIND, :TWISTDIMENSION, :LEADCOAT, :STRIKER, :GROWINGTOOTH,
                :FIGHTINGSPIRIT, :DUSTCLOUD, :PRIMALARMOR, :WHITEOUT, :DUALWIELD,
                :LUMBERJACK, :SPIDERLAIR, :DRACONIZE, :MAGICALFISTS, :SOULLINKER,
                :ARCTICFUR, :DETERMINATION, :LUNARECLIPSE, :PRETENTIOUS, :STEELYSPIRIT,
                :ABSORBANT, :CHILLINGPRESENCE, :ENERGYTAP, :HEATSINK, :NOSFERATU,
                :PUNKROCK, :VOLCANORAGE)

module KIFER
  module BatchF
    # ER's Mega Launcher moves (Dual Wield)
    MEGA_LAUNCHER_MOVES = [
      :WATERGUN, :HYDROPUMP, :ICEBEAM, :PSYBEAM, :BUBBLEBEAM, :AURORABEAM,
      :HYPERBEAM, :SOLARBEAM, :SPIKECANNON, :OCTAZOOKA, :ZAPCANNON, :ERUPTION,
      :HYDROCANNON, :WATERSPOUT, :SIGNALBEAM, :FRENZYPLANT, :MUDSHOT, :WATERPULSE,
      :AURASPHERE, :DARKPULSE, :DRAGONPULSE, :VACUUMWAVE, :FOCUSBLAST, :MIRRORSHOT,
      :FLASHCANNON, :GUNKSHOT, :CHARGEBEAM, :FLAMEBURST, :HEALPULSE, :INFERNO,
      :SEARINGSHOT, :PARTINGSHOT, :STEAMERUPTION, :ORIGINPULSE, :ANCHORSHOT,
      :FLEURCANNON, :PRISMATICLASER, :SUNSTEELSTRIKE, :MOONGEISTBEAM, :PHOTONGEYSER,
      :DYNAMAXCANNON, :SNIPESHOT, :TARSHOT, :ETERNABEAM, :STEELBEAM, :SCALESHOT,
      :METEORBEAM, :TERRAINPULSE, :DRAGONENERGY, :PLASMAPULSE
    ].freeze

    # Drain moves (Absorbant): Absorb & co., Dream Eater, Draining Kiss & co.
    DRAIN_FUNCTIONS = ["0DD", "0DE", "14F"]

    SPIDER_LAIR_TURNS = 5

    # ER picks the higher of the raw Attack and Sp. Atk (a tie is Sp. Atk)
    def self.highest_attack_stat(battler)
      return (battler.attack > battler.spatk) ? :ATTACK : :SPECIAL_ATTACK
    end

    def self.stab_mult(user)
      return user.hasActiveAbility?(:ADAPTABILITY) ? 2 : 1.5
    end

    # STAB an ability gives for a type the user isn't (stacks with Mystic
    # Power and the other abilities that give it)
    def self.ability_stab?(user, type)
      return !!type && !user.pbHasType?(type)
    end

    def self.dual_wield_move?(move)
      return MEGA_LAUNCHER_MOVES.include?(move.id) || KIFER::SLICING_MOVES.include?(move.id)
    end

    # A target the move really hit (not a substitute, not immune)
    def self.hit?(b)
      ds = b.damageState
      return !ds.unaffected && !ds.substitute && ds.totalHPLost > 0
    end

    # Uses a move for an ability, outside the battler's turn (ER's "extra
    # move"). No PP, and the battler's last-move records are left as they
    # were. It never misses: pbUseMove's special usage skips the accuracy roll
    # (Cody, 2026-10-19), but a Pokemon in the air or underground still dodges.
    def self.use_extra_move(user, move_id, target_idx, power = nil, ability = nil)
      battle = user.battle
      return false if !GameData::Move.exists?(move_id)
      return false if user.fainted?
      move = PokeBattle_Move.from_pokemon_move(battle, Pokemon::Move.new(move_id))
      move.pp = -1
      if power
        move.instance_variable_set(:@baseDamage, power)
        move.instance_variable_set(:@kifer_f_power, power)
      end
      if ability
        battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
        battle.pbHideAbilitySplash(user)
      end
      saved = [user.lastRoundMoved, user.lastMoveUsed, user.lastMoveUsedType,
               user.lastMoveFailed, battle.lastMoveUsed, battle.lastMoveUser,
               battle.moldBreaker, user.currentMove]
      user.instance_variable_set(:@kifer_f_extra, true)
      begin
        # the move's own priority while it runs (023)
        KIFER.with_extra_move(user, move) do
          user.pbUseMove([:UseMove, -1, move, target_idx], true)
        end
      ensure
        user.instance_variable_set(:@kifer_f_extra, false)
        user.lastRoundMoved, user.lastMoveUsed, user.lastMoveUsedType,
          user.lastMoveFailed, battle.lastMoveUsed, battle.lastMoveUser,
          battle.moldBreaker = saved[0..6]
        user.instance_variable_set(:@currentMove, saved[7])
      end
      battle.pbJudge
      return true
    end

    # A foe next to the battler, picked at random (nil if none)
    def self.random_near_foe(battler)
      foes = []
      battler.battle.eachOtherSideBattler(battler.index) { |b| foes << b if b.near?(battler) }
      return nil if foes.empty?
      return foes[battler.battle.pbRandom(foes.length)]
    end
  end
end

#-------------------------------------------------------------------------------
# Psychic Mind – Psychic moves x1.2, or x1.5 at 1/3 HP or less
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:PSYCHICMIND,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= KIFER::BatchA.pinch_boost(user) if type == :PSYCHIC
  }
)

#-------------------------------------------------------------------------------
# Twisted Dimension – on entry: Trick Room for 3 turns. If Trick Room is
# already up, it ends it instead (as in ER).
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:TWISTDIMENSION,
  proc { |ability, battler, battle|
    # Copies don't stack here: a second copy would undo the first one's Trick
    # Room, so it works once per switch-in
    key = [battler.index, battler.pokemon.object_id, battle.turnCount]
    done = battle.instance_variable_get(:@kifer_f_twist) || {}
    next if done[battler.index] == key
    done[battler.index] = key
    battle.instance_variable_set(:@kifer_f_twist, done)
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    if battle.field.effects[PBEffects::TrickRoom] > 0
      battle.field.effects[PBEffects::TrickRoom] = 0
      battle.pbDisplay(_INTL("{1} reverted the dimensions!", battler.pbThis))
    else
      battle.field.effects[PBEffects::TrickRoom] = 3
      battle.pbDisplay(_INTL("{1} twisted the dimensions!", battler.pbThis))
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Lead Coat – physical hits on it x0.6; Speed x0.9; weight x3
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:LEADCOAT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.6 if move.physicalMove?(type)
  }
)

BattleHandlers::SpeedCalcAbility.add(:LEADCOAT,
  proc { |ability, battler, mult|
    next mult * 0.9
  }
)

BattleHandlers::WeightCalcAbility.add(:LEADCOAT,
  proc { |ability, battler, w|
    next w * 3
  }
)

#-------------------------------------------------------------------------------
# Striker – kicking moves x1.3
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:STRIKER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER.kick_move?(move)
  }
)

#-------------------------------------------------------------------------------
# Growing Tooth – Attack +1 after hitting with a biting move
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:GROWINGTOOTH,
  proc { |ability, user, targets, move, battle|
    next if !KIFER.bite_move?(move) || !move.damagingMove?
    next if !targets.any? { |b| KIFER::BatchF.hit?(b) }
    next if !user.pbCanRaiseStatStage?(:ATTACK, user)
    user.pbRaiseStatStageByAbility(:ATTACK, 1, user, true, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Fighting Spirit – Normal moves become Fighting
#   * Fighting-type user: its Fighting moves ignore the foe's Reflect, Light
#     Screen and Aurora Veil, and break them when they hit (like Brick Break).
#   * Other users: Fighting moves get STAB.
# Draconize – Normal moves become Dragon
#   * Dragon-type user: its Dragon moves hit Fairy-types for neutral damage.
#   * Other users: Dragon moves get STAB.
# ER 2.65's versions have no power boost for the changed moves.
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.add(:FIGHTINGSPIRIT,
  proc { |ability, user, move, type|
    next :FIGHTING if type == :NORMAL && GameData::Type.exists?(:FIGHTING)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:FIGHTINGSPIRIT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :FIGHTING || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

BattleHandlers::UserAbilityEndOfMove.add(:FIGHTINGSPIRIT,
  proc { |ability, user, targets, move, battle|
    next if move.calcType != :FIGHTING || !move.damagingMove? || !user.pbHasType?(:FIGHTING)
    next if !targets.any? { |b| !b.damageState.unaffected && b.opposes?(user) }
    side = user.pbOpposingSide
    shown = false
    [[PBEffects::LightScreen, _INTL("{1}'s Light Screen wore off!", user.pbOpposingTeam)],
     [PBEffects::Reflect,     _INTL("{1}'s Reflect wore off!", user.pbOpposingTeam)],
     [PBEffects::AuroraVeil,  _INTL("{1}'s Aurora Veil wore off!", user.pbOpposingTeam)]].each do |eff, msg|
      next if side.effects[eff] <= 0
      if !shown
        battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
        shown = true
      end
      side.effects[eff] = 0
      battle.pbDisplay(msg)
    end
    battle.pbHideAbilitySplash(user) if shown
  }
)

BattleHandlers::MoveBaseTypeModifierAbility.add(:DRACONIZE,
  proc { |ability, user, move, type|
    next :DRAGON if type == :NORMAL && GameData::Type.exists?(:DRAGON)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:DRACONIZE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :DRAGON || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

class PokeBattle_Move
  alias kifer_f_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_f_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_f_pbCalcTypeModSingle(moveType, defType, user, target)
    if moveType == :DRAGON && defType == :FAIRY && user &&
       Effectiveness.ineffective_type?(moveType, defType) &&
       user.pbHasType?(:DRAGON) && user.hasActiveAbility?(:DRACONIZE)
      ret = Effectiveness::NORMAL_EFFECTIVE_ONE
    end
    return ret
  end

  # Fighting Spirit (Fighting-type user, Fighting move): screens don't count
  alias kifer_f_ignoresReflect? ignoresReflect? unless method_defined?(:kifer_f_ignoresReflect?)
  def ignoresReflect?
    return true if @kifer_f_breaks_screens
    return kifer_f_ignoresReflect?
  end

  #-----------------------------------------------------------------------------
  # Dual Wield – single-hit Mega Launcher and Keen Edge moves hit twice, both
  # hits x0.7. Not when another ability already makes it hit twice.
  #-----------------------------------------------------------------------------
  alias kifer_f_pbNumHits pbNumHits unless method_defined?(:kifer_f_pbNumHits)
  def pbNumHits(user, targets)
    @kifer_f_dual = false
    n = kifer_f_pbNumHits(user, targets)
    if n == 1 && pbDamagingMove? && !chargingTurnMove? && targets.length == 1 &&
       KIFER::BatchF.dual_wield_move?(self) && user.hasActiveAbility?(:DUALWIELD)
      @kifer_f_dual = true
      return 2
    end
    return n
  end

  # ER: secondary effects roll for each hit, except flinch (second hit)
  alias kifer_f_pbFlinchChance pbFlinchChance unless method_defined?(:kifer_f_pbFlinchChance)
  def pbFlinchChance(user, target)
    return 0 if @kifer_f_dual && user.instance_variable_get(:@kifer_f_hit).to_i > 0
    return kifer_f_pbFlinchChance(user, target)
  end

  alias kifer_f_pbAdditionalEffectChance pbAdditionalEffectChance unless method_defined?(:kifer_f_pbAdditionalEffectChance)
  def pbAdditionalEffectChance(user, target, effectChance = 0)
    return 0 if @kifer_f_dual && flinchingMove? && user.instance_variable_get(:@kifer_f_hit).to_i > 0
    return kifer_f_pbAdditionalEffectChance(user, target, effectChance)
  end

  alias kifer_f_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_f_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    @kifer_f_breaks_screens = (type == :FIGHTING && user.pbHasType?(:FIGHTING) &&
                                 user.hasActiveAbility?(:FIGHTINGSPIRIT))
    begin
      kifer_f_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    ensure
      @kifer_f_breaks_screens = false
    end
    if @kifer_f_dual && user.hasActiveAbility?(:DUALWIELD)
      multipliers[:final_damage_multiplier] *= 0.7
    end
  end

  #-----------------------------------------------------------------------------
  # Magical Fists – punching moves use its Sp. Atk (and Sp. Atk stages)
  # instead of Attack; they still hit the target's Defense
  #-----------------------------------------------------------------------------
  alias kifer_f_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_f_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    unless physicalMove? && KIFER.punch_move?(self) && user.hasActiveAbility?(:MAGICALFISTS)
      return kifer_f_pbGetAttackStats(user, target)
    end
    @kifer_f_magical = true   # read by 008's hook, so other abilities' additions are kept
    begin
      return kifer_f_pbGetAttackStats(user, target)
    ensure
      @kifer_f_magical = false
    end
  end
end

#-------------------------------------------------------------------------------
# Dust Cloud – on entry: uses Sand Attack on a foe
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:DUSTCLOUD,
  proc { |ability, battler, battle|
    foe = KIFER::BatchF.random_near_foe(battler)
    next if !foe
    KIFER::BatchF.use_extra_move(battler, :SANDATTACK, foe.index, nil, ability)
  }
)

#-------------------------------------------------------------------------------
# Primal Armor – super-effective hits on it x0.5
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:PRIMALARMOR,
  proc { |ability, user, target, move, mults, baseDmg, type|
    if Effectiveness.super_effective?(move.pbCalcTypeMod(type, user, target))
      mults[:final_damage_multiplier] *= 0.5
    end
  }
)

#-------------------------------------------------------------------------------
# Whiteout – in hail: its higher attacking stat x1.5; no hail damage
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:WHITEOUT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if user.battle.pbWeather != :Hail
    stat = KIFER::BatchF.highest_attack_stat(user)
    if (stat == :ATTACK && move.physicalMove?(type)) ||
       (stat == :SPECIAL_ATTACK && move.specialMove?(type))
      mults[:attack_multiplier] *= 1.5
    end
  }
)

class PokeBattle_Battler
  alias kifer_f_takesHailDamage? takesHailDamage? unless method_defined?(:kifer_f_takesHailDamage?)
  def takesHailDamage?
    return false if !kifer_f_takesHailDamage?
    return false if hasActiveAbility?(:WHITEOUT)
    return true
  end

  # Pretentious: crit stages from KOs (Baton Pass passes them on, like Focus
  # Energy)
  alias kifer_f_pbInitEffects pbInitEffects unless method_defined?(:kifer_f_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_f_pbInitEffects(batonPass)
    @kifer_f_crit = 0 if !batonPass
  end

  def kifer_f_crit
    return @kifer_f_crit || 0
  end

  def kifer_f_crit=(value)
    @kifer_f_crit = value
  end

  #-----------------------------------------------------------------------------
  # Absorbant – drain moves heal 50% more
  #-----------------------------------------------------------------------------
  alias kifer_f_pbRecoverHPFromDrain pbRecoverHPFromDrain unless method_defined?(:kifer_f_pbRecoverHPFromDrain)
  def pbRecoverHPFromDrain(amt, target, msg = nil)
    if @kifer_f_draining && hasActiveAbility?(:ABSORBANT)
      amt = [(amt * 1.5).floor, 1].max
    end
    kifer_f_pbRecoverHPFromDrain(amt, target, msg)
  end

  #-----------------------------------------------------------------------------
  # Volcano Rage – its follow-up Eruption is used once the move is over
  #-----------------------------------------------------------------------------
  alias kifer_f_pbUseMove pbUseMove unless method_defined?(:kifer_f_pbUseMove)
  def pbUseMove(choice, specialUsage = false)
    @kifer_f_follow = nil if !@kifer_f_extra
    begin
      kifer_f_pbUseMove(choice, specialUsage)
    ensure
      # Dual Wield's mark is for this use only
      choice[2].instance_variable_set(:@kifer_f_dual, false) if choice[2].is_a?(PokeBattle_Move)
    end
    follow = @kifer_f_follow
    @kifer_f_follow = nil
    return if !follow || @kifer_f_extra
    return if @battle.decision > 0 || fainted?
    move_id, idx_target, power, ability = follow
    target = @battle.battlers[idx_target]
    return if !target || target.fainted?
    return if [:SLEEP, :FROZEN].include?(@status)
    KIFER::BatchF.use_extra_move(self, move_id, idx_target, power, ability)
  end
end

KIFER::BatchF::DRAIN_FUNCTIONS.each do |code|
  klass = Object.const_get("PokeBattle_Move_#{code}") rescue nil
  next if !klass
  klass.class_eval do
    alias_method :kifer_f_pbEffectAgainstTarget, :pbEffectAgainstTarget unless method_defined?(:kifer_f_pbEffectAgainstTarget)
    define_method(:pbEffectAgainstTarget) do |user, target|
      user.instance_variable_set(:@kifer_f_draining, true)
      begin
        kifer_f_pbEffectAgainstTarget(user, target)
      ensure
        user.instance_variable_set(:@kifer_f_draining, false)
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Lumberjack – x1.5 damage to Grass-type Pokémon, x0.5 from Grass-type
# attackers
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:LUMBERJACK,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 1.5 if target.pbHasType?(:GRASS)
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:LUMBERJACK,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.5 if user.pbHasType?(:GRASS)
  }
)

#-------------------------------------------------------------------------------
# Spider Lair – on entry: Sticky Web on the foe's side for 5 turns. Does
# nothing if a Sticky Web is already there. A Sticky Web laid by the move
# stays as long as it normally does.
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:SPIDERLAIR,
  proc { |ability, battler, battle|
    side = battler.pbOpposingSide
    next if side.effects[PBEffects::StickyWeb]
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    side.effects[PBEffects::StickyWeb] = true
    side.instance_variable_set(:@kifer_f_web, KIFER::BatchF::SPIDER_LAIR_TURNS)
    battle.pbDisplay(_INTL("A sticky web has been laid out beneath {1}'s feet!",
                           battler.pbOpposingTeam(true)))
    battle.pbHideAbilitySplash(battler)
  }
)

class PokeBattle_Move_153
  alias kifer_f_pbEffectGeneral pbEffectGeneral unless method_defined?(:kifer_f_pbEffectGeneral)
  def pbEffectGeneral(user)
    kifer_f_pbEffectGeneral(user)
    user.pbOpposingSide.instance_variable_set(:@kifer_f_web, 0)
  end
end

class PokeBattle_Battle
  # Counted down with the other side effects at the end of each round
  alias kifer_f_pbEORCountDownSideEffect pbEORCountDownSideEffect unless method_defined?(:kifer_f_pbEORCountDownSideEffect)
  def pbEORCountDownSideEffect(side, effect, msg)
    kifer_f_web_countdown(side) if effect == PBEffects::Reflect
    kifer_f_pbEORCountDownSideEffect(side, effect, msg)
  end

  def kifer_f_web_countdown(side)
    s = @sides[side]
    turns = s.instance_variable_get(:@kifer_f_web).to_i
    return if turns <= 0
    if !s.effects[PBEffects::StickyWeb]   # removed (Rapid Spin, Defog...)
      s.instance_variable_set(:@kifer_f_web, 0)
      return
    end
    turns -= 1
    s.instance_variable_set(:@kifer_f_web, turns)
    return if turns > 0
    s.effects[PBEffects::StickyWeb] = false
    pbDisplay(_INTL("{1}'s Sticky Web wore off!", @battlers[side].pbTeam))
  end
end

#-------------------------------------------------------------------------------
# Magical Fists – punching moves x1.3 (the Sp. Atk part is above)
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:MAGICALFISTS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER.punch_move?(move)
  }
)

#-------------------------------------------------------------------------------
# Soul Linker – after a hit, the attacker takes the same damage it dealt:
#   * when this Pokémon is hit (the attacker is hurt)
#   * when this Pokémon hits (it hurts itself)
# Not if both have Soul Linker, or if either one fainted from the hit.
#-------------------------------------------------------------------------------
module KIFER
  module BatchF
    def self.soul_link(owner, ability, user, target)
      return if user.index == target.index
      return if user.fainted? || target.fainted?
      dmg = target.damageState.hpLost
      return if dmg <= 0
      other = owner.equal?(user) ? target : user
      return if other.hasActiveAbility?(:SOULLINKER)
      battle = owner.battle
      battle.pbShowAbilitySplash(owner, false, true, KIFER.ability_name(ability))
      if user.takesIndirectDamage?(true)
        battle.scene.pbDamageAnimation(user)
        user.pbReduceHP(dmg, false)
        battle.pbDisplay(_INTL("{1} is hurt!", user.pbThis))
      end
      battle.pbHideAbilitySplash(owner)
    end
  end
end

BattleHandlers::TargetAbilityOnHit.add(:SOULLINKER,
  proc { |ability, user, target, move, battle|
    KIFER::BatchF.soul_link(target, ability, user, target)
  }
)

BattleHandlers::UserAbilityOnHit.add(:SOULLINKER,
  proc { |ability, user, target, move, battle|
    KIFER::BatchF.soul_link(user, ability, user, target)
  }
)

#-------------------------------------------------------------------------------
# Arctic Fur – damage taken x0.65
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:ARCTICFUR,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.65
  }
)

#-------------------------------------------------------------------------------
# Determination – Sp. Atk x1.5 while it has a status problem
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:DETERMINATION,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if user.status == :NONE
    mults[:attack_multiplier] *= 1.5 if move.specialMove?(type)
  }
)

#-------------------------------------------------------------------------------
# Lunar Eclipse – Fairy and Dark moves get STAB; Hypnosis is 90% accurate
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:LUNARECLIPSE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :FAIRY && type != :DARK
    next if !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

BattleHandlers::AccuracyCalcUserAbility.add(:LUNARECLIPSE,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 90 if move.id == :HYPNOSIS && mods[:base_accuracy] < 90 && mods[:base_accuracy] > 0
  }
)

#-------------------------------------------------------------------------------
# Pretentious – each KO it lands with an attack raises its critical hit stage
# by 1 (stacks, until it switches out)
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:PRETENTIOUS,
  proc { |ability, user, targets, move, battle|
    next if user.fainted? || !move.damagingMove?
    kos = targets.count { |b| b.damageState.fainted }
    next if kos == 0
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    user.kifer_f_crit += kos
    battle.pbDisplay(_INTL("{1} is getting pumped!", user.pbThis))
    battle.pbHideAbilitySplash(user)
  }
)

class << BattleHandlers
  alias kifer_f_triggerCriticalCalcUserAbility triggerCriticalCalcUserAbility unless method_defined?(:kifer_f_triggerCriticalCalcUserAbility)
  def triggerCriticalCalcUserAbility(ability, user, target, c)
    ret = kifer_f_triggerCriticalCalcUserAbility(ability, user, target, c)
    if ret.is_a?(Numeric) && ret >= 0 && user.respond_to?(:kifer_f_crit) &&
       user.kifer_f_crit > 0 && user.hasActiveAbility?(:PRETENTIOUS)
      ret += user.kifer_f_crit
    end
    return ret
  end
end

#-------------------------------------------------------------------------------
# Steely Spirit – its and its allies' Steel moves x1.3
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:STEELYSPIRIT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if type == :STEEL
  }
)

BattleHandlers::DamageCalcUserAllyAbility.add(:STEELYSPIRIT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if type == :STEEL
  }
)

#-------------------------------------------------------------------------------
# Absorbant – a drain move that hits seeds the target (the heal boost is
# above). Not Grass-types or a target that's already seeded.
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:ABSORBANT,
  proc { |ability, user, targets, move, battle|
    next if !KIFER::BatchF::DRAIN_FUNCTIONS.include?(KIFER.pif_function(move))
    targets.each do |b|
      next if b.fainted? || b.index == user.index
      next if !KIFER::BatchF.hit?(b)
      next if b.pbHasType?(:GRASS) || b.effects[PBEffects::LeechSeed] >= 0
      battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
      b.effects[PBEffects::LeechSeed] = user.index
      battle.pbDisplay(_INTL("{1} was seeded!", b.pbThis))
      battle.pbHideAbilitySplash(user)
    end
  }
)

#-------------------------------------------------------------------------------
# Chilling Presence – on entry: uses Icy Wind with 10 power
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:CHILLINGPRESENCE,
  proc { |ability, battler, battle|
    next if !KIFER::BatchF.random_near_foe(battler)
    KIFER::BatchF.use_extra_move(battler, :ICYWIND, -1, 10, ability)
  }
)

#-------------------------------------------------------------------------------
# Energy Tap – heals 1/8 of the damage it deals to a foe, right after each hit
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:ENERGYTAP,
  proc { |ability, user, target, move, battle|
    next if !target.opposes?(user) || !user.canHeal?
    dmg = target.damageState.hpLost
    next if dmg <= 0
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    user.pbRecoverHP([dmg / 8, 1].max)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", user.pbThis))
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Heat Sink – draws in Fire moves aimed at one foe (like Lightning Rod), is
# immune to Fire moves, and they raise its higher attacking stat by 1
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:HEATSINK,
  proc { |ability, user, target, move, type, battle|
    stat = KIFER::BatchF.highest_attack_stat(target)
    next pbBattleMoveImmunityStatAbility(user, target, move, type, :FIRE, stat, 1, battle)
  }
)

class PokeBattle_Battler
  alias kifer_f_pbChangeTargets pbChangeTargets unless method_defined?(:kifer_f_pbChangeTargets)
  def pbChangeTargets(move, user, targets)
    first = targets[0]
    ret = kifer_f_pbChangeTargets(move, user, targets)
    return ret if ret.length != 1 || !ret[0].equal?(first)   # already redirected
    return ret if move.calcType != :FIRE || @battle.switching || move.cannotRedirect?
    return ret if user && user.hasActiveAbility?(:PROPELLERTAIL)   # (024's check runs inside this one)
    t = move.pbTarget(user)
    return ret if !t.can_target_one_foe?
    return pbChangeTargetByAbility(:HEATSINK, :FIRE, move, user, ret, @battle.pbPriority(true),
                                   !t.can_choose_distant_target?)
  end
end

#-------------------------------------------------------------------------------
# Nosferatu – contact moves x1.2, and heal 1/2 of the damage they dealt
# (after all hits and recoil)
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:NOSFERATU,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.2 if move.pbContactMove?(user)
  }
)

BattleHandlers::UserAbilityEndOfMove.add(:NOSFERATU,
  proc { |ability, user, targets, move, battle|
    next if !move.damagingMove? || !move.pbContactMove?(user) || !user.canHeal?
    dmg = 0
    targets.each { |b| dmg += b.damageState.totalHPLost if KIFER::BatchF.hit?(b) && b.index != user.index }
    next if dmg <= 0
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    user.pbRecoverHP([dmg / 2, 1].max)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", user.pbThis))
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Punk Rock – its sound moves x1.3; sound moves hit it for x0.5
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:PUNKROCK,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER.sound_move?(move)
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:PUNKROCK,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.5 if KIFER.sound_move?(move)
  }
)

#-------------------------------------------------------------------------------
# Volcano Rage – after it uses a Fire move that works, it uses Eruption with
# 50 power (scaled by its HP: 50 at full HP) at the same target
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:VOLCANORAGE,
  proc { |ability, user, targets, move, battle|
    next if user.instance_variable_get(:@kifer_f_extra)
    next if move.calcType != :FIRE || user.fainted? || user.lastMoveFailed
    next if user.instance_variable_get(:@kifer_f_follow)
    t = targets.find { |b| b.index != user.index && !b.fainted? && !b.damageState.unaffected }
    next if !t
    user.instance_variable_set(:@kifer_f_follow, [:ERUPTION, t.index, 50, ability])
  }
)

class PokeBattle_Move_08B   # Eruption, Water Spout
  alias kifer_f_pbBaseDamage pbBaseDamage unless method_defined?(:kifer_f_pbBaseDamage)
  def pbBaseDamage(baseDmg, user, target)
    power = @kifer_f_power
    return [power * user.hp / user.totalhp, 1].max if power
    return kifer_f_pbBaseDamage(baseDmg, user, target)
  end
end

# The hit number of the move a battler is using (Dual Wield's flinch rule)
class PokeBattle_Battler
  alias kifer_f_pbProcessMoveHit pbProcessMoveHit unless method_defined?(:kifer_f_pbProcessMoveHit)
  def pbProcessMoveHit(move, user, targets, hitNum, skipAccuracyCheck)
    user.instance_variable_set(:@kifer_f_hit, hitNum)
    return kifer_f_pbProcessMoveHit(move, user, targets, hitNum, skipAccuracyCheck)
  end
end
