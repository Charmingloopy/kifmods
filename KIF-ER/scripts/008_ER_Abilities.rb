#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch 1)
#   Each one is added to the game's ability list (GameData::Ability) once its
#   battle code is here, so it works as a choice ability and as an innate.
#   Until then it is shown on the Summary screen but does nothing (and a
#   choice falls back to PIF's ability).
#   Mechanics follow Elite Redux 2.65 (its C source and in-game texts).
#===============================================================================
module KIFER
  # Every ER-only ability, in data file order. An ability's id number is
  # ER_ID_BASE + its place here, so it never depends on which files are in.
  ER_ONLY    = ABILITY_TEXT.keys.select { |k| ABILITY_TEXT[k][:pif] == false }.freeze
  ER_ID_BASE = 9000   # id numbers well past PIF's own abilities
  ER_CODED   = []     # filled by KIFER.er_code in each abilities file

  # An abilities file calls this with the abilities it codes
  def self.er_code(*ids)
    ids.flatten.each do |id|
      unless ER_ONLY.include?(id)
        log("er_code: #{id.inspect} isn't an ER-only ability")
        next
      end
      ER_CODED << id unless ER_CODED.include?(id)
    end
    register_er_abilities
  end

  # Elite Redux's slashing moves (Keen Edge). Moves PIF doesn't have are skipped.
  SLICING_MOVES = [
    :GUILLOTINE, :CUT, :RAZORLEAF, :SLASH, :FALSESWIPE, :FURYCUTTER, :AERIALACE,
    :DRAGONCLAW, :LEAFBLADE, :NIGHTSLASH, :AIRSLASH, :XSCISSOR, :SHADOWCLAW,
    :PSYCHOCUT, :CROSSPOISON, :STONEEDGE, :DUALCHOP, :SACREDSWORD, :RAZORSHELL,
    :SECRETSWORD, :SOLARBLADE, :BEHEMOTHBLADE, :BREAKINGSWIPE, :METEORASSAULT,
    :EXCALIBUR, :AIRCUTTER, :FURYSWIPES, :RAZORWIND
  ].freeze

  # Elite Redux's punching, biting, kicking and sound moves. Every batch uses
  # these (with PIF's own move flags), so an ability sees the same moves as
  # another. Moves PIF doesn't have never match.
  PUNCH_MOVES = [
    :BULLETPUNCH, :CLOSECOMBAT, :COMETPUNCH, :DIZZYPUNCH, :DOUBLEIRONBASH,
    :DRAINPUNCH, :DYNAMICPUNCH, :FIREPUNCH, :FOCUSPUNCH, :HAMMERARM, :ICEHAMMER,
    :ICEPUNCH, :MACHPUNCH, :MEGAPUNCH, :METEORMASH, :NEEDLEARM, :PLASMAFISTS,
    :POISONJAB, :POWERUPPUNCH, :PSYCHICFANGS, :SEISMICFIST, :SHADOWPUNCH,
    :SKYUPPERCUT, :SURGINGSTRIKES, :THUNDERPUNCH, :WICKEDBLOW
  ].freeze
  BITE_MOVES = [
    :AQUAFANG, :BITE, :BUGBITE, :CRUNCH, :DEATHROLL, :FIREFANG, :FISHIOUSREND,
    :HYPERFANG, :ICEFANG, :IRONFANGS, :JAGGEDFANGS, :JAWLOCK, :LEECHLIFE,
    :LOVELYBITE, :PLUCK, :POISONFANG, :PSYCHICFANGS, :SHADOWFANGS, :SUPERFANG,
    :THUNDERFANG
  ].freeze
  KICK_MOVES = [   # ER 2.65's list (Striker)
    :STOMP, :DOUBLEKICK, :MEGAKICK, :JUMPKICK, :ROLLINGKICK, :LOWKICK,
    :HIJUMPKICK, :TRIPLEKICK, :BLAZEKICK, :HIGHHORSEPOWER, :TROPKICK,
    :PYROBALL, :TRIPLEAXEL, :THUNDEROUSKICK, :WHIRLINGSTRIKES, :TRIPLEARROWS,
    :RIDERKICK, :AXEKICK, :TRIPLETREMOR, :RUMBLEKICK
  ].freeze
  SOUND_MOVES = [
    :BOOMBURST, :BUGBUZZ, :CHATTER, :CLANGINGSCALES, :CLANGOROUSSOUL, :CONFIDE,
    :DISARMINGVOICE, :ECHOEDVOICE, :EERIESPELL, :GRASSWHISTLE, :GROWL, :HEALBELL,
    :HOWL, :HYPERVOICE, :METALSOUND, :NOBLEROAR, :OVERDRIVE, :PARTINGSHOT,
    :PERISHSONG, :RELICSONG, :ROAR, :ROAROFTIME, :SCREECH, :SING, :SNARL, :SNORE,
    :SPARKLINGARIA, :SUPERSONIC, :UPROAR, :ROUND, :SONICBOOM, :SYNCHRONOISE
  ].freeze

  # (punchingMove? also covers Mixed Martial Arts' Normal moves, 027)
  def self.punch_move?(move); return !!(PUNCH_MOVES.include?(move.id) || move.punchingMove?); end
  def self.bite_move?(move);  return !!(BITE_MOVES.include?(move.id) || move.bitingMove?); end
  def self.sound_move?(move); return !!(SOUND_MOVES.include?(move.id) || move.soundMove?); end

  # A move's PIF function code: an ER move coded as KERBnn (062) counts as the
  # PIF code it's built on in the drain / burn lists
  def self.pif_function(move)
    f = move.function
    return f unless f.is_a?(String) && f.start_with?("KERB") && defined?(KIFER::MoveFxAttacks)
    return KIFER::MoveFxAttacks::BASE[f] || f
  end

  def self.kick_move?(move)
    return true if KICK_MOVES.include?(move.id)
    return defined?(BatchH) && BatchH.mma_move?(move) ? true : false   # Mixed Martial Arts
  end

  # Adds the coded abilities to GameData::Ability. Safe to run more than once
  # (the game reloads its data on some screens).
  def self.register_er_abilities
    return 0 unless defined?(GameData::Ability)
    n = 0
    ER_CODED.each do |id|
      next if GameData::Ability::DATA[id] && !GameData::Ability::DATA[id].instance_variable_get(:@kifer_er)
      t = ABILITY_TEXT[id] || {}
      GameData::Ability.register({
        :id          => id,
        :id_number   => ER_ID_BASE + ER_ONLY.index(id),
        :name        => t[:name] || id.to_s,
        :description => t[:short] || ""
      })
      GameData::Ability::DATA[id].instance_variable_set(:@kifer_er, true)
      n += 1
    end
    return n
  end

  # Stat stage multipliers (stage + 6 is the index)
  STAGE_MUL = [2, 2, 2, 2, 2, 2, 2, 3, 4, 5, 6, 7, 8]
  STAGE_DIV = [8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 2, 2, 2]

  # Elite Redux's Speed stat for Speed Force (stages above 0: +50% each;
  # below 0: its own table)
  SPEED_FORCE_DROPS = { -1 => 0.66, -2 => 0.50, -3 => 0.40, -4 => 0.33, -5 => 0.28, -6 => 0.25 }

  def self.speed_force_speed(battler)
    stage = battler.stages[:SPEED]
    spd = battler.speed
    return (spd * (stage * 0.5 + 1)).floor if stage >= 0
    return (spd * SPEED_FORCE_DROPS[stage]).floor
  end

  # Mountaineer / Tectonize (022 / 021): runs the block (its entry) with entry
  # hazard damage off for it (PIF's Stealth Rock and Spikes ask
  # takesIndirectDamage?, below)
  def self.hazard_proof(battler)
    old = battler.instance_variable_get(:@kifer_hazard_proof)
    battler.instance_variable_set(:@kifer_hazard_proof, true)
    begin
      return yield
    ensure
      battler.instance_variable_set(:@kifer_hazard_proof, old)
    end
  end

  # Does a Pokémon on the field have this ability (main or innate)? Read live;
  # a quick first test for hooks that run on every move.
  def self.on_field?(battle, id)
    return false if !battle
    battle.battlers.each do |b|
      next if !b || b.fainted?
      return true if b.ability_id == id || (b.innate_ids && b.innate_ids.include?(id))
    end
    return false
  end

  #-----------------------------------------------------------------------------
  # Extra moves, shared by every batch: a move an ability uses outside the
  # battler's own turn (Cheap Tactics, Aftershock, Tag, Two Step, Surprise...)
  #-----------------------------------------------------------------------------
  # The flags the batches set while one of their extra moves runs
  EXTRA_MOVE_FLAGS = [:@kifer_extra_depth, :@kifer_d_in_extra, :@kifer_f_extra,
                      :@kifer_sp2_in_extra, :@kifer_h_twostep]

  def self.in_extra_move?(battler)
    return false if !battler
    EXTRA_MOVE_FLAGS.each do |v|
      x = battler.instance_variable_get(v)
      return true if x && x != 0
    end
    return false
  end

  # The priority the move would have if the battler had chosen it
  def self.extra_move_priority(user, move)
    pri = move.priority
    pri = BattleHandlers.triggerPriorityChangeAbility(user.ability, user, move, pri) if user.abilityActive?
    return pri
  rescue StandardError
    return move.priority
  end

  # Runs the block with the battler's choice holding the given priority (the
  # game reads it for Dazzling, Queenly Majesty, Psychic Terrain and Quick
  # Guard), then puts the old one back. The choice is made if it is missing.
  def self.with_priority(user, pri)
    battle = user.battle
    ch = battle.choices[user.index]
    if !ch.is_a?(Array)
      ch = [:None, 0, nil, -1]
      battle.choices[user.index] = ch
    end
    old = ch[4]
    ch[4] = pri
    begin
      return yield
    ensure
      ch[4] = old
    end
  end

  # Runs an extra move (the block): its own priority, not the one of the move
  # the battler chose this turn, and no Choice item lock from it
  def self.with_extra_move(user, move)
    depth = user.instance_variable_get(:@kifer_extra_depth) || 0
    user.instance_variable_set(:@kifer_extra_depth, depth + 1)
    begin
      return with_priority(user, extra_move_priority(user, move)) { yield }
    ensure
      user.instance_variable_set(:@kifer_extra_depth, depth)
    end
  end

  # pbUseMoveSimple for an ability's extra move
  def self.use_move_simple(user, move_id, target = -1)
    move = PokeBattle_Move.from_pokemon_move(user.battle, Pokemon::Move.new(move_id))
    move.pp = -1
    with_extra_move(user, move) { user.pbUseMove([:UseMove, -1, move, target], true) }
    user.battle.pbJudge
  end
