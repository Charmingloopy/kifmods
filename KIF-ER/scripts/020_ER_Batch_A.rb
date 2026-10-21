#===============================================================================
# KIF: Elite Redux – Elite Redux abilities, batch A
#   Mechanics follow Elite Redux 2.65 (its C source and in-game texts). Where
#   the public C source is older than 2.65 and differs from the 2.65 text, the
#   2.65 text is followed (noted on the ability).
#
#   Flock            – Flying moves x1.2, or x1.5 at 1/3 HP or less
#   Short Circuit    – Electric moves x1.2, or x1.5 at 1/3 HP or less
#   Grip Pincer      – contact moves: 50% to trap the target (like Wrap); vs a
#                      trapped target its moves always hit and ignore the
#                      target's Defense/Sp. Def changes
#   Hypnotist        – Hypnosis has 90% accuracy (2.65 text; old source: 100)
#   Air Blower       – on entry: 3-turn Tailwind
#   Power Core       – adds 20% of Defense to physical attacks, 20% of
#                      Sp. Def to special attacks
#   Loud Bang        – sound moves: 50% to confuse (2.65 text)
#   Gorilla Tactics  – physical moves x1.5, but locked into the first move used
#                      until it switches out
#   Generator        – charged on entry and when Electric Terrain starts: its
#                      next Electric attack x2
#   Overcharge       – its Electric moves hit Electric types super effectively
#                      and it can paralyze Electric types
#   Aurora Borealis  – Ice moves get STAB; Weather Ball is always Ice with
#                      double power; Aurora Veil works without hail; Blizzard
#                      never misses; no hail damage
#   Fighter          – Fighting moves x1.2, or x1.5 at 1/3 HP or less
#   Perfectionist    – moves of 50 BP or less: crit stage +1; 25 BP or less:
#                      also +1 priority
#   Aerialist        – Levitate (Ground immunity, not grounded) + Flying moves
#                      x1.25 + Flock
#   Exploit Weakness – vs a statused foe, hits its lower defensive stat (2.65
#                      text; old source: x1.25 damage)
#   Natural Recovery – on switching out: cures its status and heals 1/3 HP
#   Sun Worship      – on entry in sun (any sun: Sun or primal Harsh Sun): its
#                      highest stat +1
#   Bone Zone        – bone moves ignore type immunities (and Levitate etc.),
#                      and resisted hits do x2
#   Dragonslayer     – x1.5 damage to Dragon types; Dragon-type attackers do
#                      x0.5 damage to it
#   Hubris           – a KO raises its Sp. Atk (like Moxie)
#   Neurotoxin       – when it poisons a foe, the foe's Attack, Sp. Atk and
#                      Speed drop by 1
#   Sighting System  – its moves always hit; moves under 80% accuracy get -3
#                      priority
#   Sweeping Edge    – slashing moves never miss and hit both foes (once each)
#   Atlas            – on entry: Gravity for 8 turns
#   Cud Chew         – a berry it eats is eaten again at the end of the next
#                      turn
#   Fungal Infection – its contact moves Leech Seed the target
#   Magical Dust     – contact either way makes the other Pokémon pure Psychic
#                      (2.65 text; old source added Psychic as a 3rd type)
#   Quick Draw       – 30% chance to move first in its priority bracket
#   Sweet Dreams     – heals 1/8 HP each turn while asleep; immune to Bad
#                      Dreams
#   Wishmaker        – on entry: Wish (3 times per battle)
#
#   Left out at first, now coded in 030-035 (fog, frostbite/bleeding,
#   fear, Toxic Terrain/enrage, one-offs).
#===============================================================================
KIFER.er_code(:FLOCK, :SHORTCIRCUIT, :GRIPPINCER, :HYPNOTIST, :AIRBLOWER, :POWERCORE,
                :LOUDBANG, :GORILLATACTICS, :GENERATOR, :OVERCHARGE, :AURORABOREALIS,
                :FIGHTER, :PERFECTIONIST, :AERIALIST, :EXPLOITWEAKNESS, :NATURALRECOVERY,
                :SUNWORSHIP, :BONEZONE, :DRAGONSLAYER, :HUBRIS, :NEUROTOXIN,
                :SIGHTINGSYSTEM, :SWEEPINGEDGE, :ATLAS, :CUDCHEW, :FUNGALINFECTION,
                :MAGICALDUST, :QUICKDRAW, :SWEETDREAMS, :WISHMAKER)

