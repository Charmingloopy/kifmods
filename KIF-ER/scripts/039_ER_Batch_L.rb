#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch L)
#   Mechanics follow the Elite Redux in-game texts (these abilities aren't in
#   the public C source).
#
#   Restraining Order – hit by a contact move: the attacker is dragged out for
#                       a random party member (as Red Card), once per switch-in
#   Rose Garden       – on entry: 2 layers of Toxic Spikes on the foes' side
#   Sand Titan        – Juggernaut + Sand Stream (8 turns, 12 with Smooth
#                       Rock); no sandstorm damage
#   Sepia Lens        – Tinted Lens + Sand Guard; no sandstorm damage
#   Sharp Edges       – contact attackers lose 1/6 of their max HP, every hit
#   Shattered Armor   – Battle Armor (no crits, hits x0.8) + Scrapyard
#   Shiny Lightning   – accuracy x1.2; Thunder never misses
#   Shocking Maw      – biting moves x1.3 + Shocking Jaws (50% paralysis)
#   Sinister Claws    – slicing moves x1.3 and special (Sp. Atk vs Sp. Def);
#                       they lower the target's Sp. Def by 1, once per turn
#                       per target
#   Sleek Scales      – adds 15% of its Speed to its Defense / Sp. Def
#                       (stages count, Choice Scarf doesn't, as Speed Force)
#   Spectral Shroud   – Spectralize + its moves (status moves too) have a 30%
#                       chance to badly poison the target
#   Spike Armor       – contact either way: 30% chance to bleed
#   Spinning Top      – after a Fighting move: Speed +1, its side's entry
#                       hazards are cleared
#   Steel Barrel      – no recoil from its moves (and Electric Burst's); enrage
#                       recoil is in 033. Crash damage and Explosion stay.
#   Sumo Guard        – Juggernaut + Thick Fat
#   Sumo Wrestler     – end of each 2nd turn on the field: a 20 power Circle
#                       Throw
#   Terminal Velocity – non-contact attacks add 20% of its Speed to its
#                       attacking stat (stages count, Choice Scarf doesn't)
#   Thunder Clouds    – after a special attack: a 35 power Thunderbolt
#   Toxic Shell       – Shell Armor (no crits, hits x0.8) + Poison Point (30%
#                       on contact, either way)
#   Trash Heap        – Corrosion + Toxic Spill
#   Tummyache         – Thick Fat + Corrosion
#   Unstable Core     – Power Core + Aftermath (ER's: KO'd by an attack, it
#                       explodes; its explosion moves always flinch)
#   Venom Crown       – Poison Point (30% on contact, either way) + Mighty Horn
#   Watch Your Step   – on entry: 2 layers of Spikes on the foes' side
#   Waterborne        – Aquatic + Adaptability
#   Wildfire          – on entry: a 50 power Fire Spin on a foe
#   Wind Chimes       – Amplifier + after a move hits it: a 30 power Hyper Voice
#   Witch Broom       – Hyper Aggressive + Hover (on entry: adds the Psychic
#                       type; floats like Levitate)
#   Wonder Scale      – Shed Skin + Wonder Skin (ER's: foes' damage boosting
#                       abilities don't work on it; Parental Bond and
#                       Multi-Headed still do)
#   Wrestle Showman   – Flying Press +10 power, and its hits Taunt the target
#   Yuki Onna         – Intimidate + Scare on entry; contact either way: 30%
#                       chance to infatuate (ER's infatuation, "New battle
#                       effects" setting)
#
#   "A + B" abilities use A's and B's own code where the mod has it, so they
#   act the same and stack the same way.
#
# Not coded yet:
#   (Rejection, Talon Trap: 042)
#   Thundercall   – its follow-up is Smite, which PIF doesn't have
#===============================================================================
KIFER.er_code(:RESTRAININGORDER, :ROSEGARDEN, :SANDTITAN, :SEPIALENS, :SHARPEDGES,
              :SHATTEREDARMOR, :SHINYLIGHTNING, :SHOCKINGMAW, :SINISTERCLAWS,
              :SLEEKSCALES, :SPECTRALSHROUD, :SPIKEARMOR, :SPINNINGTOP, :STEELBARREL,
              :SUMOGUARD, :SUMOWRESTLER, :TERMINALVELOCITY, :THUNDERCLOUDS,
              :TOXICSHELL, :TRASHHEAP, :TUMMYACHE, :UNSTABLECORE, :VENOMCROWN,
              :WATCHYOURSTEP, :WATERBORNE, :WILDFIRE, :WINDCHIMES, :WITCHBROOM,
              :WONDERSCALE, :WRESTLESHOWMAN, :YUKIONNA)

