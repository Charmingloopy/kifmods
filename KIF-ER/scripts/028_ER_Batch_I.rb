#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch I)
#   Mechanics follow the newest Elite Redux texts (none of these are in the
#   public C source, except Armor Tail).
#
#   Hellblaze        – Fire moves x1.3, x1.8 at 1/3 HP or less
#   Riptide          – Water moves x1.3, x1.8 at 1/3 HP or less
#   Forest Rage      – Grass moves x1.3, x1.8 at 1/3 HP or less
#   Arcane Force     – Mystic Power (every move gets the same-type boost), and
#                      super-effective moves x1.1
#   Armor Tail       – foes' moves with priority above 0 can't be used on it or
#                      its ally (Dazzling's code)
#   Big Leaves       – Chloroplast + Chlorophyll + Leaf Guard + Harvest + Solar
#                      Power
#   Crystallize      – Rock moves become Ice and get x1.1
#   Flame Shield     – takes x0.65 damage from super-effective hits
#   King's Wrath     – when it or its ally has a stat lowered (not by the
#                      Pokemon itself): its Attack and Defense +1
#   Radiance         – accuracy x1.2; Dark moves fail while it is on the field
#                      (anyone's, its own too)
#   Roundhouse       – kicking moves never miss and hit the target's weaker
#                      defense (Sp. Def when it is lower, stages counted)
#   To The Bone      – Sniper + Razor Sharp: critical hits x1.5 and make the
#                      target bleed
#   Acidic Slime     – Corrosion, and Poison moves get the same-type boost
#   Acid Reflux      – hit by an attack that does damage: uses a 20 power Acid
#                      once the attack is over
#   Angelic Wings    – Prism Scales + Imposing Wings
#   Arc Flash        – its contact hits: 50% to paralyze; hits on it: 50% to
#                      burn the attacker
#   Atomic Burst     – Galvanize; hit by an attack: charged (its next Electric
#                      move x2, Generator's charge)
#   Aura Armor       – takes x0.65 damage from attacks
#   Backflip         – after it uses a dance move: a 50 power Chip Away
#   Backstreet Boy   – Striker; its kicking moves count as dance moves and its
#                      dance moves as kicking moves
#   Balloon Blitz    – Inflatable + Hyper Aggressive
#   Balloon Bomb     – Aftermath + Inflatable
#   Battle Aura      – every Pokemon's critical hit stage +2 while it is on
#                      the field
#   Berserker Rage   – Tipping Point + Rampage
#   Blight Scale     – Multiscale + Poison Point
#   Break it Down    – after it uses a damaging move: a 20 power Rapid Spin
#   Chandelier       – Illuminate + Pyromancy
#   Cheating Death   – the first two hits that would damage it do 0 damage
#                      (once per battle; effects of the hits still apply)
#   Chestnut Axe     – slicing moves and Grass moves x1.3 (Keen Edge)
#   Chestnut Shield  – Impenetrable + Bulletproof
#   Cold Rebound     – hit by a contact move: uses a 60 power Icy Wind once
#                      the attack is over
#   Conjurer Of Deceit – Magic Guard + Magic Bounce
#   Contempt         – Unaware + Defiant
#
#   "A + B" abilities: each part works as if the Pokemon had it (its handlers
#   run, and hasActiveAbility? / KIFER.on_field? answer true for the part).
#   PIF abilities among the parts follow the "Ability versions" setting.
#
# Not coded yet:
#   Angel's Wrath    – rewrites seven moves into new ones; a big engine change
#   Ape Shift        – a form change PIF can't do
#   Clueless         – turning off terrains and rooms needs every terrain and
#                      room check in the game changed
#===============================================================================
KIFER.er_code(:HELLBLAZE, :RIPTIDE, :FORESTRAGE, :ARCANEFORCE, :ARMORTAIL,
                :BIGLEAVES, :CRYSTALLIZE, :FLAMESHIELD, :KINGSWRATH, :RADIANCE,
                :ROUNDHOUSE, :TOTHEBONE, :ACIDICSLIME, :ACIDREFLUX, :ANGELICWINGS,
                :ARCFLASH, :ATOMICBURST, :AURAARMOR, :BACKFLIP, :BACKSTREETBOY,
                :BALLOONBLITZ, :BALLOONBOMB, :BATTLEAURA, :BERSERKERRAGE,
                :BLIGHTSCALE, :BREAKITDOWN, :CHANDELIER, :CHEATINGDEATH,
                :CHESTNUTAXE, :CHESTNUTSHIELD, :COLDREBOUND, :CONJUREROFDECEIT,
                :CONTEMPT)