module KIFER
  module BatchA
    # Elite Redux's bone moves (Bone Zone)
    BONE_MOVES = [:BONECLUB, :BONEMERANG, :BONERUSH, :SHADOWBONE].freeze

    # Flock / Short Circuit / Fighter and the like: x1.2, or x1.5 at 1/3 HP or less
    def self.pinch_boost(user)
      return (user.hp <= user.totalhp / 3) ? 1.5 : 1.2
    end

    def self.bone_zone?(user, move)
      return false unless user && move
      return BONE_MOVES.include?(move.id) && user.hasActiveAbility?(:BONEZONE)
    end

    def self.sweeping_edge?(user, move)
      return false unless user && move
      return KIFER::SLICING_MOVES.include?(move.id) && user.hasActiveAbility?(:SWEEPINGEDGE)
    end

    # Power Fists (024), Elude and Blur (027): another stat stands in for the
    # defense stat while the block runs (the outer hook wins); the defense
    # hooks below still work on it
    def self.def_stat(move, s)
      old = move.instance_variable_get(:@kifer_def_stat)
      move.instance_variable_set(:@kifer_def_stat, old || s)
      begin
        return yield
      ensure
        move.instance_variable_set(:@kifer_def_stat, old)
      end
    end

    # Defense stat and stage after Power Fists / Elude / Blur, Exploit
    # Weakness and Grip Pincer
    def self.defense_stats(user, target, stat, stage, move = nil)
      return stat, stage unless user && target
      s = move && move.instance_variable_get(:@kifer_def_stat)
      stat, stage = ((s == :SPEED) ? target.speed : target.spdef), target.stages[s] + 6 if s
      if target.status != :NONE && user.hasActiveAbility?(:EXPLOITWEAKNESS)
        low = KIFER::BatchD.staged(target, :SPECIAL_DEFENSE) < KIFER::BatchD.staged(target, :DEFENSE)
        stat, stage = low ? [target.spdef, target.stages[:SPECIAL_DEFENSE] + 6] : [target.defense, target.stages[:DEFENSE] + 6]
      end
      if target.effects[PBEffects::Trapping] > 0 && user.hasActiveAbility?(:GRIPPINCER)
        stage = 6
      end
      return stat, stage
    end

    # Generator's charge
    def self.charge(battler, name)
      return if battler.fainted?
      battle = battler.battle
      battle.pbShowAbilitySplash(battler, false, true, name)
      battler.instance_variable_set(:@kifer_a_charged, true)
      battle.pbDisplay(_INTL("{1} began charging power!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    end

    # Gravity from an ability on entry (Atlas, Gravity Well 024), as the move
    # Gravity does; nothing if there is Gravity already
    def self.gravity(battler, ability, turns)
      battle = battler.battle
      return if battle.field.effects[PBEffects::Gravity] > 0
      battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
      battle.field.effects[PBEffects::Gravity] = turns
      battle.pbDisplay(_INTL("Gravity intensified!"))
      battle.pbHideAbilitySplash(battler)
      # brings down anything in the air
      battle.eachBattler do |b|
        showMessage = false
        if b.inTwoTurnAttack?("0C9", "0CC", "0CE")   # Fly/Bounce/Sky Drop
          b.effects[PBEffects::TwoTurnAttack] = nil
          battle.pbClearChoice(b.index) if !b.movedThisRound?
          showMessage = true
        end
        if b.effects[PBEffects::MagnetRise] > 0 ||
           b.effects[PBEffects::Telekinesis] > 0 ||
           b.effects[PBEffects::SkyDrop] >= 0
          b.effects[PBEffects::MagnetRise]  = 0
          b.effects[PBEffects::Telekinesis] = 0
          b.effects[PBEffects::SkyDrop]     = -1
          showMessage = true
        end
        battle.pbDisplay(_INTL("{1} couldn't stay airborne because of gravity!", b.pbThis)) if showMessage
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Flock, Short Circuit, Fighter – type boost, bigger at 1/3 HP or less
# Aerialist – Flying moves x1.25, then Flock's boost
#-------------------------------------------------------------------------------
{ :FLOCK => :FLYING, :SHORTCIRCUIT => :ELECTRIC, :FIGHTER => :FIGHTING }.each do |abil, t|
  BattleHandlers::DamageCalcUserAbility.add(abil,
    proc { |ability, user, target, move, mults, baseDmg, type|
      mults[:base_damage_multiplier] *= KIFER::BatchA.pinch_boost(user) if type == t
    }
  )
end

BattleHandlers::DamageCalcUserAbility.add(:AERIALIST,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :FLYING
    mults[:base_damage_multiplier] *= 1.25 * KIFER::BatchA.pinch_boost(user)
  }
)

#-------------------------------------------------------------------------------
# Aerialist – Ground moves miss it, like Levitate
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:AERIALIST,
  proc { |ability, user, target, move, type, battle|
    next false if type != :GROUND || !move.damagingMove? || move.hitsFlyingTargets?
    next false if !target.airborne?
    next false if KIFER::BatchA.bone_zone?(user, move)
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("{1} avoided the attack!", target.pbThis))
    battle.pbHideAbilitySplash(target)
    next true
  }
)