module KIFER
  module BatchL
    # Inline checks for A also see these "A + B" abilities
    COUNTS_AS = {
      :CORROSION    => [:TRASHHEAP, :TUMMYACHE],
      :ADAPTABILITY => [:WATERBORNE],
      :AMPLIFIER    => [:WINDCHIMES]
    }
    JUGGERNAUTS = [:SANDTITAN, :SUMOGUARD]
    SAND_PROOF  = [:SANDTITAN, :SEPIALENS]
    ARMORS      = [:SHATTEREDARMOR, :TOXICSHELL]

    def self.has?(battler, id)
      return KIFER::BatchH.has?(battler, id)
    end

    # Fort Knox / Wonder Skin: the target blocks the user's boosting abilities
    def self.blocked?(user, target)
      return false if !target || !defined?(KIFER::Specials2)
      return KIFER::Specials2.blocks?(user, target)
    end

    #---------------------------------------------------------------------------
    # Moves its abilities use once the move that set them off is over
    # (Thunder Clouds, Wind Chimes)
    #---------------------------------------------------------------------------
    def self.queue(battle)
      q = battle.instance_variable_get(:@kifer_l_queue)
      q = battle.instance_variable_set(:@kifer_l_queue, []) if !q
      return q
    end

    def self.add_follow(bearer, move_id, target_idx, power, ability, once = false)
      q = queue(bearer.battle)
      return if once && q.any? { |e| e[0].equal?(bearer) && e[5] == ability }
      q << [bearer, bearer.pokemon, move_id, target_idx, power, ability]
    end

    def self.run_follows(battle)
      q = queue(battle)
      return if q.empty?
      todo = q.dup
      q.clear
      todo.each do |b, pkmn, move_id, idx, power, ability|
        break if battle.decision > 0
        next if b.fainted? || !b.pokemon.equal?(pkmn)
        if idx >= 0
          t = battle.battlers[idx]
          next if !t || t.fainted?
        end
        KIFER::BatchF.use_extra_move(b, move_id, idx, power, ability)
      end
    end

    #---------------------------------------------------------------------------
    # Restraining Order
    #---------------------------------------------------------------------------
    def self.restraining_order(user, targets, move, switched)
      battle = user.battle
      return if user.fainted? || switched.include?(user.index)
      return if !move.pbContactMove?(user) || !user.affectedByContactEffect?
      targets.each do |b|
        next if b.index == user.index
        next if b.fainted? || switched.include?(b.index)
        ds = b.damageState
        next if ds.unaffected || ds.substitute || ds.calcDamage == 0
        next if b.instance_variable_get(:@kifer_l_ro_used)
        next if !b.hasActiveAbility?(:RESTRAININGORDER)
        newPkmn = battle.pbGetReplacementPokemonIndex(user.index, true)   # random
        next if newPkmn < 0
        b.instance_variable_set(:@kifer_l_ro_used, true)
        battle.pbShowAbilitySplash(b, false, true, KIFER.ability_name(:RESTRAININGORDER))
        battle.pbRecallAndReplace(user.index, newPkmn, true)
        battle.pbDisplay(_INTL("{1} was dragged out!", user.pbThis))
        battle.pbHideAbilitySplash(b)
        battle.pbClearChoice(user.index)   # the new Pokemon does nothing this round
        switched.push(user.index)
        battle.moldBreaker = false
        user.pbEffectsOnSwitchIn(true)
        return
      end
    end

    #---------------------------------------------------------------------------
    # Entry hazards (Rose Garden, Watch Your Step)
    #---------------------------------------------------------------------------
    def self.hazards(ability, battler, battle, effect, layers, max, msg)
      side = battler.pbOpposingSide
      return if side.effects[effect] >= max
      battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
      side.effects[effect] = [side.effects[effect] + layers, max].min
      battle.pbDisplay(_INTL(msg, battler.pbOpposingTeam(true)))
      battle.pbHideAbilitySplash(battler)
    end

    # Yuki Onna: Specials2.charm with a 30% chance
    def self.yuki_charm(ability, bearer, other, defending)
      return if !defined?(KIFER::Specials2) || !KIFER.feature_on?(:erlove)
      battle = bearer.battle
      return if bearer.fainted? || other.fainted? || bearer.equal?(other)
      return if other.effects[PBEffects::Attract] >= 0
      return if defending && !other.affectedByContactEffect?
      return if !other.pbCanAttract?(bearer, false)
      if !battle.moldBreaker
        veil = false
        other.eachAlly { |a| veil = true if a.hasActiveAbility?(:AROMAVEIL) }
        return if veil
      end
      return if battle.pbRandom(100) >= 30
      battle.pbShowAbilitySplash(bearer, false, true, KIFER.ability_name(ability))
      KIFER::Specials2.love = true
      begin
        other.pbAttract(bearer)
      ensure
        KIFER::Specials2.love = false
      end
      battle.pbHideAbilitySplash(bearer)
    end

    # Poison Point's ER version (30% on contact, either way), always on
    def self.poison_target(ability, user, target, move)
      KIFER::ERVersions.on_hit_target(ability, user, target, move, :POISON, 30, 0)
    end

    def self.poison_user(ability, user, target, move)
      KIFER::ERVersions.on_hit_user(ability, user, target, move, :POISON, 30, 0)
    end
  end