module KIFER
  module BatchI
    # "A + B" abilities and the abilities they are made of
    PARTS = {
      :BIGLEAVES        => [:CHLOROPLAST, :CHLOROPHYLL, :LEAFGUARD, :HARVEST, :SOLARPOWER],
      :TOTHEBONE        => [:SNIPER, :RAZORSHARP],
      :ACIDICSLIME      => [:CORROSION],
      :ANGELICWINGS     => [:PRISMSCALES, :IMPOSINGWINGS],
      :ATOMICBURST      => [:GALVANIZE],
      :BACKSTREETBOY    => [:STRIKER],
      :BALLOONBLITZ     => [:INFLATABLE, :HYPERAGGRESSIVE],
      :BALLOONBOMB      => [:AFTERMATH, :INFLATABLE],
      :BERSERKERRAGE    => [:TIPPINGPOINT, :RAMPAGE],
      :BLIGHTSCALE      => [:MULTISCALE, :POISONPOINT],
      :CHANDELIER       => [:ILLUMINATE, :PYROMANCY],
      :CHESTNUTSHIELD   => [:IMPENETRABLE, :BULLETPROOF],
      :CONJUREROFDECEIT => [:MAGICGUARD, :MAGICBOUNCE],
      :CONTEMPT         => [:UNAWARE, :DEFIANT]
    }.freeze

    # part => the abilities that include it
    PART_OF = {}
    PARTS.each { |c, parts| parts.each { |pt| (PART_OF[pt] ||= []) << c } }
    # Imposing Wings counts as Levitate (022 asks for it only by its own name)
    PART_OF[:LEVITATE] = [:ANGELICWINGS]

    # A composite's own effects besides its parts: [handler hash, id] => proc
    EXTRA = {}

    # A composite's handler: its parts' handlers (looked up when it runs, so
    # later files' versions count), then its own, combined the way 004 combines
    # innates
    def self.run_parts(name, comp, args)
      spec = KIFER::TRIGGERS[name]
      hash = BattleHandlers.const_get(name)
      list = PARTS[comp].map { |pt| [pt, hash[pt]] }
      list << [comp, EXTRA[[name, comp]]]
      ret = (spec[1] == :chain) ? args[spec[2]] : nil
      list.each do |id, h|
        next if !h
        case spec[1]
        when :chain
          a = args.dup
          a[spec[2]] = ret
          r = h.call(id, *a)
          ret = r if !r.nil?
        when :any
          return true if h.call(id, *args)
        else
          r = h.call(id, *args)
          ret = r if !ret
        end
      end
      return ret
    end

    # Copies of an ability the battler has working (main ability and innates)
    def self.copies(b, id)
      return 0 if !b || b.fainted? || !b.abilityActive?
      n = (b.ability_id == id) ? 1 : 0
      return n + b.active_innates.count(id)
    end

    def self.pinch(user, type, want)
      return 1.0 if type != want
      return (user.hp <= user.totalhp / 3) ? 1.8 : 1.3
    end

    def self.super_effective?(target)
      return Effectiveness.super_effective?(target.damageState.typeMod)
    end

    # Battle Aura: crit stages from every one on the field
    def self.aura_stages(battle)
      n = 0
      battle.battlers.each { |b| n += copies(b, :BATTLEAURA) * 2 if b }
      return n
    end

    # King's Wrath: a stat of battler was lowered by user
    def self.kings_wrath(battler, user)
      return if user && user.equal?(battler)
      battle = battler.battle
      return if !KIFER.on_field?(battle, :KINGSWRATH)
      bearers = [battler]
      battler.eachAlly { |a| bearers << a }
      bearers.each do |b|
        copies(b, :KINGSWRATH).times do
          break if b.fainted?
          up = [:ATTACK, :DEFENSE].select { |s| b.pbCanRaiseStatStage?(s, b) }
          break if up.empty?
          battle.pbShowAbilitySplash(b, false, true, KIFER.ability_name(:KINGSWRATH))
          up.each { |s| b.pbRaiseStatStage(s, 1, b) }
          battle.pbHideAbilitySplash(b)
        end
      end
    end

    # Cheating Death: hits taken this battle, per Pokemon
    def self.cheats(battle)
      return battle.instance_variable_get(:@kifer_i_cheats) ||
             battle.instance_variable_set(:@kifer_i_cheats, {})
    end

    def self.cheat_death(move, user, target)
      ds = target.damageState
      return if ds.calcDamage.to_i <= 0 || ds.substitute || ds.disguise
      battle = target.battle
      return if battle.moldBreaker || !KIFER.on_field?(battle, :CHEATINGDEATH)
      n = copies(target, :CHEATINGDEATH)
      return if n == 0
      used = cheats(battle)[target.pokemon.object_id] || 0
      return if used >= 2 * n
      cheats(battle)[target.pokemon.object_id] = used + 1
      ds.calcDamage = 0
      battle.pbShowAbilitySplash(target, false, true, KIFER.ability_name(:CHEATINGDEATH))
      battle.pbDisplay(_INTL("{1} took no damage!", target.pbThis))
      battle.pbHideAbilitySplash(target)
    end

    # Cold Rebound / Acid Reflux: moves used once the attack is over
    def self.queue(battle)
      return battle.instance_variable_get(:@kifer_i_queue) ||
             battle.instance_variable_set(:@kifer_i_queue, [])
    end

    def self.retaliate(ability, bearer, attacker, move_id, power)
      return if !attacker || attacker.index == bearer.index || KIFER.in_extra_move?(attacker)
      q = queue(bearer.battle)
      return if q.any? { |e| e[0].equal?(bearer) && e[3] == move_id }
      q << [bearer, bearer.pokemon, attacker, move_id, power, ability]
    end

    def self.run_queue(battle)
      q = queue(battle)
      return if q.empty?
      todo = q.dup
      q.clear
      todo.each do |b, pkmn, foe, move_id, power, ability|
        break if battle.decision > 0
        next if b.fainted? || !b.pokemon.equal?(pkmn) || [:SLEEP, :FROZEN].include?(b.status)
        next if foe.fainted?
        KIFER::BatchF.use_extra_move(b, move_id, foe.index, power, ability)
      end
    end

    # Backflip / Break it Down: follow-ups after its own move
    def self.follow_ups(user, choice)
      move = choice[2]
      return if !move.is_a?(PokeBattle_Move) || KIFER.in_extra_move?(user)
      battle = user.battle
      return if battle.decision > 0 || user.fainted?
      return if user.lastMoveUsed != move.id || user.lastMoveFailed
      return if user.effects[PBEffects::TwoTurnAttack]
      [[:BACKFLIP, :CHIPAWAY, 50], [:BREAKITDOWN, :RAPIDSPIN, 20]].each do |id, move_id, power|
        break if user.fainted? || battle.decision > 0
        next if id == :BACKFLIP ? !move.danceMove? : !move.damagingMove?
        next if !KIFER.on_field?(battle, id) || !KIFER::BatchH.has?(user, id)
        t = choice[3]
        foe = (t.is_a?(Integer) && t >= 0) ? battle.battlers[t] : nil
        foe = KIFER::BatchF.random_near_foe(user) if !foe || foe.fainted? || !foe.opposes?(user)
        next if !foe || foe.fainted?
        KIFER::BatchF.use_extra_move(user, move_id, foe.index, power, id)
      end
    end
  end