#-------------------------------------------------------------------------------
# Gorilla Tactics – physical moves x1.5 (the move lock is further down)
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:GORILLATACTICS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if move.physicalMove?
  }
)

#-------------------------------------------------------------------------------
# Dragonslayer – x1.5 vs Dragon types; Dragon-type attackers do x0.5 to it
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:DRAGONSLAYER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if target.pbHasType?(:DRAGON)
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:DRAGONSLAYER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.5 if user.pbHasType?(:DRAGON)
  }
)

#-------------------------------------------------------------------------------
# Aurora Borealis – Ice moves get STAB (x2 with Adaptability) when they don't
# already have it
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:AURORABOREALIS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :ICE || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

#-------------------------------------------------------------------------------
# Bone Zone – resisted bone moves do x2
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:BONEZONE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next unless KIFER::BatchA::BONE_MOVES.include?(move.id)
    eff = move.pbCalcTypeMod(type, user, target)
    next if eff <= 0
    mults[:final_damage_multiplier] *= 2 if eff.to_f / Effectiveness::NORMAL_EFFECTIVE <= 0.5
  }
)

#-------------------------------------------------------------------------------
# Hypnotist – Hypnosis has 90% accuracy (stat stages still count)
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcUserAbility.add(:HYPNOTIST,
  proc { |ability, mods, user, target, move, type|
    next if move.id != :HYPNOSIS || mods[:base_accuracy] <= 0
    mods[:base_accuracy] = 90 if mods[:base_accuracy] < 90
  }
)

#-------------------------------------------------------------------------------
# Sighting System – its moves always hit
# Grip Pincer – its moves always hit a trapped target
# Sweeping Edge – slashing moves always hit
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcUserAbility.add(:SIGHTINGSYSTEM,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0
  }
)

BattleHandlers::AccuracyCalcUserAbility.add(:GRIPPINCER,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0 if target.effects[PBEffects::Trapping] > 0
  }
)

BattleHandlers::AccuracyCalcUserAbility.add(:SWEEPINGEDGE,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0 if KIFER::SLICING_MOVES.include?(move.id)
  }
)

#-------------------------------------------------------------------------------
# Sighting System – moves under 80% accuracy get -3 priority
# Perfectionist – moves of 25 BP or less get +1 priority
#-------------------------------------------------------------------------------
BattleHandlers::PriorityChangeAbility.add(:SIGHTINGSYSTEM,
  proc { |ability, battler, move, pri|
    next pri - 3 if move.accuracy > 0 && move.accuracy < 80
    next pri
  }
)

BattleHandlers::PriorityChangeAbility.add(:PERFECTIONIST,
  proc { |ability, battler, move, pri|
    next pri + 1 if move.baseDamage > 0 && move.baseDamage <= 25
    next pri
  }
)

#-------------------------------------------------------------------------------
# Perfectionist – moves of 50 BP or less: crit stage +1
#   The crit handler isn't given the move, so it is noted while the game
#   works out a critical hit.
#-------------------------------------------------------------------------------
module KIFER
  module BatchA
    @crit_move = nil
    class << self; attr_accessor :crit_move; end
  end
end

BattleHandlers::CriticalCalcUserAbility.add(:PERFECTIONIST,
  proc { |ability, user, target, c|
    m = KIFER::BatchA.crit_move
    next c + 1 if m && m.baseDamage > 0 && m.baseDamage <= 50
    next c
  }
)

#-------------------------------------------------------------------------------
# Quick Draw – 30% chance to move first in its priority bracket
#-------------------------------------------------------------------------------
BattleHandlers::PriorityBracketChangeAbility.add(:QUICKDRAW,
  proc { |ability, battler, subPri, battle|
    # A copy that doesn't roll (another copy already worked) leaves the flag,
    # so the "moved first" message still shows
    next subPri if subPri >= 1
    ch = battle.choices[battler.index]
    if ch && ch[0] == :UseMove && ch[2] && ch[2].statusMove?   # not with status moves
      battler.instance_variable_set(:@kifer_a_quickdraw, false)
      next subPri
    end
    if battle.pbRandom(100) < 30
      battler.instance_variable_set(:@kifer_a_quickdraw, true)
      next 1
    end
    battler.instance_variable_set(:@kifer_a_quickdraw, false)
    next subPri
  }
)