end

#-------------------------------------------------------------------------------
# Juggernaut's attack boost also for Sand Titan and Sumo Guard
#-------------------------------------------------------------------------------
class << KIFER::BatchH
  alias kifer_l_juggernaut? juggernaut? unless method_defined?(:kifer_l_juggernaut?)
  def juggernaut?(move, user, target)
    return true if kifer_l_juggernaut?(move, user, target)
    return false unless move.physicalMove? && move.pbContactMove?(user)
    return false unless KIFER::BatchL::JUGGERNAUTS.any? { |a| KIFER.on_field?(user.battle, a) && has?(user, a) }
    return false if KIFER::BatchH::JUGGERNAUT_BEFORE.any? { |a| has?(user, a) }
    return false if target && fort_knox?(user, target)
    return true
  end

  # Wonder Scale blocks like Fort Knox
  alias kifer_l_fort_knox? fort_knox? unless method_defined?(:kifer_l_fort_knox?)
  def fort_knox?(user, target)
    return true if kifer_l_fort_knox?(user, target)
    return false if !user || !target || user.equal?(target)
    return false unless target.respond_to?(:opposes?) && KIFER.on_field?(target.battle, :WONDERSCALE)
    return false unless target.opposes?(user)
    return false if target.battle.moldBreaker
    return has?(target, :WONDERSCALE)
  end
end