end

#-------------------------------------------------------------------------------
# "A + B" abilities: handlers for every hash innates use, and the parts count
# for inline checks
#-------------------------------------------------------------------------------
KIFER::TRIGGERS.each_key do |name|
  next if !BattleHandlers.const_defined?(name)
  KIFER::BatchI::PARTS.each_key do |comp|
    BattleHandlers.const_get(name).add(comp,
      proc { |_ability, *args| KIFER::BatchI.run_parts(name, comp, args) })
  end
end

# hasActiveAbility?(:PART) is also true for the abilities above that contain
# it: 003's "counts as" table (registered at the end of this file)

class << KIFER
  alias kifer_i_on_field? on_field? unless method_defined?(:kifer_i_on_field?)
  def on_field?(battle, id)
    return true if kifer_i_on_field?(battle, id)
    comps = KIFER::BatchI::PART_OF[id]
    return false if !comps
    return comps.any? { |c| kifer_i_on_field?(battle, c) }
  end

  # Backstreet Boy: its dance moves are kicks
  alias kifer_i_kick_move? kick_move? unless method_defined?(:kifer_i_kick_move?)
  def kick_move?(move)
    return true if kifer_i_kick_move?(move)
    return (move.instance_variable_get(:@kifer_i_bsb) && move.kifer_i_danceMove?) ? true : false
  end
end

#-------------------------------------------------------------------------------
# Hellblaze / Riptide / Forest Rage
#-------------------------------------------------------------------------------
{ :HELLBLAZE => :FIRE, :RIPTIDE => :WATER, :FORESTRAGE => :GRASS }.each do |id, t|
  BattleHandlers::DamageCalcUserAbility.add(id,
    proc { |ability, user, target, move, mults, baseDmg, type|
      mults[:base_damage_multiplier] *= KIFER::BatchI.pinch(user, type, t)
    }
  )