end

# Names and descriptions of the mod's abilities come from the ER texts (the
# game's message files don't have them)
module GameData
  class Ability
    alias kifer_name name unless method_defined?(:kifer_name)
    def name
      return @real_name if @kifer_er
      return kifer_name
    end

    alias kifer_description description unless method_defined?(:kifer_description)
    def description
      return @real_description if @kifer_er
      return kifer_description
    end
  end
end

KIFER.er_code(:PREDATOR, :HYPERAGGRESSIVE, :IMPENETRABLE, :SELFSUFFICIENT, :NOCTURNAL,
                :OPPORTUNIST, :LETSROLL, :AERODYNAMICS, :SCARE, :SPEEDFORCE,
                :MYSTICPOWER, :KEENEDGE)
KIF::DataLoad.after_load_all("KIF-ER: Elite Redux abilities") { KIFER.register_er_abilities } if defined?(KIF::DataLoad)

#-------------------------------------------------------------------------------
# Predator – a KO with its attack heals 1/4 of its max HP (Soul Eater,
# Scavenger and Looter copy it)
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:PREDATOR,
  proc { |ability, user, targets, move, battle|
    next if user.fainted? || user.hp >= user.totalhp
    next unless targets.any? { |b| b.damageState.fainted }
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    user.pbRecoverHP(user.totalhp / 4)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", user.pbThis))
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Hyper Aggressive – attacks hit twice, the 2nd hit at 25% (same rules as
# PIF's Parental Bond, which also does the 25%)
#-------------------------------------------------------------------------------
class PokeBattle_Move
  alias kifer_pbNumHits pbNumHits unless method_defined?(:kifer_pbNumHits)
  def pbNumHits(user, targets)
    n = kifer_pbNumHits(user, targets)
    if n == 1 && user.hasActiveAbility?(:HYPERAGGRESSIVE) && pbDamagingMove? &&
       !chargingTurnMove? && targets.length == 1
      user.effects[PBEffects::ParentalBond] = 3
      return 2
    end
    return n
  end

  #-----------------------------------------------------------------------------
  # Speed Force – physical contact moves add 20% of its Speed to its Attack
  #-----------------------------------------------------------------------------
  alias kifer_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    stat, stage = kifer_pbGetAttackStats(user, target)
    # Magical Fists (025): Sp. Atk in place of Attack; additions below still count
    stat, stage = user.spatk, user.stages[:SPECIAL_ATTACK] + 6 if @kifer_f_magical
    if physicalMove? && KIFER.on_field?(@battle, :SPEEDFORCE) && pbContactMove?(user) &&
       user.hasActiveAbility?(:SPEEDFORCE)
      stat += (KIFER.speed_force_speed(user) * 0.2).floor
    end
    return stat, stage
  end
end

#-------------------------------------------------------------------------------
# Impenetrable – only attacks can damage it (like Magic Guard)
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_takesIndirectDamage? takesIndirectDamage? unless method_defined?(:kifer_takesIndirectDamage?)
  def takesIndirectDamage?(showMsg = false)
    return false if @kifer_hazard_proof
    # Mountaineer coming in: the first check is Stealth Rock's when rocks are up
    if @kifer_rock_proof
      @kifer_rock_proof = false
      return false if pbOwnSide.effects[PBEffects::StealthRock]
    end
    return false unless kifer_takesIndirectDamage?(showMsg)
    if hasActiveAbility?(:IMPENETRABLE)
      if showMsg
        @battle.pbShowAbilitySplash(self)
        if PokeBattle_SceneConstants::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis))
        else
          @battle.pbDisplay(_INTL("{1} is unaffected because of its {2}!", pbThis, abilityName))
        end
        @battle.pbHideAbilitySplash(self)
      end
      return false
    end
    return true
  end