class PokeBattle_Battler
  # Sand Titan / Sepia Lens: no sandstorm damage
  alias kifer_l_takesSandstormDamage? takesSandstormDamage? unless method_defined?(:kifer_l_takesSandstormDamage?)
  def takesSandstormDamage?
    return false if !kifer_l_takesSandstormDamage?
    return false if hasActiveAbility?(KIFER::BatchL::SAND_PROOF)
    return true
  end

  # Witch Broom (Hover): floats like Levitate
  alias kifer_l_airborne? airborne? unless method_defined?(:kifer_l_airborne?)
  def airborne?
    return true if kifer_l_airborne?
    return false if !hasActiveAbility?(:WITCHBROOM)   # the usual case: done
    return false if hasActiveItem?(:IRONBALL)
    return false if @effects[PBEffects::Ingrain] || @effects[PBEffects::SmackDown]
    return false if @battle.field.effects[PBEffects::Gravity] > 0
    return !@battle.moldBreaker && KIFER.on_field?(@battle, :WITCHBROOM) && KIFER::BatchL.has?(self, :WITCHBROOM)
  end

  # Restraining Order: once per switch-in
  alias kifer_l_pbInitEffects pbInitEffects unless method_defined?(:kifer_l_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_l_pbInitEffects(batonPass)
    @kifer_l_ro_used = false
  end

  alias kifer_l_pbEffectsAfterMove2 pbEffectsAfterMove2 unless method_defined?(:kifer_l_pbEffectsAfterMove2)
  def pbEffectsAfterMove2(user, targets, move, numHits, switchedBattlers)
    kifer_l_pbEffectsAfterMove2(user, targets, move, numHits, switchedBattlers)
    if KIFER.on_field?(@battle, :RESTRAININGORDER)
      KIFER::BatchL.restraining_order(user, targets, move, switchedBattlers)
    end
  end

  #-----------------------------------------------------------------------------
  # Sinister Claws: its slicing moves are special while it uses them.
  # Thunder Clouds / Wind Chimes: their moves come once the move is over.
  #-----------------------------------------------------------------------------
  alias kifer_l_pbUseMove pbUseMove unless method_defined?(:kifer_l_pbUseMove)
  def pbUseMove(choice, specialUsage = false)
    depth = @battle.instance_variable_get(:@kifer_l_depth) || 0
    move = choice[2]
    claws = move.is_a?(PokeBattle_Move) && move.physicalMove? &&
            KIFER::SLICING_MOVES.include?(move.id) && hasActiveAbility?(:SINISTERCLAWS)
    if claws
      old_cat = move.instance_variable_get(:@category)
      move.instance_variable_set(:@category, 1)
    end
    @battle.instance_variable_set(:@kifer_l_depth, depth + 1)
    begin
      kifer_l_pbUseMove(choice, specialUsage)
    ensure
      move.instance_variable_set(:@category, old_cat) if claws
      @battle.instance_variable_set(:@kifer_l_depth, depth)
    end
    KIFER::BatchL.run_follows(@battle) if depth == 0
  end
end

class PokeBattle_Move
  #-----------------------------------------------------------------------------
  # Terminal Velocity – non-contact attacks add 20% of its Speed
  # Unstable Core (Power Core) – adds 20% of Defense / Sp. Def
  #-----------------------------------------------------------------------------
  alias kifer_l_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_l_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    stat, stage = kifer_l_pbGetAttackStats(user, target)
    return stat, stage if !damagingMove?
    tv = !pbContactMove?(user) && user.hasActiveAbility?(:TERMINALVELOCITY)
    uc = user.hasActiveAbility?(:UNSTABLECORE)
    return stat, stage if (!tv && !uc) || KIFER::BatchL.blocked?(user, target)   # cheap checks first
    if tv
      stat += (KIFER.speed_force_speed(user) * 0.2).floor
    end
    # same rules as Power Core (020): not with Speed Force or Juggernaut
    if uc &&
       !user.hasActiveAbility?(:POWERCORE) &&
       !(physicalMove? && pbContactMove?(user) && user.hasActiveAbility?(:SPEEDFORCE)) &&
       !KIFER::BatchH.juggernaut?(self, user, target)
      stat += specialMove? ? (user.spdef * 0.2).floor : (user.defense * 0.2).floor
    end
    return stat, stage
  end

  #-----------------------------------------------------------------------------
  # Witch Broom (Hyper Aggressive) – attacks hit twice, the 2nd at 25%, no
  # flinch on the 2nd (same rules as 008 / 024)
  #-----------------------------------------------------------------------------
  alias kifer_l_pbNumHits pbNumHits unless method_defined?(:kifer_l_pbNumHits)
  def pbNumHits(user, targets)
    n = kifer_l_pbNumHits(user, targets)
    if n == 1 && pbDamagingMove? && !chargingTurnMove? && targets.length == 1 &&
       user.hasActiveAbility?(:WITCHBROOM) && !KIFER::BatchL.blocked?(user, targets[0])
      user.effects[PBEffects::ParentalBond] = 3
      user.instance_variable_set(:@kifer_e_nf2, true)
      return 2
    end
    return n
  end

  #-----------------------------------------------------------------------------
  # Trash Heap / Tummyache (Corrosion) – Poison moves are super effective on Steel
  #-----------------------------------------------------------------------------
  alias kifer_l_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_l_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_l_pbCalcTypeModSingle(moveType, defType, user, target)
    if moveType == :POISON && defType == :STEEL && user &&
       user.hasActiveAbility?(KIFER::BatchL::COUNTS_AS[:CORROSION])
      ret = Effectiveness::SUPER_EFFECTIVE_ONE
    end
    return ret
  end

  #-----------------------------------------------------------------------------
  # Unstable Core (Aftermath) – its explosion moves always flinch
  #-----------------------------------------------------------------------------
  alias kifer_l_pbFlinchChance pbFlinchChance unless method_defined?(:kifer_l_pbFlinchChance)
  def pbFlinchChance(user, target)
    ret = kifer_l_pbFlinchChance(user, target)
    if ret < 100 && defined?(KIFER::ERVersions) && KIFER::ERVersions.explosion_move?(self) &&
       user.hasActiveAbility?(:UNSTABLECORE) &&
       !(target.hasActiveAbility?(:SHIELDDUST) && !@battle.moldBreaker)
      ret = 100
    end
    return ret
  end
end

#-------------------------------------------------------------------------------
# Sleek Scales – adds 15% of its Speed to its defending stat (Psyshock too)
#-------------------------------------------------------------------------------
[PokeBattle_Move, PokeBattle_Move_122].each do |klass|
  klass.class_eval do
    alias_method :kifer_l_pbGetDefenseStats, :pbGetDefenseStats unless method_defined?(:kifer_l_pbGetDefenseStats)
    define_method(:pbGetDefenseStats) do |user, target|
      stat, stage = kifer_l_pbGetDefenseStats(user, target)
      if !@battle.moldBreaker && KIFER.on_field?(@battle, :SLEEKSCALES) && target.hasActiveAbility?(:SLEEKSCALES)
        stat += (KIFER.speed_force_speed(target) * 0.15).floor
      end
      next stat, stage
    end
  end
end

#-------------------------------------------------------------------------------
# Steel Barrel – no recoil from its moves or from Electric Burst
#-------------------------------------------------------------------------------
class PokeBattle_RecoilMove
  alias kifer_l_pbEffectAfterAllHits pbEffectAfterAllHits unless method_defined?(:kifer_l_pbEffectAfterAllHits)
  def pbEffectAfterAllHits(user, target)
    return if user.hasActiveAbility?(:STEELBARREL)
    kifer_l_pbEffectAfterAllHits(user, target)
  end
end

if BattleHandlers::UserAbilityEndOfMove[:ELECTRICBURST]
  kifer_l_eburst = BattleHandlers::UserAbilityEndOfMove[:ELECTRICBURST]
  BattleHandlers::UserAbilityEndOfMove.add(:ELECTRICBURST,
    proc { |ability, user, targets, move, battle|
      next if user.hasActiveAbility?(:STEELBARREL)
      kifer_l_eburst.call(ability, user, targets, move, battle)
    }
  )
end

#-------------------------------------------------------------------------------
# Composite parts that are plain copies
#-------------------------------------------------------------------------------
BattleHandlers::StatusImmunityAbility.copy(:JUGGERNAUT, :SANDTITAN, :SUMOGUARD)
BattleHandlers::StatusCureAbility.copy(:JUGGERNAUT, :SANDTITAN, :SUMOGUARD)
BattleHandlers::DamageCalcUserAbility.copy(:TINTEDLENS, :SEPIALENS)
BattleHandlers::DamageCalcTargetAbility.copy(:SANDGUARD, :SEPIALENS)
BattleHandlers::DamageCalcTargetAbility.copy(:THICKFAT, :SUMOGUARD, :TUMMYACHE)
BattleHandlers::TargetAbilityOnHit.copy(:SCRAPYARD, :SHATTEREDARMOR)
BattleHandlers::UserAbilityOnHit.copy(:SHOCKINGJAWS, :SHOCKINGMAW)
BattleHandlers::MoveBaseTypeModifierAbility.copy(:SPECTRALIZE, :SPECTRALSHROUD)
BattleHandlers::DamageCalcUserAbility.copy(:SPECTRALIZE, :SPECTRALSHROUD)
BattleHandlers::UserAbilityOnHit.copy(:SPECTRALIZE, :SPECTRALSHROUD)
BattleHandlers::DamageCalcUserAbility.copy(:MIGHTYHORN, :VENOMCROWN)
BattleHandlers::AbilityOnSwitchIn.copy(:TOXICSPILL, :TRASHHEAP)
BattleHandlers::EOREffectAbility.copy(:TOXICSPILL, :TRASHHEAP)
BattleHandlers::AbilityOnSwitchIn.copy(:AQUATIC, :WATERBORNE)
BattleHandlers::DamageCalcUserAbility.copy(:AMPLIFIER, :WINDCHIMES)
BattleHandlers::MoveImmunityTargetAbility.copy(:DRAGONFLY, :WITCHBROOM)
BattleHandlers::EORHealingAbility.copy(:SHEDSKIN, :WONDERSCALE)
BattleHandlers::AbilityOnSwitchIn.copy(:FEARMONGER, :YUKIONNA)

#-------------------------------------------------------------------------------
# Sand Titan – Sand Stream (ER's: 8 turns, 12 with Smooth Rock)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:SANDTITAN,
  proc { |ability, battler, battle|
    KIFER::ERVersions.weather_ability(:Sandstorm, battler, battle, ability)
  }
)

