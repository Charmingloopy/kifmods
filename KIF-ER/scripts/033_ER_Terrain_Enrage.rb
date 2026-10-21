#===============================================================================
# KIF: Elite Redux – Elite Redux's Toxic Terrain, enrage, and Mold Breaker for one
# target, and the abilities that need them
#   Mechanics follow Elite Redux 2.65: ER's C source (eliteredux-source) first,
#   then the 2.65 in-game texts.
#
#   Toxic Terrain (a battle terrain, :Toxic):
#     - lasts 8 turns, 12 if the Pokemon that set it holds a Terrain Extender
#     - end of each turn: grounded Pokemon that aren't Poison or Steel lose
#       1/16 of their max HP. Magic Guard, Stench and Poison Heal block it.
#     - grounded Pokemon's Poison moves do 30% more damage
#     - its turns don't count down while a Pokemon with Stench is out
#     - Venoshock and Venom Drench treat grounded Pokemon as poisoned
#     - Camouflage makes the user Poison-type
#     - Toxic Boost: a grounded Pokemon with it poisons itself when it comes
#       in, or when Toxic Terrain starts
#     - Spikes become Toxic Spikes (Toxic Surge's text: "Spikes are converted
#       to Toxic Spikes"): when the terrain starts, and Spikes laid while it
#       is up turn before the next Pokemon comes in on that side. Each layer
#       of Spikes is a layer of Toxic Spikes (2 at most); they stay Toxic
#       Spikes after the terrain ends.
#     - Defog doesn't clear it (ER's Defog clears no terrain)
#     - Nature Power and Secret Power use the place's move, as in ER (it has
#       no Toxic Terrain move for them). Mimicry doesn't change type for it.
#     - like other terrains: a new terrain replaces it
#     - looks: no common animation (PIF has none that fits)
#     - only starts while the "New battle effects" setting is On
#   Enrage (a volatile effect, kept on the battler like confusion):
#     - after an enraged Pokemon's move deals damage, it loses 1/3 of the
#       damage it dealt. Magic Guard, Rock Head, Steel Barrel and Brute Force
#       block this.
#     - Reckless boosts every move of an enraged Pokemon
#     - lasts until it switches out; Baton Pass passes it on
#     - Swagger and Flatter enrage instead of confusing (they fail on a target
#       that is already enraged and can't raise the stat)
#     - only starts while the "New battle effects" setting is On
#   Mold Breaker for one target: @battle.moldBreaker is read per target while
#     a move is used against that target (see TargetMoldBreaker below).
#     Deadly Precision and Third-Degree Burn use it.
#
#   Toxic Surge      – on entry: sets Toxic Terrain. Toxic Terrain affects it
#                      even when it isn't grounded.
#   Biofilm          – Sp. Def x1.5 while Toxic Terrain is up
#   Berserk DNA      – on entry: its higher attacking stat (with stat stages)
#                      +2, then it becomes enraged. Does nothing if that stat
#                      can't go higher; the boost still happens if it can't
#                      become enraged.
#   Deviate          – Normal moves become Dark. Dark-type user: its Dark moves
#                      have a 10% chance to enrage the target. Other users:
#                      Dark moves get STAB.
#   Deadly Precision – its damaging moves never miss a target they're super
#                      effective against, and ignore that target's abilities
#                      (like Mold Breaker, for that target only)
#   Stalwart         – its moves can't be redirected; it can't be hit by a
#                      critical hit; Mold Breaker and Gastro Acid don't affect
#                      its abilities (Magic Bounce still bounces a Mold
#                      Breaker user's status moves, with or without a target)
#   Third-Degree Burn – it can burn Fire types (their type immunity is
#                      skipped); its Fire moves ignore the target's abilities
#                      (like Mold Breaker, for each target; Stalwart still
#                      keeps its own)
#
#   Not coded yet: none.
#   Not added: ER's Toxic Terrain move, Terrain Pulse and Toxic Thread's
#   spread (PIF doesn't have them); the Toxic Terrain seed (no such item).
#===============================================================================
KIFER.feature(:toxic_terrain, "Toxic Terrain",
                "Elite Redux's Toxic Terrain (Toxic Surge): hurts grounded Pokemon each turn.")