end

#-------------------------------------------------------------------------------
# Self Sufficient – heals 1/16 of its max HP at the end of each turn (not on
# the turn it came in)
#-------------------------------------------------------------------------------
BattleHandlers::EORHealingAbility.add(:SELFSUFFICIENT,
  proc { |ability, battler, battle|
    next if battler.turnCount == 0 || !battler.canHeal?
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battler.pbRecoverHP([battler.totalhp / 16, 1].max)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Nocturnal – its Dark moves x1.25; Dark and Fairy moves hit it for x0.75
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:NOCTURNAL,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.25 if type == :DARK
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:NOCTURNAL,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.75 if type == :DARK || type == :FAIRY
  }
)

#-------------------------------------------------------------------------------
# Opportunist – +1 priority when the move will hit a foe at half HP or less
#   * Aimed at one foe: only that foe counts.
#   * Hits several foes (or a random one): any foe it can reach counts.
#   * Moves that don't hit a foe (self, ally, hazards, field): no boost.
#   Priority is worked out once per move, before it is used, so it can't be
#   different for each foe a spread move hits.
#-------------------------------------------------------------------------------
module KIFER
  def self.opportunist_targets(battler, move)
    battle = battler.battle
    choice = battle.choices[battler.index] rescue nil
    idx = choice ? choice[3] : -1
    if idx.is_a?(Integer) && idx >= 0
      b = battle.battlers[idx]
      return (b && b.opposes?(battler)) ? [b] : []
    end
    t = move.pbTarget(battler) rescue nil
    return [] unless t && t.targets_foe
    foes = []
    battle.eachOtherSideBattler(battler.index) do |b|
      foes << b if t.long_range || b.near?(battler)
    end
    return foes
  end