#-------------------------------------------------------------------------------
# Sepia Lens – Sand Guard's block of foes' priority moves in a sandstorm
#-------------------------------------------------------------------------------
BattleHandlers::MoveBlockingAbility.add(:SEPIALENS,
  proc { |ability, bearer, user, targets, move, battle|
    next false if battle.pbWeather != :Sandstorm
    next false if !battle.choices[user.index][4] || battle.choices[user.index][4] <= 0
    next false if !bearer.opposes?(user)
    next false if !targets.any? { |b| b.opposes?(user) }
    next bearer.hasActiveAbility?(:SEPIALENS)   # names it on the game's splash
  }
)

#-------------------------------------------------------------------------------
# Sharp Edges – contact attackers lose 1/6 of their max HP
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:SHARPEDGES,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user) || user.fainted?
    next if !user.takesIndirectDamage? || !user.affectedByContactEffect?
    battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(ability))
    battle.scene.pbDamageAnimation(user)
    user.pbReduceHP([user.totalhp / 6, 1].max, false)
    battle.pbDisplay(_INTL("{1} is hurt!", user.pbThis))
    battle.pbHideAbilitySplash(target)
  }
)

#-------------------------------------------------------------------------------
# Shattered Armor / Toxic Shell – no crits on it; hits on it x0.8
#-------------------------------------------------------------------------------
KIFER::BatchL::ARMORS.each do |id|
  BattleHandlers::CriticalCalcTargetAbility.add(id, proc { |ability, user, target, c| next -1 })
  BattleHandlers::DamageCalcTargetAbility.add(id,
    proc { |ability, user, target, move, mults, baseDmg, type|
      mults[:final_damage_multiplier] *= 0.8
    }
  )