BattleHandlers::PriorityBracketUseAbility.add(:QUICKDRAW,
  proc { |ability, battler, battle|
    next unless battler.instance_variable_get(:@kifer_a_quickdraw)
    battler.instance_variable_set(:@kifer_a_quickdraw, false)
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("{1} moved first!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Hubris – a KO raises its Sp. Atk (like Moxie)
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:HUBRIS,
  proc { |ability, user, targets, move, battle|
    next if battle.pbAllFainted?(user.idxOpposingSide)
    numFainted = 0
    targets.each { |b| numFainted += 1 if b.damageState.fainted }
    next if numFainted == 0 || !user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user)
    user.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, numFainted, user, true, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Grip Pincer – contact moves: 50% chance to trap the target (like Wrap)
#   Same turns and damage as PIF's Wrap (Grip Claw and Binding Band count).
#   The end-of-turn message names Wrap.
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:GRIPPINCER,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || target.index == user.index
    next if !move.pbContactMove?(user)
    next if target.effects[PBEffects::Trapping] > 0
    next if battle.pbRandom(2) != 0
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    if user.hasActiveItem?(:GRIPCLAW)
      target.effects[PBEffects::Trapping] = (Settings::MECHANICS_GENERATION >= 5) ? 8 : 6
    else
      target.effects[PBEffects::Trapping] = 5 + battle.pbRandom(2)
    end
    target.effects[PBEffects::TrappingMove] = :WRAP
    target.effects[PBEffects::TrappingUser] = user.index
    battle.pbDisplay(_INTL("{1} was wrapped by {2}!", target.pbThis, user.pbThis(true)))
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Loud Bang – sound moves: 50% chance to confuse
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:LOUDBANG,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || !KIFER.sound_move?(move)
    next if battle.pbRandom(100) >= 50
    next if !target.pbCanConfuse?(user, false, move)
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    target.pbConfuse
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Fungal Infection – contact moves Leech Seed the target
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:FUNGALINFECTION,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || target.index == user.index
    next if !move.pbContactMove?(user)
    next if target.pbHasType?(:GRASS) || target.effects[PBEffects::LeechSeed] >= 0
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    target.effects[PBEffects::LeechSeed] = user.index
    battle.pbDisplay(_INTL("{1} was seeded!", target.pbThis))
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Magical Dust – contact (its attack or the foe's) makes the other Pokémon
# pure Psychic
#-------------------------------------------------------------------------------
module KIFER
  module BatchA
    def self.magical_dust(bearer, other, move, name)
      battle = bearer.battle
      return if other.fainted? || other.index == bearer.index
      return if other.pbHasType?(:PSYCHIC) && !other.pbHasOtherType?(:PSYCHIC)
      battle.pbShowAbilitySplash(bearer, false, true, name)
      other.pbChangeTypes(:PSYCHIC)
      battle.pbDisplay(_INTL("{1} transformed into the {2} type!", other.pbThis,
                             GameData::Type.get(:PSYCHIC).name))
      battle.pbHideAbilitySplash(bearer)
    end
  end
end

BattleHandlers::UserAbilityOnHit.add(:MAGICALDUST,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    KIFER::BatchA.magical_dust(user, target, move, KIFER.ability_name(ability))
  }
)

BattleHandlers::TargetAbilityOnHit.add(:MAGICALDUST,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user) || !user.affectedByContactEffect?
    KIFER::BatchA.magical_dust(target, user, move, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Air Blower – on entry: 3-turn Tailwind (if its side has none)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:AIRBLOWER,
  proc { |ability, battler, battle|
    next if battler.pbOwnSide.effects[PBEffects::Tailwind] > 0
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.pbOwnSide.effects[PBEffects::Tailwind] = 3
    battle.pbDisplay(_INTL("The Tailwind blew from behind {1}!", battler.pbTeam(true)))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Atlas – on entry: Gravity for 8 turns (if there is none)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:ATLAS,
  proc { |ability, battler, battle|
    KIFER::BatchA.gravity(battler, ability, 8)
  }
)

#-------------------------------------------------------------------------------
# Sun Worship – on entry in sun: raises its highest stat (stages counted;
# ties go Attack, Defense, Sp. Atk, Sp. Def, Speed)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:SUNWORSHIP,
  proc { |ability, battler, battle|
    next unless [:Sun, :HarshSun].include?(battle.pbWeather)
    best = KIFER::BatchD.highest_stat(battler)
    next if !battler.pbCanRaiseStatStage?(best, battler)
    battler.pbRaiseStatStageByAbility(best, 1, battler, true, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Generator – charged on entry: its next Electric attack x2
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:GENERATOR,
  proc { |ability, battler, battle|
    KIFER::BatchA.charge(battler, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Wishmaker – on entry: Wish (3 times per battle for each Pokémon)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:WISHMAKER,
  proc { |ability, battler, battle|
    pos = battle.positions[battler.index]
    next if !pos || pos.effects[PBEffects::Wish] > 0
    uses = battle.instance_variable_get(:@kifer_a_wishes)
    uses = battle.instance_variable_set(:@kifer_a_wishes, Hash.new(0)) if !uses
    key = [battler.idxOwnSide, battler.pokemonIndex]
    next if uses[key] >= 3
    uses[key] += 1
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    pos.effects[PBEffects::Wish]       = 2
    pos.effects[PBEffects::WishAmount] = (battler.totalhp / 2.0).round
    pos.effects[PBEffects::WishMaker]  = battler.pokemonIndex
    battle.pbDisplay(_INTL("{1} made a wish!", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Natural Recovery – on switching out: cures its status and heals 1/3 HP
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchOut.add(:NATURALRECOVERY,
  proc { |ability, battler, endOfBattle|
    battler.status = :NONE
    next if endOfBattle
    battler.pbRecoverHP(battler.totalhp / 3, false, false)
  }
)

#-------------------------------------------------------------------------------
# Sweet Dreams – heals 1/8 HP each turn while asleep (or with Comatose)
#-------------------------------------------------------------------------------
BattleHandlers::EORHealingAbility.add(:SWEETDREAMS,
  proc { |ability, battler, battle|
    next if !battler.asleep? || !battler.canHeal?
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.pbRecoverHP([battler.totalhp / 8, 1].max)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

# Sweet Dreams – Bad Dreams doesn't hurt it. PIF's Bad Dreams, with that check
# added.
BattleHandlers::EOREffectAbility.add(:BADDREAMS,
  proc { |ability, battler, battle|
    battle.eachOtherSideBattler(battler.index) do |b|
      next if !b.near?(battler) || !b.asleep?
      next if b.hasActiveAbility?(:SWEETDREAMS)
      battle.pbShowAbilitySplash(battler)
      next if !b.takesIndirectDamage?(PokeBattle_SceneConstants::USE_ABILITY_SPLASH)
      oldHP = b.hp
      b.pbReduceHP(b.totalhp / 8)
      if PokeBattle_SceneConstants::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1} is tormented!", b.pbThis))
      else
        battle.pbDisplay(_INTL("{1} is tormented by {2}'s {3}!", b.pbThis,
                               battler.pbThis(true), battler.abilityName))
      end
      battle.pbHideAbilitySplash(battler)
      b.pbItemHPHealCheck
      b.pbAbilitiesOnDamageTaken(oldHP)
      b.pbFaint if b.fainted?
    end
  }
)

#-------------------------------------------------------------------------------
# Cud Chew – a berry it eats is eaten again at the end of the next turn
#-------------------------------------------------------------------------------
BattleHandlers::EOREffectAbility.add(:CUDCHEW,
  proc { |ability, battler, battle|
    cc = battler.instance_variable_get(:@kifer_a_cudchew)
    next if !cc
    if cc[1] > 0
      cc[1] -= 1
      next
    end
    battler.instance_variable_set(:@kifer_a_cudchew, nil)
    next if battler.fainted?
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbDisplay(_INTL("{1} ate its {2} again!", battler.pbThis, GameData::Item.get(cc[0]).name))
    battler.pbHeldItemTriggerCheck(cc[0], false)
    battle.pbHideAbilitySplash(battler)
  }
)

#===============================================================================
# Game method hooks
#===============================================================================
class PokeBattle_Battler
  # Batch A's per-battler states end when it leaves the field
  alias kifer_a_pbInitEffects pbInitEffects unless method_defined?(:kifer_a_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_a_pbInitEffects(batonPass)
    @kifer_a_gorilla   = nil
    @kifer_a_charged   = false
    @kifer_a_cudchew   = nil
    @kifer_a_quickdraw = false
  end

  #-----------------------------------------------------------------------------
  # Gorilla Tactics – locked into the first move it uses (like a Choice item)
  # Generator – the charge is used up by an Electric attack
  #-----------------------------------------------------------------------------
  alias kifer_a_pbEndTurn pbEndTurn unless method_defined?(:kifer_a_pbEndTurn)
  def pbEndTurn(choice)
    kifer_a_pbEndTurn(choice)
    # (not locked by a move one of its abilities used, 023)
    if !@kifer_a_gorilla && !KIFER.in_extra_move?(self) && hasActiveAbility?(:GORILLATACTICS)
      if @lastMoveUsed && pbHasMove?(@lastMoveUsed)
        @kifer_a_gorilla = @lastMoveUsed
      elsif @lastRegularMoveUsed && pbHasMove?(@lastRegularMoveUsed)
        @kifer_a_gorilla = @lastRegularMoveUsed
      end
    end
    if @kifer_a_charged && @lastMoveUsed && @lastMoveUsedType == :ELECTRIC &&
       GameData::Move.get(@lastMoveUsed).category != 2
      @kifer_a_charged = false
    end
  end

  alias kifer_a_pbCanChooseMove? pbCanChooseMove? unless method_defined?(:kifer_a_pbCanChooseMove?)
  def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
    lock = @kifer_a_gorilla
    if lock && move.id != lock && pbHasMove?(lock) && !KIFER.in_extra_move?(self) &&
       hasActiveAbility?(:GORILLATACTICS)
      if showMessages
        msg = _INTL("{1} can only use {2}!", pbThis, GameData::Move.get(lock).name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    return kifer_a_pbCanChooseMove?(move, commandPhase, showMessages, specialUsage)
  end

  #-----------------------------------------------------------------------------
  # Aerialist – in the air like Levitate (Gravity, Iron Ball, Ingrain and Smack
  # Down still ground it)
  #-----------------------------------------------------------------------------
  alias kifer_a_airborne? airborne? unless method_defined?(:kifer_a_airborne?)
  def airborne?
    return true if kifer_a_airborne?
    return false if hasActiveItem?(:IRONBALL)
    return false if @effects[PBEffects::Ingrain] || @effects[PBEffects::SmackDown]
    return false if @battle.field.effects[PBEffects::Gravity] > 0
    return KIFER.on_field?(@battle, :AERIALIST) && hasActiveAbility?(:AERIALIST) && !@battle.moldBreaker
  end

  #-----------------------------------------------------------------------------
  # Aurora Borealis – no hail damage
  #-----------------------------------------------------------------------------
  alias kifer_a_takesHailDamage? takesHailDamage? unless method_defined?(:kifer_a_takesHailDamage?)
  def takesHailDamage?
    return false unless kifer_a_takesHailDamage?
    return !hasActiveAbility?(:AURORABOREALIS)
  end

  #-----------------------------------------------------------------------------
  # Overcharge – can paralyze Electric types (the type check is skipped while
  # the game asks whether it can paralyze)
  #-----------------------------------------------------------------------------
  alias kifer_a_pbCanInflictStatus? pbCanInflictStatus? unless method_defined?(:kifer_a_pbCanInflictStatus?)
  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
    if newStatus == :PARALYSIS && user && user.index != @index &&
       !@kifer_a_no_electric && user.hasActiveAbility?(:OVERCHARGE)
      @kifer_a_no_electric = true
      begin
        return kifer_a_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
      ensure
        @kifer_a_no_electric = false
      end
    end
    return kifer_a_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
  end

  alias kifer_a_pbHasType? pbHasType? unless method_defined?(:kifer_a_pbHasType?)
  def pbHasType?(type)
    return false if @kifer_a_no_electric && type == :ELECTRIC
    return kifer_a_pbHasType?(type)
  end

  #-----------------------------------------------------------------------------
  # Neurotoxin – poisoning a foe also lowers its Attack, Sp. Atk and Speed
  #-----------------------------------------------------------------------------
  alias kifer_a_pbInflictStatus pbInflictStatus unless method_defined?(:kifer_a_pbInflictStatus)
  def pbInflictStatus(newStatus, newStatusCount = 0, msg = nil, user = nil)
    kifer_a_pbInflictStatus(newStatus, newStatusCount, msg, user)
    return if newStatus != :POISON || !user || fainted?
    return if !user.opposes?(self) || !user.hasActiveAbility?(:NEUROTOXIN)
    stats = [:ATTACK, :SPECIAL_ATTACK, :SPEED].select { |s| pbCanLowerStatStage?(s, user) }
    return if stats.empty?
    @battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(:NEUROTOXIN))
    KIFER::BatchG.ability_drop { stats.each { |s| pbLowerStatStage(s, 1, user) } }   # an ability's drop: Subdue doesn't double it
    @battle.pbHideAbilitySplash(user)
  end

  #-----------------------------------------------------------------------------
  # Cud Chew – notes a berry it eats itself
  #-----------------------------------------------------------------------------
  alias kifer_a_pbHeldItemTriggered pbHeldItemTriggered unless method_defined?(:kifer_a_pbHeldItemTriggered)
  def pbHeldItemTriggered(item_to_use, own_item = true, fling = false)
    if own_item && !fling && item_to_use && hasActiveAbility?(:CUDCHEW) &&
       GameData::Item.get(item_to_use).is_berry?
      @kifer_a_cudchew = [GameData::Item.get(item_to_use).id, 1]
    end
    kifer_a_pbHeldItemTriggered(item_to_use, own_item, fling)
  end

  #-----------------------------------------------------------------------------
  # Bone Zone – bone moves get past Levitate, Air Balloon and the like
  #-----------------------------------------------------------------------------
  alias kifer_a_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget unless method_defined?(:kifer_a_pbSuccessCheckAgainstTarget)
  def pbSuccessCheckAgainstTarget(move, user, target)
    if KIFER::BatchA.bone_zone?(user, move)
      move.instance_variable_set(:@kifer_a_bonezone, true)
      begin
        return kifer_a_pbSuccessCheckAgainstTarget(move, user, target)
      ensure
        move.instance_variable_set(:@kifer_a_bonezone, false)
      end
    end
    return kifer_a_pbSuccessCheckAgainstTarget(move, user, target)
  end
end

class PokeBattle_Battle
  #-----------------------------------------------------------------------------
  # Generator – charges again when Electric Terrain starts
  #-----------------------------------------------------------------------------
  alias kifer_a_pbStartTerrain pbStartTerrain unless method_defined?(:kifer_a_pbStartTerrain)
  def pbStartTerrain(user, newTerrain, fixedDuration = true)
    old = @field.terrain
    kifer_a_pbStartTerrain(user, newTerrain, fixedDuration)
    return if old == @field.terrain || @field.terrain != :Electric
    eachBattler do |b|
      next if b.fainted? || !b.hasActiveAbility?(:GENERATOR)
      KIFER::BatchA.charge(b, KIFER.ability_name(:GENERATOR))
    end
  end
end

class PokeBattle_Move
  #-----------------------------------------------------------------------------
  # Overcharge – Electric is super effective on Electric
  # Bone Zone – bone moves ignore type immunities
  #-----------------------------------------------------------------------------
  alias kifer_a_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_a_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_a_pbCalcTypeModSingle(moveType, defType, user, target)
    if moveType == :ELECTRIC && defType == :ELECTRIC && user && user.hasActiveAbility?(:OVERCHARGE)
      ret = Effectiveness::SUPER_EFFECTIVE_ONE
    end
    if Effectiveness.ineffective_type?(moveType, defType) && KIFER::BatchA.bone_zone?(user, self)
      ret = Effectiveness::NORMAL_EFFECTIVE_ONE
    end
    return ret
  end

  alias kifer_a_hitsFlyingTargets? hitsFlyingTargets? unless method_defined?(:kifer_a_hitsFlyingTargets?)
  def hitsFlyingTargets?
    return true if @kifer_a_bonezone
    return kifer_a_hitsFlyingTargets?
  end

  #-----------------------------------------------------------------------------
  # Power Core – adds 20% of Defense (physical) or Sp. Def (special)
  #   Not with Speed Force or Juggernaut on the same hit (Elite Redux uses one
  #   or the other; Juggernaut wins).
  #-----------------------------------------------------------------------------
  alias kifer_a_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_a_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    stat, stage = kifer_a_pbGetAttackStats(user, target)
    if KIFER.on_field?(@battle, :POWERCORE) && user.hasActiveAbility?(:POWERCORE) &&
       !(physicalMove? && pbContactMove?(user) && user.hasActiveAbility?(:SPEEDFORCE)) &&
       !(defined?(KIFER::BatchH) && KIFER::BatchH.juggernaut?(self, user, target))
      stat += specialMove? ? (user.spdef * 0.2).floor : (user.defense * 0.2).floor
    end
    return stat, stage
  end

  #-----------------------------------------------------------------------------
  # Exploit Weakness – vs a statused foe, hits its lower defensive stat
  # Grip Pincer – ignores a trapped target's Defense/Sp. Def changes
  #-----------------------------------------------------------------------------
  alias kifer_a_pbGetDefenseStats pbGetDefenseStats unless method_defined?(:kifer_a_pbGetDefenseStats)
  def pbGetDefenseStats(user, target)
    stat, stage = kifer_a_pbGetDefenseStats(user, target)
    return KIFER::BatchA.defense_stats(user, target, stat, stage, self)
  end

  #-----------------------------------------------------------------------------
  # Notes the move for the crit handlers (Perfectionist; Precise Fist 021,
  # Fatal Precision 027)
  #-----------------------------------------------------------------------------
  alias kifer_a_pbIsCritical? pbIsCritical? unless method_defined?(:kifer_a_pbIsCritical?)
  def pbIsCritical?(user, target)
    old = KIFER::BatchA.crit_move
    KIFER::BatchA.crit_move = self
    begin
      return kifer_a_pbIsCritical?(user, target)
    ensure
      KIFER::BatchA.crit_move = old
    end
  end

  #-----------------------------------------------------------------------------
  # Sweeping Edge – slashing moves aimed at one Pokémon hit both foes
  #-----------------------------------------------------------------------------
  alias kifer_a_pbTarget pbTarget unless method_defined?(:kifer_a_pbTarget)
  def pbTarget(user)
    ret = kifer_a_pbTarget(user)
    if [:NearOther, :NearFoe].include?(ret.id) && KIFER::BatchA.sweeping_edge?(user, self)
      return GameData::Target.get(:AllNearFoes)
    end
    return ret
  end

  alias kifer_a_pbNumHits pbNumHits unless method_defined?(:kifer_a_pbNumHits)
  def pbNumHits(user, targets)
    n = kifer_a_pbNumHits(user, targets)
    return 1 if n > 1 && targets.length > 1 && KIFER::BatchA.sweeping_edge?(user, self)
    return n
  end

  #-----------------------------------------------------------------------------
  # Generator – charged: Electric attacks x2 (not on top of the move Charge)
  #-----------------------------------------------------------------------------
  alias kifer_a_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_a_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    kifer_a_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    if type == :ELECTRIC && user.instance_variable_get(:@kifer_a_charged) &&
       user.effects[PBEffects::Charge] == 0
      multipliers[:base_damage_multiplier] *= 2
    end
  end
end

# Psyshock and the like use their own defense stat; Exploit Weakness and Grip
# Pincer still apply
if defined?(PokeBattle_Move_122)
  class PokeBattle_Move_122
    alias kifer_a_122_pbGetDefenseStats pbGetDefenseStats unless method_defined?(:kifer_a_122_pbGetDefenseStats)
    def pbGetDefenseStats(user, target)
      stat, stage = kifer_a_122_pbGetDefenseStats(user, target)
      return KIFER::BatchA.defense_stats(user, target, stat, stage, self)
    end
  end
end

# Sweeping Edge – Dual Chop hits each foe once when it hits both
if defined?(PokeBattle_Move_0BD)
  class PokeBattle_Move_0BD
    alias kifer_a_0bd_pbNumHits pbNumHits unless method_defined?(:kifer_a_0bd_pbNumHits)
    def pbNumHits(user, targets)
      n = kifer_a_0bd_pbNumHits(user, targets)
      return 1 if n > 1 && targets.length > 1 && KIFER::BatchA.sweeping_edge?(user, self)
      return n
    end
  end
end

#-------------------------------------------------------------------------------
# Aurora Borealis – moves act as if it were hailing
#-------------------------------------------------------------------------------
# Weather Ball: always Ice-type with double power
if defined?(PokeBattle_Move_087)
  class PokeBattle_Move_087
    alias kifer_a_087_pbBaseType pbBaseType unless method_defined?(:kifer_a_087_pbBaseType)
    def pbBaseType(user)
      return :ICE if user && user.hasActiveAbility?(:AURORABOREALIS)
      return kifer_a_087_pbBaseType(user)
    end

    alias kifer_a_087_pbBaseDamage pbBaseDamage unless method_defined?(:kifer_a_087_pbBaseDamage)
    def pbBaseDamage(baseDmg, user, target)
      return baseDmg * 2 if user && user.hasActiveAbility?(:AURORABOREALIS)
      return kifer_a_087_pbBaseDamage(baseDmg, user, target)
    end
  end
end

# Aurora Veil: works without hail
if defined?(PokeBattle_Move_167)
  class PokeBattle_Move_167
    alias kifer_a_167_pbMoveFailed? pbMoveFailed? unless method_defined?(:kifer_a_167_pbMoveFailed?)
    def pbMoveFailed?(user, targets)
      if user.hasActiveAbility?(:AURORABOREALIS) && @battle.pbWeather != :Hail
        if user.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
          @battle.pbDisplay(_INTL("But it failed!"))
          return true
        end
        return false
      end
      return kifer_a_167_pbMoveFailed?(user, targets)
    end
  end
end

# Blizzard: never misses
if defined?(PokeBattle_Move_00D)
  class PokeBattle_Move_00D
    alias kifer_a_00d_pbBaseAccuracy pbBaseAccuracy unless method_defined?(:kifer_a_00d_pbBaseAccuracy)
    def pbBaseAccuracy(user, target)
      return 0 if user && user.hasActiveAbility?(:AURORABOREALIS)
      return kifer_a_00d_pbBaseAccuracy(user, target)
    end
  end
end