end

#-------------------------------------------------------------------------------
# Arcane Force – Mystic Power, and super-effective moves x1.1
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:ARCANEFORCE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    BattleHandlers::DamageCalcUserAbility[:MYSTICPOWER].call(ability, user, target, move, mults, baseDmg, type)
    mults[:base_damage_multiplier] *= 1.1 if KIFER::BatchI.super_effective?(target)
  }
)

#-------------------------------------------------------------------------------
# Armor Tail – blocks foes' priority moves on its side
#-------------------------------------------------------------------------------
BattleHandlers::MoveBlockingAbility.copy(:DAZZLING, :ARMORTAIL)

#-------------------------------------------------------------------------------
# Crystallize – Rock moves become Ice, x1.1
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.add(:CRYSTALLIZE,
  proc { |ability, user, move, type|
    next if type != :ROCK || !GameData::Type.exists?(:ICE)
    next :ICE
  }
)

BattleHandlers::DamageCalcUserAbility.add(:CRYSTALLIZE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.1 if type == :ICE && move.type == :ROCK
  }
)

#-------------------------------------------------------------------------------
# Flame Shield / Aura Armor – less damage taken
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:FLAMESHIELD,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.65 if KIFER::BatchI.super_effective?(target)
  }
)

BattleHandlers::DamageCalcTargetAbility.add(:AURAARMOR,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.65
  }
)

#-------------------------------------------------------------------------------
# Radiance – accuracy x1.2; Dark moves fail
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcUserAbility.add(:RADIANCE,
  proc { |ability, mods, user, target, move, type|
    mods[:accuracy_multiplier] *= 1.2
  }
)

BattleHandlers::MoveBlockingAbility.add(:RADIANCE,
  proc { |ability, bearer, user, targets, move, battle|
    next (move.calcType || move.pbCalcType(user)) == :DARK
  }
)

#-------------------------------------------------------------------------------
# Roundhouse – kicks never miss and hit the weaker defense
#-------------------------------------------------------------------------------
BattleHandlers::AccuracyCalcUserAbility.add(:ROUNDHOUSE,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0 if KIFER.kick_move?(move)
  }
)

class PokeBattle_Move
  alias kifer_i_pbGetDefenseStats pbGetDefenseStats unless method_defined?(:kifer_i_pbGetDefenseStats)
  def pbGetDefenseStats(user, target)
    if physicalMove? && KIFER.on_field?(@battle, :ROUNDHOUSE) && KIFER.kick_move?(self) &&
       KIFER::BatchH.has?(user, :ROUNDHOUSE) &&
       KIFER::BatchD.staged(target, :SPECIAL_DEFENSE) < KIFER::BatchD.staged(target, :DEFENSE)
      return KIFER::BatchA.def_stat(self, :SPECIAL_DEFENSE) { kifer_i_pbGetDefenseStats(user, target) }
    end
    return kifer_i_pbGetDefenseStats(user, target)
  end

  #-----------------------------------------------------------------------------
  # Battle Aura – crit stage +2 for everyone (each copy on the field)
  #-----------------------------------------------------------------------------
  alias kifer_i_pbIsCritical? pbIsCritical? unless method_defined?(:kifer_i_pbIsCritical?)
  def pbIsCritical?(user, target)
    n = KIFER.on_field?(@battle, :BATTLEAURA) ? KIFER::BatchI.aura_stages(@battle) : 0
    return kifer_i_pbIsCritical?(user, target) if n == 0
    user.effects[PBEffects::FocusEnergy] += n
    begin
      return kifer_i_pbIsCritical?(user, target)
    ensure
      user.effects[PBEffects::FocusEnergy] -= n
    end
  end

  #-----------------------------------------------------------------------------
  # Cheating Death – the hit does 0 damage
  #-----------------------------------------------------------------------------
  alias kifer_i_pbReduceDamage pbReduceDamage unless method_defined?(:kifer_i_pbReduceDamage)
  def pbReduceDamage(user, target)
    KIFER::BatchI.cheat_death(self, user, target)
    kifer_i_pbReduceDamage(user, target)
  end

  #-----------------------------------------------------------------------------
  # Backstreet Boy – marks this use of the move; its kicks are dance moves
  #-----------------------------------------------------------------------------
  alias kifer_i_pbCalcType pbCalcType unless method_defined?(:kifer_i_pbCalcType)
  def pbCalcType(user)
    ret = kifer_i_pbCalcType(user)
    @kifer_i_bsb = (KIFER.on_field?(@battle, :BACKSTREETBOY) && KIFER::BatchH.has?(user, :BACKSTREETBOY))
    return ret
  end

  alias kifer_i_danceMove? danceMove? unless method_defined?(:kifer_i_danceMove?)
  def danceMove?
    return true if kifer_i_danceMove?
    return (@kifer_i_bsb && KIFER.kifer_i_kick_move?(self)) ? true : false
  end