end

BattleHandlers::PriorityChangeAbility.add(:OPPORTUNIST,
  proc { |ability, battler, move, pri|
    low = KIFER.opportunist_targets(battler, move).any? { |b| !b.fainted? && b.hp <= b.totalhp / 2 }
    next low ? pri + 1 : pri
  }
)

#-------------------------------------------------------------------------------
# Let's Roll – on entry: Defense +1 and Defense Curl
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:LETSROLL,
  proc { |ability, battler, battle|
    name = KIFER.ability_name(ability)
    if battler.pbCanRaiseStatStage?(:DEFENSE, battler)
      battler.pbRaiseStatStageByAbility(:DEFENSE, 1, battler, true, name)
    end
    battler.effects[PBEffects::DefenseCurl] = true
  }
)

#-------------------------------------------------------------------------------
# Scare – on entry: lowers the Sp. Atk of the foes next to it
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:SCARE,
  proc { |ability, battler, battle|
    name = KIFER.ability_name(ability)
    battle.pbShowAbilitySplash(battler, false, true, name)
    battle.eachOtherSideBattler(battler.index) do |b|
      next if !b.near?(battler)
      if b.effects[PBEffects::Substitute] > 0
        battle.pbDisplay(_INTL("{1} is protected by its substitute!", b.pbThis))
        next
      end
      b.pbLowerStatStageByAbility(:SPECIAL_ATTACK, 1, battler, false, false, name)
    end
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Aerodynamics – Flying moves don't hurt it and raise its Speed
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:AERODYNAMICS,
  proc { |ability, user, target, move, type, battle|
    next pbBattleMoveImmunityStatAbility(user, target, move, type, :FLYING, :SPEED, 1, battle)
  }
)

#-------------------------------------------------------------------------------
# Mystic Power – every move gets the 1.5x same-type boost (2x with
# Adaptability); moves that already have it don't get it twice
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:MYSTICPOWER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if !KIFER::BatchF.ability_stab?(user, type)
    next if defined?(PokeBattle_Confusion) && move.is_a?(PokeBattle_Confusion)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

#-------------------------------------------------------------------------------
# Keen Edge – slashing moves x1.3
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:KEENEDGE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER::SLICING_MOVES.include?(move.id)
  }
)