KIFER.feature(:enrage, "Enrage",
                "Elite Redux's enrage: an enraged Pokemon is hurt by 1/3 of the damage it deals.")
KIFER.er_code(:TOXICSURGE, :BIOFILM, :BERSERKDNA, :DEVIATE, :DEADLYPRECISION, :STALWART,
                :THIRDDEGREEBURN)

if defined?(GameData::BattleTerrain) && !GameData::BattleTerrain.exists?(:Toxic)
  GameData::BattleTerrain.register({
    :id   => :Toxic,
    :name => _INTL("Toxic")
  })
end

module KIFER
  module TerrainEnrage
    TURNS          = 8
    TURNS_EXTENDER = 12
    NO_RECOIL      = [:ROCKHEAD, :STEELBARREL, :BRUTEFORCE]
    NO_TOXIC_CHIP  = [:STENCH, :POISONHEAL]

    #---------------------------------------------------------------------------
    # Toxic Terrain
    #---------------------------------------------------------------------------
    def self.toxic_terrain?(battle)
      return battle.field.terrain == :Toxic
    end

    # Toxic Terrain affects it (grounded; Toxic Surge also when airborne).
    # on: whether the terrain is up (the battle AI passes a would-be one)
    def self.toxic_affected?(battler, on = nil)
      return false if !battler || battler.fainted?
      return false if !(on.nil? ? toxic_terrain?(battler.battle) : on)
      return false if battler.semiInvulnerable?
      return true if battler.affectedByTerrain?
      return battler.hasActiveAbility?(:TOXICSURGE)
    end

    def self.toxic_chip?(battler, on = nil)
      return false if !toxic_affected?(battler, on)
      return false if battler.pbHasType?(:POISON) || battler.pbHasType?(:STEEL)
      return false if !battler.takesIndirectDamage?
      return false if battler.hasActiveAbility?(NO_TOXIC_CHIP)
      return true
    end

    def self.stench_out?(battle)
      battle.eachBattler { |b| return true if b.hasActiveAbility?(:STENCH) }
      return false
    end

    # After PIF's pbStartTerrain set it: ER's turns, message, Toxic Boost
    def self.after_toxic_start(battle, user, fixed_duration)
      turns = -1
      if fixed_duration
        turns = TURNS
        turns = TURNS_EXTENDER if user && user.hasActiveItem?(:TERRAINEXTENDER)
      end
      battle.field.terrainDuration = turns
      battle.pbDisplay(_INTL("Toxic sludge covers the battlefield!"))
      convert_spikes(battle)
      battle.pbPriority(true).each { |b| toxic_boost(b) }
    end

    # Spikes -> Toxic Spikes on each side, one layer each (2 at most)
    def self.convert_spikes(battle)
      return if !toxic_terrain?(battle)
      battle.sides.each do |side|
        n = side.effects[PBEffects::Spikes]
        next if n <= 0
        side.effects[PBEffects::Spikes] = 0
        side.effects[PBEffects::ToxicSpikes] = [side.effects[PBEffects::ToxicSpikes] + n, 2].min
        battle.pbDisplay(_INTL("The toxic sludge turned the spikes into toxic spikes!"))
      end
    end

    # End of turn: count down (not while Stench is out), then hurt. Returns
    # true if the terrain is still up.
    def self.eor_toxic(battle)
      field = battle.field
      if field.terrainDuration > 0 && !stench_out?(battle)
        field.terrainDuration -= 1
        if field.terrainDuration == 0
          battle.pbDisplay(_INTL("The sludge disappeared from the battlefield."))
          field.terrain = :None
          return false
        end
      end
      battle.pbDisplay(_INTL("Toxic sludge is covering the battlefield."))
      battle.pbPriority(true).each do |b|
        next if !toxic_chip?(b)
        oldHP = b.hp
        battle.scene.pbDamageAnimation(b)
        b.pbReduceHP([b.totalhp / 16, 1].max, false)
        battle.pbDisplay(_INTL("{1} was damaged by the toxic terrain!", b.pbThis))
        b.pbItemHPHealCheck
        b.pbAbilitiesOnDamageTaken(oldHP)
        b.pbFaint if b.fainted?
      end
      return true
    end

    # Toxic Boost (PIF's ability): poisons itself in Toxic Terrain
    def self.toxic_boost(battler)
      return if !toxic_affected?(battler)
      return if !battler.hasActiveAbility?(:TOXICBOOST)
      return if !battler.pbCanPoison?(battler, false)
      battle = battler.battle
      battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(:TOXICBOOST))
      battler.pbPoison(nil, _INTL("{1} takes the poison in!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    end

    #---------------------------------------------------------------------------
    # Enrage
    #---------------------------------------------------------------------------
    def self.enraged?(battler)
      return battler && battler.instance_variable_get(:@kifer_te_enraged) == true
    end

    # Enrages the battler. Returns true if it worked.
    def self.enrage(battler)
      return false if !battler || battler.fainted? || enraged?(battler)
      return false if !KIFER.feature_on?(:enrage)
      battler.instance_variable_set(:@kifer_te_enraged, true)
      battler.battle.pbDisplay(_INTL("{1} is filled with rage!", battler.pbThis))
      return true
    end

    # After a move: an enraged user loses 1/3 of the damage it dealt
    def self.enrage_recoil(user, targets, move)
      return if !enraged?(user) || user.fainted? || !move.damagingMove?
      dealt = 0
      targets.each do |b|
        next if !b || b.damageState.unaffected
        dealt += b.damageState.totalHPLost
      end
      return if dealt <= 0
      if move.id != :STRUGGLE
        return if !user.takesIndirectDamage?
        return if user.hasActiveAbility?(NO_RECOIL)
      end
      user.pbReduceHP([dealt / 3, 1].max, false)
      user.battle.pbDisplay(_INTL("{1} hurts itself in its rampage!", user.pbThis))
      user.pbItemHPHealCheck
      user.pbFaint if user.fainted?
    end

    #---------------------------------------------------------------------------
    # Mold Breaker for one target
    #   While a move is used against one target, that target is on a stack.
    #   PokeBattle_Battle#moldBreaker then answers for that target:
    #     - false if the target has Stalwart (its abilities can't be ignored)
    #     - true if the user has Deadly Precision and the move is super
    #       effective against the target, or has Third-Degree Burn and the
    #       move is Fire (not against a Stalwart target)
    #   A nested move (Dancer, Instruct, extra moves) starts a clean stack.
    #---------------------------------------------------------------------------
    @stack   = []
    @busy    = false
    @mb_true = false   # while checking effectiveness, as ER does it

    def self.in_target(user, target, move)
      @stack.push([user, target, move, nil])
      begin
        return yield
      ensure
        @stack.pop
      end
    end

    def self.barrier
      @stack.push(nil)
      begin
        return yield
      ensure
        @stack.pop
        @bounce_once = false
      end
    end

    # Stalwart's ER parts; with Innates Off, Megas' official one runs (Cody, 2026-10-19)
    def self.stalwart?(battler)
      return KIFER.enabled? && battler.hasActiveAbility?(:STALWART)
    end

    def self.super_effective?(user, target, move)
      type = move.calcType || move.type
      return false if !type
      old = @mb_true
      @mb_true = true
      begin
        eff = move.pbCalcTypeMod(type, user, target)
      ensure
        @mb_true = old
      end
      return Effectiveness.super_effective?(eff)
    end

    def self.deadly_precision?(user, target, move)
      return false if !user || !target || !move || user.equal?(target)
      return false if !move.damagingMove?
      return false if !user.hasActiveAbility?(:DEADLYPRECISION)
      return super_effective?(user, target, move)
    end

    # Third-Degree Burn: its Fire moves ignore the target's abilities
    def self.third_degree_burn?(user, target, move)
      return false if !user || !target || !move || user.equal?(target)
      type = move.calcType || move.type
      return false if type != :FIRE
      return user.hasActiveAbility?(:THIRDDEGREEBURN)
    end

    # Magic Bounce for moves with no target (Stealth Rock, Spikes...): PIF
    # asks each foe "hasActiveAbility?(:MAGICBOUNCE) && !moldBreaker" outside
    # any target. A Stalwart foe's yes is remembered for that next read only.
    @bounce_once = false

    def self.note_magic_bounce(battler)
      return if @busy || !battler.battle.kifer_te_moldBreaker
      @busy = true
      begin
        @bounce_once = true if stalwart?(battler)
      ensure
        @busy = false
      end
    end

    def self.adjust(raw)
      return true if @mb_true
      if @bounce_once
        @bounce_once = false
        return false
      end
      return raw if @busy
      entry = @stack.last
      return raw if !entry
      user, target, move = entry
      return raw if !target
      @busy = true
      begin
        if raw
          return false if !(user && user.equal?(target)) && stalwart?(target)
        else
          if entry[3].nil?
            entry[3] = (deadly_precision?(user, target, move) ||
                        third_degree_burn?(user, target, move)) ? true : false
          end
          return true if entry[3] && !stalwart?(target)   # Stalwart keeps its own
        end
      ensure
        @busy = false
      end
      return raw
    end

    # Writing back the value this file reported changes nothing (code that
    # saves and restores moldBreaker around a nested move)
    def self.same_as_reported?(raw, value)
      return false if @stack.empty? || !@stack.last
      return adjust(raw) == value && raw != value
    end

    # Move methods that run for one target: [name, index of the target arg]
    MOVE_TARGET_METHODS = [
      [:pbEffectAgainstTarget, 1], [:pbAdditionalEffect, 1], [:pbEffectAfterAllHits, 1],
      [:pbEffectWhenDealingDamage, 1], [:pbAdditionalEffectChance, 1], [:pbFlinchChance, 1],
      [:pbHitEffectivenessMessages, 1], [:pbEffectivenessMessage, 1],
      [:pbCheckDamageAbsorption, 1], [:pbCalcDamage, 1], [:pbReduceDamage, 1],
      [:pbEndureKOMessage, 0], [:pbAccuracyCheck, 1]
    ]

    def self.wrap_move_class(klass)
      MOVE_TARGET_METHODS.each do |meth, idx|
        next if !klass.instance_methods(false).include?(meth) &&
                !klass.private_instance_methods(false).include?(meth)
        # one alias name per class: a subclass method that calls super must
        # reach the parent's own original, never its own again
        tag = klass.name.to_s.gsub(/[^A-Za-z0-9_]/, "_")
        orig = :"kifer_te_ctx_#{tag}_#{meth}"
        next if klass.instance_methods(false).include?(orig) ||
                klass.private_instance_methods(false).include?(orig)
        klass.send(:alias_method, orig, meth)
        if meth == :pbAccuracyCheck
          klass.send(:define_method, meth) do |*args, &blk|
            user = args[0]; target = args[1]
            KIFER::TerrainEnrage.in_target(user, target, self) do
              next true if KIFER::TerrainEnrage.deadly_precision?(user, target, self)   # super effective: never misses
              send(orig, *args, &blk)
            end
          end
        else
          klass.send(:define_method, meth) do |*args, &blk|
            user = (idx == 1) ? args[0] : nil
            KIFER::TerrainEnrage.in_target(user, args[idx], self) { send(orig, *args, &blk) }
          end
        end
      end
    end

    def self.wrap_all_moves
      Object.constants.each do |c|
        next if !c.to_s.start_with?("PokeBattle_")
        k = Object.const_get(c) rescue nil
        next if !k.is_a?(Class) || !(k <= PokeBattle_Move)
        wrap_move_class(k)
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Battle: terrain start and end of turn, mold breaker per target
#-------------------------------------------------------------------------------
class PokeBattle_Battle
  alias kifer_te_pbStartTerrain pbStartTerrain unless method_defined?(:kifer_te_pbStartTerrain)
  def pbStartTerrain(user, newTerrain, fixedDuration = true)
    return kifer_te_pbStartTerrain(user, newTerrain, fixedDuration) if newTerrain != :Toxic
    return if @field.terrain == :Toxic
    kifer_te_pbStartTerrain(user, newTerrain, fixedDuration)
    return if @field.terrain != :Toxic
    KIFER::TerrainEnrage.after_toxic_start(self, user, fixedDuration)
  end

  # Spikes laid while Toxic Terrain is up are Toxic Spikes by the time a
  # Pokemon comes in
  alias kifer_te_pbOnActiveOne pbOnActiveOne unless method_defined?(:kifer_te_pbOnActiveOne)
  def pbOnActiveOne(battler)
    KIFER::TerrainEnrage.convert_spikes(self)
    return kifer_te_pbOnActiveOne(battler)
  end

  # Toxic Terrain's own countdown and damage; the rest of the chain (other
  # files' terrain hooks) still runs, with no countdown of its own
  alias kifer_te_pbEORTerrain pbEORTerrain unless method_defined?(:kifer_te_pbEORTerrain)
  def pbEORTerrain
    return kifer_te_pbEORTerrain if @field.terrain != :Toxic
    if KIFER::TerrainEnrage.eor_toxic(self)
      turns = @field.terrainDuration
      @field.terrainDuration = -1
      begin
        kifer_te_pbEORTerrain
      ensure
        @field.terrainDuration = turns if @field.terrain == :Toxic
      end
    else
      kifer_te_pbEORTerrain
      pbStartTerrain(nil, @field.defaultTerrain, false) if @field.terrain == :None && @field.defaultTerrain != :None
    end
  end

  alias kifer_te_moldBreaker moldBreaker unless method_defined?(:kifer_te_moldBreaker)
  def moldBreaker
    return KIFER::TerrainEnrage.adjust(kifer_te_moldBreaker)
  end

  alias kifer_te_set_moldBreaker moldBreaker= unless method_defined?(:kifer_te_set_moldBreaker)
  def moldBreaker=(value)
    return value if KIFER::TerrainEnrage.same_as_reported?(kifer_te_moldBreaker, value)
    kifer_te_set_moldBreaker(value)
  end
end

#-------------------------------------------------------------------------------
# Battlers: enrage, Stalwart, per-target checks
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_te_pbInitEffects pbInitEffects unless method_defined?(:kifer_te_pbInitEffects)
  def pbInitEffects(batonPass)
    keep = batonPass && @kifer_te_enraged == true
    kifer_te_pbInitEffects(batonPass)
    @kifer_te_enraged = keep
  end

  # Gastro Acid doesn't stop a Stalwart Pokemon's abilities
  alias kifer_te_abilityActive? abilityActive? unless method_defined?(:kifer_te_abilityActive?)
  def abilityActive?(ignore_fainted = false)
    if @effects[PBEffects::GastroAcid] && KIFER::Specials1.stalwart_raw?(self)   # 034
      return false if fainted? && !ignore_fainted
      return true
    end
    return kifer_te_abilityActive?(ignore_fainted)
  end

  # Stalwart + Magic Bounce vs Mold Breaker, for moves with no target (moves
  # with a target are covered by pbSuccessCheckAgainstTarget below)
  alias kifer_te_hasActiveAbility? hasActiveAbility? unless method_defined?(:kifer_te_hasActiveAbility?)
  def hasActiveAbility?(check_ability, ignore_fainted = false, mold_broken = false)
    ret = kifer_te_hasActiveAbility?(check_ability, ignore_fainted, mold_broken)
    KIFER::TerrainEnrage.note_magic_bounce(self) if ret && check_ability == :MAGICBOUNCE
    return ret
  end

  # Third-Degree Burn: Fire types' burn immunity is skipped while the game
  # asks whether it can burn them
  alias kifer_te_pbCanInflictStatus? pbCanInflictStatus? unless method_defined?(:kifer_te_pbCanInflictStatus?)
  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
    if newStatus == :BURN && user && user.index != @index && !@kifer_te_no_fire &&
       user.hasActiveAbility?(:THIRDDEGREEBURN)
      @kifer_te_no_fire = true
      begin
        return kifer_te_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
      ensure
        @kifer_te_no_fire = false
      end
    end
    return kifer_te_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
  end

  alias kifer_te_pbHasType? pbHasType? unless method_defined?(:kifer_te_pbHasType?)
  def pbHasType?(type)
    return false if @kifer_te_no_fire && type == :FIRE
    return kifer_te_pbHasType?(type)
  end

  # Stalwart: its moves can't be redirected
  alias kifer_te_pbChangeTargets pbChangeTargets unless method_defined?(:kifer_te_pbChangeTargets)
  def pbChangeTargets(move, user, targets)
    return targets if user && KIFER::TerrainEnrage.stalwart?(user)
    return kifer_te_pbChangeTargets(move, user, targets)
  end

  # A nested move starts with no target
  alias kifer_te_pbUseMove pbUseMove unless method_defined?(:kifer_te_pbUseMove)
  def pbUseMove(*args, &blk)
    KIFER::TerrainEnrage.barrier { kifer_te_pbUseMove(*args, &blk) }
  end

  alias kifer_te_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget unless method_defined?(:kifer_te_pbSuccessCheckAgainstTarget)
  def pbSuccessCheckAgainstTarget(move, user, target)
    KIFER::TerrainEnrage.in_target(user, target, move) do
      kifer_te_pbSuccessCheckAgainstTarget(move, user, target)
    end
  end

  alias kifer_te_pbSuccessCheckPerHit pbSuccessCheckPerHit unless method_defined?(:kifer_te_pbSuccessCheckPerHit)
  def pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
    KIFER::TerrainEnrage.in_target(user, target, move) do
      kifer_te_pbSuccessCheckPerHit(move, user, target, skipAccuracyCheck)
    end
  end

  alias kifer_te_pbEffectsOnMakingHit pbEffectsOnMakingHit unless method_defined?(:kifer_te_pbEffectsOnMakingHit)
  def pbEffectsOnMakingHit(move, user, target)
    KIFER::TerrainEnrage.in_target(user, target, move) do
      kifer_te_pbEffectsOnMakingHit(move, user, target)
    end
  end

  # Enrage recoil comes after all hits, before switching effects
  alias kifer_te_pbEffectsAfterMove pbEffectsAfterMove unless method_defined?(:kifer_te_pbEffectsAfterMove)
  def pbEffectsAfterMove(user, targets, move, numHits)
    KIFER::TerrainEnrage.enrage_recoil(user, targets, move)
    kifer_te_pbEffectsAfterMove(user, targets, move, numHits)
  end
end

#-------------------------------------------------------------------------------
# Moves
#-------------------------------------------------------------------------------
class PokeBattle_Move
  # Toxic Terrain: grounded users' Poison moves x1.3
  alias kifer_te_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_te_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    kifer_te_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    if type == :POISON && @battle.field.terrain == :Toxic && KIFER::TerrainEnrage.toxic_affected?(user)
      multipliers[:base_damage_multiplier] *= 1.3
    end
  end
end

# Venoshock: a target in Toxic Terrain counts as poisoned
class PokeBattle_Move_07B
  alias kifer_te_pbBaseDamage pbBaseDamage unless method_defined?(:kifer_te_pbBaseDamage)
  def pbBaseDamage(baseDmg, user, target)
    ret = kifer_te_pbBaseDamage(baseDmg, user, target)
    if !target.poisoned? && KIFER::TerrainEnrage.toxic_affected?(target) &&
       (target.effects[PBEffects::Substitute] == 0 || ignoresSubstitute?(user))
      ret *= 2
    end
    return ret
  end
end

# Venom Drench: a target in Toxic Terrain counts as poisoned
class PokeBattle_Move_140
  alias kifer_te_pbMoveFailed? pbMoveFailed? unless method_defined?(:kifer_te_pbMoveFailed?)
  def pbMoveFailed?(user, targets)
    return kifer_te_pbMoveFailed?(user, targets) if @battle.field.terrain != :Toxic
    @validTargets = []
    targets.each do |b|
      next if !b || b.fainted?
      next if !b.poisoned? && !KIFER::TerrainEnrage.toxic_affected?(b)
      next if !b.pbCanLowerStatStage?(:ATTACK, user, self) &&
              !b.pbCanLowerStatStage?(:SPECIAL_ATTACK, user, self) &&
              !b.pbCanLowerStatStage?(:SPEED, user, self)
      @validTargets.push(b.index)
    end
    if @validTargets.length == 0
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return false
  end
end

# Camouflage: Poison in Toxic Terrain
class PokeBattle_Move_060
  alias kifer_te_pbMoveFailed? pbMoveFailed? unless method_defined?(:kifer_te_pbMoveFailed?)
  def pbMoveFailed?(user, targets)
    return kifer_te_pbMoveFailed?(user, targets) if @battle.field.terrain != :Toxic
    if !user.canChangeType? || !GameData::Type.exists?(:POISON) || !user.pbHasOtherType?(:POISON)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    @newType = :POISON
    return false
  end
end

# Flatter / Swagger: enrage instead of confusing (while enrage is on)
module KIFER
  module TerrainEnrage
    def self.rage_move_failed?(move, user, targets, stat)
      failed = true
      targets.each do |b|
        next if enraged?(b) && !b.pbCanRaiseStatStage?(stat, user, move)
        failed = false
        break
      end
      if failed
        user.battle.pbDisplay(_INTL("But it failed!"))
        return true
      end
      return false
    end

    def self.rage_move_effect(move, user, target, stat, n)
      if target.pbCanRaiseStatStage?(stat, user, move)
        target.pbRaiseStatStage(stat, n, user)
      end
      enrage(target)
    end
  end
end

class PokeBattle_Move_040
  alias kifer_te_pbMoveFailed? pbMoveFailed? unless method_defined?(:kifer_te_pbMoveFailed?)
  def pbMoveFailed?(user, targets)
    return kifer_te_pbMoveFailed?(user, targets) if !KIFER.feature_on?(:enrage)
    return KIFER::TerrainEnrage.rage_move_failed?(self, user, targets, :SPECIAL_ATTACK)
  end

  alias kifer_te_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_te_pbEffectAgainstTarget)
  def pbEffectAgainstTarget(user, target)
    return kifer_te_pbEffectAgainstTarget(user, target) if !KIFER.feature_on?(:enrage)
    KIFER::TerrainEnrage.rage_move_effect(self, user, target, :SPECIAL_ATTACK, 1)
  end
end

class PokeBattle_Move_041
  alias kifer_te_pbMoveFailed? pbMoveFailed? unless method_defined?(:kifer_te_pbMoveFailed?)
  def pbMoveFailed?(user, targets)
    return kifer_te_pbMoveFailed?(user, targets) if !KIFER.feature_on?(:enrage)
    return KIFER::TerrainEnrage.rage_move_failed?(self, user, targets, :ATTACK)
  end

  alias kifer_te_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_te_pbEffectAgainstTarget)
  def pbEffectAgainstTarget(user, target)
    return kifer_te_pbEffectAgainstTarget(user, target) if !KIFER.feature_on?(:enrage)
    KIFER::TerrainEnrage.rage_move_effect(self, user, target, :ATTACK, 2)
  end