end

#-------------------------------------------------------------------------------
# Chestnut Axe – slicing and Grass moves x1.3
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:CHESTNUTAXE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :GRASS && !KIFER::SLICING_MOVES.include?(move.id)
    mults[:base_damage_multiplier] *= 1.3
  }
)

#-------------------------------------------------------------------------------
# Acidic Slime – Poison same-type boost (Corrosion is its part)
#-------------------------------------------------------------------------------
KIFER::BatchI::EXTRA[[:DamageCalcUserAbility, :ACIDICSLIME]] =
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :POISON || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }

#-------------------------------------------------------------------------------
# Atomic Burst – hit by an attack: charged (Galvanize is its part)
#-------------------------------------------------------------------------------
KIFER::BatchI::EXTRA[[:TargetAbilityOnHit, :ATOMICBURST]] =
  proc { |ability, user, target, move, battle|
    next if target.fainted? || target.instance_variable_get(:@kifer_a_charged)
    KIFER::BatchA.charge(target, KIFER.ability_name(ability))
  }

#-------------------------------------------------------------------------------
# Arc Flash – 50% paralysis with its contact hits, 50% burn when hit
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:ARCFLASH,
  proc { |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_user(ability, user, target, move, :PARALYSIS, 50, 0)
  }
)

BattleHandlers::TargetAbilityOnHit.add(:ARCFLASH,
  proc { |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_target(ability, user, target, move, :BURN, 50, 50)
  }
)

#-------------------------------------------------------------------------------
# Acid Reflux / Cold Rebound – a move back once the attack is over
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:ACIDREFLUX,
  proc { |ability, user, target, move, battle|
    next if target.damageState.substitute || target.damageState.hpLost.to_i <= 0
    KIFER::BatchI.retaliate(ability, target, user, :ACID, 20)
  }
)

BattleHandlers::TargetAbilityOnHit.add(:COLDREBOUND,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    KIFER::BatchI.retaliate(ability, target, user, :ICYWIND, 60)
  }
)

#-------------------------------------------------------------------------------
# King's Wrath – a stat drop on its side: Attack and Defense +1
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_i_pbLowerStatStage pbLowerStatStage unless method_defined?(:kifer_i_pbLowerStatStage)
  def pbLowerStatStage(stat, increment, user, showAnim = true, ignoreContrary = false)
    before = @stages[stat]
    ret = kifer_i_pbLowerStatStage(stat, increment, user, showAnim, ignoreContrary)
    KIFER::BatchI.kings_wrath(self, user) if ret && @stages[stat] < before
    return ret
  end

  alias kifer_i_pbLowerStatStageByCause pbLowerStatStageByCause unless method_defined?(:kifer_i_pbLowerStatStageByCause)
  def pbLowerStatStageByCause(stat, increment, user, cause, showAnim = true, ignoreContrary = false)
    before = @stages[stat]
    ret = kifer_i_pbLowerStatStageByCause(stat, increment, user, cause, showAnim, ignoreContrary)
    KIFER::BatchI.kings_wrath(self, user) if ret && @stages[stat] < before
    return ret
  end

  #-----------------------------------------------------------------------------
  # Backflip / Break it Down follow-ups; Acid Reflux / Cold Rebound once the
  # outermost move is over
  #-----------------------------------------------------------------------------
  alias kifer_i_pbUseMove pbUseMove unless method_defined?(:kifer_i_pbUseMove)
  def pbUseMove(choice, specialUsage = false)
    depth = @battle.instance_variable_get(:@kifer_i_depth) || 0
    @battle.instance_variable_set(:@kifer_i_depth, depth + 1)
    begin
      kifer_i_pbUseMove(choice, specialUsage)
      KIFER::BatchI.follow_ups(self, choice)
    ensure
      @battle.instance_variable_set(:@kifer_i_depth, depth)
      # Backstreet Boy's mark is for this use only
      choice[2].instance_variable_set(:@kifer_i_bsb, false) if choice[2].is_a?(PokeBattle_Move)
    end
    KIFER::BatchI.run_queue(@battle) if depth == 0
  end
end

# Its parts count for these abilities in hasActiveAbility? (003)
KIFER::BatchI::PART_OF.each { |part, wholes| KIFER.counts_as(part, *wholes) }