end

#-------------------------------------------------------------------------------
# Toxic Shell / Venom Crown – Poison Point either way
#-------------------------------------------------------------------------------
[:TOXICSHELL, :VENOMCROWN].each do |id|
  BattleHandlers::TargetAbilityOnHit.add(id,
    proc { |ability, user, target, move, battle|
      KIFER::BatchL.poison_target(ability, user, target, move)
    }
  )
  BattleHandlers::UserAbilityOnHit.add(id,
    proc { |ability, user, target, move, battle|
      KIFER::BatchL.poison_user(ability, user, target, move)
    }
  )
end

#-------------------------------------------------------------------------------
# Shiny Lightning – accuracy x1.2; Thunder never misses
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcUserAbility.add(:SHINYLIGHTNING,
  proc { |ability, mods, user, target, move, type|
    if move.id == :THUNDER
      mods[:base_accuracy] = 0
    else
      mods[:accuracy_multiplier] *= 1.2
    end
  }
)

#-------------------------------------------------------------------------------
# Shocking Maw – biting moves x1.3 (paralysis: Shocking Jaws, copied above)
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:SHOCKINGMAW,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER.bite_move?(move)
  }
)

#-------------------------------------------------------------------------------
# Sinister Claws – slicing moves x1.3 (special: pbUseMove above), Sp. Def -1
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:SINISTERCLAWS,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if KIFER::SLICING_MOVES.include?(move.id)
  }
)

BattleHandlers::UserAbilityOnHit.add(:SINISTERCLAWS,
  proc { |ability, user, target, move, battle|
    next if !KIFER::SLICING_MOVES.include?(move.id) || target.fainted?
    next if target.damageState.substitute
    next if target.instance_variable_get(:@kifer_l_sinister) == battle.turnCount
    next if !target.pbCanLowerStatStage?(:SPECIAL_DEFENSE, user)
    target.instance_variable_set(:@kifer_l_sinister, battle.turnCount)
    target.pbLowerStatStageByAbility(:SPECIAL_DEFENSE, 1, user, true, false, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Spectral Shroud – 30% chance to badly poison each target (Spectralize's part
# is copied above; its fear chance too)
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:SPECTRALSHROUD,
  proc { |ability, user, targets, move, battle|
    next if user.fainted?
    targets.each do |b|
      next if b.index == user.index || b.fainted?
      ds = b.damageState
      next if ds.unaffected || ds.substitute
      next if battle.pbRandom(100) >= 30
      next if move.damagingMove? && b.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      next if !b.pbCanPoison?(user, false, move)
      battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
      b.pbPoison(user, nil, true)
      battle.pbHideAbilitySplash(user)
    end
  }
)

#-------------------------------------------------------------------------------
# Spike Armor – contact either way: 30% bleed
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:SPIKEARMOR,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    KIFER::Statuses.cause_bleed(user, target, move, ability, 30)
  }
)

BattleHandlers::TargetAbilityOnHit.add(:SPIKEARMOR,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user) || !user.affectedByContactEffect? || user.fainted?
    KIFER::Statuses.cause_bleed(target, user, move, ability, 30)
  }
)