end

# Gastro Acid fails on Stalwart
class PokeBattle_Move_068
  alias kifer_te_pbFailsAgainstTarget? pbFailsAgainstTarget? unless method_defined?(:kifer_te_pbFailsAgainstTarget?)
  def pbFailsAgainstTarget?(user, target)
    if KIFER::TerrainEnrage.stalwart?(target)
      @battle.pbDisplay(_INTL("But it failed!"))
      return true
    end
    return kifer_te_pbFailsAgainstTarget?(user, target)
  end
end

#-------------------------------------------------------------------------------
# Toxic Surge – sets Toxic Terrain on entry
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:TOXICSURGE,
  proc { |ability, battler, battle|
    next if !KIFER.feature_on?(:toxic_terrain)
    next if battle.field.terrain == :Toxic
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbStartTerrain(battler, :Toxic)
    # the splash is hidden in pbStartTerrain
  }
)

# Toxic Boost (PIF's ability) poisons itself in Toxic Terrain on entry
BattleHandlers::AbilityOnSwitchIn.add(:TOXICBOOST,
  proc { |ability, battler, battle|
    KIFER::TerrainEnrage.toxic_boost(battler)
  }
)

#-------------------------------------------------------------------------------
# Biofilm – Sp. Def x1.5 in Toxic Terrain
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:BIOFILM,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if user.battle.field.terrain != :Toxic || !move.specialMove?(type)
    mults[:defense_multiplier] *= 1.5
  }
)