#-------------------------------------------------------------------------------
# Spinning Top – after a Fighting move: Speed +1, its side's hazards cleared
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:SPINNINGTOP,
  proc { |ability, user, targets, move, battle|
    next if move.calcType != :FIGHTING || user.fainted? || user.lastMoveFailed
    name = KIFER.ability_name(ability)
    if user.pbCanRaiseStatStage?(:SPEED, user)
      user.pbRaiseStatStageByAbility(:SPEED, 1, user, true, name)
    end
    side = user.pbOwnSide
    e = PBEffects
    next if !side.effects[e::StealthRock] && side.effects[e::Spikes] == 0 &&
            side.effects[e::ToxicSpikes] == 0 && !side.effects[e::StickyWeb]
    battle.pbShowAbilitySplash(user, false, true, name)
    if side.effects[e::StealthRock]
      side.effects[e::StealthRock] = false
      battle.pbDisplay(_INTL("{1} blew away stealth rocks!", user.pbThis))
    end
    if side.effects[e::Spikes] > 0
      side.effects[e::Spikes] = 0
      battle.pbDisplay(_INTL("{1} blew away spikes!", user.pbThis))
    end
    if side.effects[e::ToxicSpikes] > 0
      side.effects[e::ToxicSpikes] = 0
      battle.pbDisplay(_INTL("{1} blew away poison spikes!", user.pbThis))
    end
    if side.effects[e::StickyWeb]
      side.effects[e::StickyWeb] = false
      battle.pbDisplay(_INTL("{1} blew away sticky webs!", user.pbThis))
    end
    battle.pbHideAbilitySplash(user)
  }
)

#-------------------------------------------------------------------------------
# Sumo Wrestler – end of each 2nd turn: a 20 power Circle Throw
#-------------------------------------------------------------------------------
BattleHandlers::EOREffectAbility.add(:SUMOWRESTLER,
  proc { |ability, battler, battle|
    next if battler.fainted? || battler.turnCount < 2 || battler.turnCount.odd?
    foe = KIFER::BatchC.switch_in_target(battler)
    next if !foe
    KIFER::BatchF.use_extra_move(battler, :CIRCLETHROW, foe.index, 20, ability)
  }
)

#-------------------------------------------------------------------------------
# Thunder Clouds – after a special attack: a 35 power Thunderbolt
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:THUNDERCLOUDS,
  proc { |ability, user, targets, move, battle|
    next if KIFER.in_extra_move?(user) || user.fainted? || user.lastMoveFailed
    next if !move.damagingMove? || !move.specialMove?
    t = targets.find { |b| b.index != user.index && !b.fainted? && !b.damageState.unaffected }
    next if !t
    KIFER::BatchL.add_follow(user, :THUNDERBOLT, t.index, 35, ability)
  }
)

#-------------------------------------------------------------------------------
# Unstable Core – Aftermath (ER's): KO'd by an attack, it explodes
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:UNSTABLECORE,
  proc { |ability, user, target, move, battle|
    next if !target.fainted? || !user || user.index == target.index || !move.damagingMove?
    KIFER::ERVersions.aftermath_queue(battle, target, ability)
  }
)

#-------------------------------------------------------------------------------
# Rose Garden / Watch Your Step – 2 hazard layers on entry
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:ROSEGARDEN,
  proc { |ability, battler, battle|
    KIFER::BatchL.hazards(ability, battler, battle, PBEffects::ToxicSpikes, 2, 2,
                          "Poison spikes were scattered all around {1}'s feet!")
  }
)

BattleHandlers::AbilityOnSwitchIn.add(:WATCHYOURSTEP,
  proc { |ability, battler, battle|
    KIFER::BatchL.hazards(ability, battler, battle, PBEffects::Spikes, 2, 3,
                          "Spikes were scattered all around {1}'s feet!")
  }
)

#-------------------------------------------------------------------------------
# Wildfire – on entry: a 50 power Fire Spin
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:WILDFIRE,
  proc { |ability, battler, battle|
    foe = KIFER::BatchC.switch_in_target(battler)
    next if !foe
    KIFER::BatchF.use_extra_move(battler, :FIRESPIN, foe.index, 50, ability)
  }
)

#-------------------------------------------------------------------------------
# Wind Chimes – after a move hits it: a 30 power Hyper Voice (once per move)
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:WINDCHIMES,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || user.index == target.index || !move.damagingMove?
    next if KIFER.in_extra_move?(user)
    KIFER::BatchL.add_follow(target, :HYPERVOICE, -1, 30, ability, true)
  }
)

#-------------------------------------------------------------------------------
# Witch Broom (Hover) – on entry: adds the Psychic type
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:WITCHBROOM,
  proc { |ability, battler, battle|
    KIFER::BatchH.add_type(ability, battler, battle, :PSYCHIC)
  }
)

#-------------------------------------------------------------------------------
# Wrestle Showman – Flying Press +10 power; its hits Taunt the target
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:WRESTLESHOWMAN,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if move.id != :FLYINGPRESS || !baseDmg.is_a?(Numeric) || baseDmg <= 0
    mults[:base_damage_multiplier] *= (baseDmg + 10).to_f / baseDmg
  }
)

BattleHandlers::UserAbilityOnHit.add(:WRESTLESHOWMAN,
  proc { |ability, user, target, move, battle|
    next if move.id != :FLYINGPRESS || target.fainted? || target.damageState.substitute
    next if target.effects[PBEffects::Taunt] > 0
    if !battle.moldBreaker
      immune = defined?(KIFER::ERVersions) && KIFER::ERVersions.on? ? KIFER::ERVersions::TAUNT_IMMUNE : [:OBLIVIOUS]
      next if target.hasActiveAbility?(immune)
      veil = target.hasActiveAbility?(:AROMAVEIL)
      target.eachAlly { |a| veil = true if a.hasActiveAbility?(:AROMAVEIL) }
      next if veil
    end
    battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
    target.effects[PBEffects::Taunt] = 4   # as PIF's Taunt
    battle.pbDisplay(_INTL("{1} fell for the taunt!", target.pbThis))
    battle.pbHideAbilitySplash(user)
    target.pbItemStatusCureCheck
  }
)

#-------------------------------------------------------------------------------
# Yuki Onna – 30% infatuation on contact, either way (entry part: Fearmonger's
# Intimidate + Scare, copied above)
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:YUKIONNA,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    KIFER::BatchL.yuki_charm(ability, target, user, true)
  }
)

BattleHandlers::UserAbilityOnHit.add(:YUKIONNA,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    KIFER::BatchL.yuki_charm(ability, user, target, false)
  }
)

# Trash Heap / Tummyache count as Corrosion, Waterborne as Adaptability, Wind
# Chimes as Amplifier, in hasActiveAbility? (003)
KIFER::BatchL::COUNTS_AS.each { |part, wholes| KIFER.counts_as(part, *wholes) }

#===============================================================================
# Mega Sol and Unseen Fist: the Elite Redux versions (Cody, 2026-10-19). Megas
# adds Z-A versions too; it leaves an ability alone once KIF-ER registered it.
#===============================================================================
KIFER.er_code(:MEGASOL, :UNSEENFIST)

# Mega Sol – Chloroplast (its moves act as in harsh sunlight) + Grassy Surge
# (8 turns, 12 with Terrain Extender). With Innates Off, Megas' official
# version runs instead (Cody, 2026-10-19), so these stand down; Unseen Fist too.
class << KIFER::BatchH
  alias kifer_l_chloroplast? chloroplast? unless method_defined?(:kifer_l_chloroplast?)
  def chloroplast?(user)
    return true if kifer_l_chloroplast?(user)
    return KIFER.enabled? && has?(user, :MEGASOL)
  end
end

BattleHandlers::AbilityOnSwitchIn.add(:MEGASOL,
  proc { |ability, battler, battle|
    next if battle.field.terrain == :Grassy || !KIFER.enabled?
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    battle.pbStartTerrain(battler, :Grassy)   # hides the splash
    battle.field.terrainDuration = battler.hasActiveItem?(:TERRAINEXTENDER) ? 12 : 8
  }
)

# Unseen Fist – its contact moves go through Protect, Detect, King's Shield,
# Spiky Shield, Baneful Bunker, Quick Guard and Mat Block, and skip their
# side effects (all of PIF's protection checks ask canProtectAgainst?)
class PokeBattle_Move
  alias kifer_l_canProtectAgainst? canProtectAgainst? unless method_defined?(:kifer_l_canProtectAgainst?)
  def canProtectAgainst?
    return false if @kifer_l_unseen
    return kifer_l_canProtectAgainst?
  end
end

class PokeBattle_Battler
  alias kifer_l_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget unless method_defined?(:kifer_l_pbSuccessCheckAgainstTarget)
  def pbSuccessCheckAgainstTarget(move, user, target)
    return kifer_l_pbSuccessCheckAgainstTarget(move, user, target) unless
      KIFER.enabled? && user.hasActiveAbility?(:UNSEENFIST) && move.pbContactMove?(user)
    move.instance_variable_set(:@kifer_l_unseen, true)
    begin
      return kifer_l_pbSuccessCheckAgainstTarget(move, user, target)
    ensure
      move.instance_variable_set(:@kifer_l_unseen, false)
    end
  end
end