#-------------------------------------------------------------------------------
# Berserk DNA – higher attacking stat +2, then enraged
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:BERSERKDNA,
  proc { |ability, battler, battle|
    stat = KIFER::ERVersions.highest_attack(battler)
    next if !battler.pbCanRaiseStatStage?(stat, battler)
    name = KIFER.ability_name(ability)
    battler.pbRaiseStatStageByAbility(stat, 2, battler, true, name)
    KIFER::TerrainEnrage.enrage(battler)
  }
)

#-------------------------------------------------------------------------------
# Deviate – Normal moves become Dark; Dark STAB, or (Dark-type user) a 10%
# chance to enrage
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.add(:DEVIATE,
  proc { |ability, user, move, type|
    next :DARK if type == :NORMAL && GameData::Type.exists?(:DARK)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:DEVIATE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :DARK || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

BattleHandlers::UserAbilityOnHit.add(:DEVIATE,
  proc { |ability, user, target, move, battle|
    next if move.calcType != :DARK || !user.pbHasType?(:DARK)
    next if target.fainted? || target.damageState.substitute
    next if KIFER::TerrainEnrage.enraged?(target) || !KIFER.feature_on?(:enrage)
    next if battle.pbRandom(100) >= 10
    next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    KIFER::TerrainEnrage.enrage(target)
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Reckless (PIF's ability): every move counts as a recoil move while enraged
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:RECKLESS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    if move.recoilMove? || KIFER::TerrainEnrage.enraged?(user)
      mults[:base_damage_multiplier] *= 1.2
    end
  }
)

#-------------------------------------------------------------------------------
# Stalwart – can't be hit by a critical hit (the rest is above)
#-------------------------------------------------------------------------------
BattleHandlers::CriticalCalcTargetAbility.add(:STALWART,
  proc { |ability, user, target, c|
    next c if !KIFER.enabled?
    next -1
  }
)

#-------------------------------------------------------------------------------
# Poison Absorb (Batch D) – heals 1/8 of its max HP each turn in Toxic Terrain
# (grounded, not on its first turn in)
#-------------------------------------------------------------------------------
BattleHandlers::EORHealingAbility.add(:POISONABSORB,
  proc { |ability, battler, battle|
    next if battler.turnCount == 0 || !battler.canHeal?
    next if !KIFER::TerrainEnrage.toxic_affected?(battler)
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.pbRecoverHP([battler.totalhp / 8, 1].max)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

# Last: per-target wrappers for every move class loaded so far (this file's
# own move changes included)
KIFER::TerrainEnrage.wrap_all_moves

# Cosmic Dust (029): an enraged foe's rampage damage x2
if defined?(KIFER::BatchJ)
  class << KIFER::TerrainEnrage
    alias kifer_j_enrage_recoil enrage_recoil unless method_defined?(:kifer_j_enrage_recoil)
    def enrage_recoil(user, targets, move)
      double = KIFER::BatchJ.cosmic_foe?(user)
      user.instance_variable_set(:@kifer_j_double_loss, true) if double
      begin
        kifer_j_enrage_recoil(user, targets, move)
      ensure
        user.instance_variable_set(:@kifer_j_double_loss, nil) if double
      end
    end
  end
end
