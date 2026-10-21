#===============================================================================
# KIF: Elite Redux – Elite Redux abilities that each need something special (set 2)
#   Mechanics follow Elite Redux 2.65 (its C source, then its in-game texts).
#
#   Prim and Proper  – Wonder Skin: foes' abilities can't boost their damage
#                      against it (Parental Bond and Multi-Headed still work).
#                      Cute Charm: contact either way, 50% chance to infatuate
#                      the other Pokemon (ER's infatuation, see below).
#   Relic Stone      – while it is on the field, no other Pokemon gets the
#                      same-type boost, from its types or from abilities
#   Solar Flare      – Immolate (Normal moves become Fire; Fire-type user: 10%
#                      burn on its Fire moves; other users: Fire same-type
#                      boost) plus Chloroplast (its moves act as if in sun)
#   Parasitic Spores – on entry: spores on itself. A Pokemon with spores loses
#                      1/8 of its max HP each turn and passes them on to the
#                      targets of its contact moves. Ghost types can't get
#                      them. They go away on switching out.
#   Pure Love        – contact either way: 50% chance to infatuate the other
#                      Pokemon (ER's infatuation). Its hits on an infatuated
#                      Pokemon heal it by 1/4 of the damage.
#   Pyro Shells      – after a Mega Launcher move (ER's list): a 50 power
#                      Explosion if that move was physical, a 50 power
#                      Outburst if it was special or status; once per turn.
#                      Neither has added effects or makes the user faint.
#
#   ER's infatuation: while the "New battle effects" setting is On, every
#   infatuation (Attract, Cute Charm, Destiny Knot, Prim and Proper, Pure
#   Love, anything else that infatuates) is ER's: the infatuated Pokemon is
#   never immobilized by love; instead its attacks on the Pokemon it is in love
#   with use half its Attack / Sp. Atk. It is cured the same way as PIF's and
#   ends on switching out. With the setting Off, infatuation is PIF's, and
#   Prim and Proper and Pure Love don't infatuate.
#
#   Outburst isn't in PIF. Closest version: Explosion with ER's Outburst data
#   (Normal, special, no contact, hits every Pokemon next to the user), 50
#   power, and the user doesn't faint. Damp stops it, as it stops Explosion.
#
#   Wonder Skin works for Fort Knox too (same effect, same check): handler
#   boosts are cut by batch H's Fort Knox code; this file also takes away
#   boosts that come from game-method hooks (attacking/defending stat, power,
#   hit count, Adaptability, other damage multipliers).
#
#   Settings: ER infatuation and Parasitic spores use the "New battle effects"
#   setting. Off = PIF's infatuation, and these abilities don't infatuate or
#   spread spores.
#===============================================================================
module KIFER
  module Specials2
    CODED = []
    CODED.push(:RELICSTONE, :PARASITICSPORES, :PURELOVE)
    CODED.push(:PRIMANDPROPER) if defined?(KIFER::BatchH)
    CODED.push(:SOLARFLARE) if defined?(KIFER::BatchH) && defined?(KIFER::BatchG)
    CODED.push(:PYROSHELLS) if defined?(KIFER::BatchF)
  end
end

KIFER.er_code(*KIFER::Specials2::CODED)

if KIFER.respond_to?(:feature)
  KIFER.feature(:erlove, "ER infatuation",
                  "Infatuation that halves the attacker's damage instead of stopping it.")
  KIFER.feature(:spores, "Parasitic spores",
                  "Spores that take 1/8 HP each turn and spread through contact.")
end

module KIFER
  module Specials2
    # Multi-hit abilities Wonder Skin lets through
    KEEP_MULTIHIT = [:PARENTALBOND, :MULTIHEADED]

    @h_rec    = nil     # [user, {key => factor}] while its damage handlers run
    @love     = false   # true while Prim and Proper / Pure Love infatuate
    @outburst = false   # :outburst / :explosion while Pyro Shells (or ER's
                        # Aftermath, 050) makes its move

    class << self
      attr_accessor :h_rec, :love, :outburst
    end

    #---------------------------------------------------------------------------
    # Wonder Skin (Prim and Proper, Fort Knox)
    #---------------------------------------------------------------------------
    def self.prim?(user, target)
      return false if !user || !target || user.equal?(target)
      return false unless target.respond_to?(:opposes?) && target.opposes?(user)
      return false if target.battle.moldBreaker
      return KIFER::AIInnates.has?(target, :PRIMANDPROPER)
    end

    # Does the target block the user's damage boosting abilities?
    def self.blocks?(user, target)
      return KIFER::BatchH.fort_knox?(user, target) if defined?(KIFER::BatchH)
      return prim?(user, target)
    end

    # Runs the block with the battler's abilities off (main ability and
    # innates), except those in keep
    def self.strip(battler, keep = [])
      main = battler.instance_variable_get(:@ability_id)
      ids  = battler.instance_variable_get(:@innate_ids)
      inl  = battler.instance_variable_get(:@kifer_inline)
      battler.instance_variable_set(:@ability_id, nil) unless keep.include?(main)
      battler.instance_variable_set(:@innate_ids, ids.select { |a| keep.include?(a) }) if ids.is_a?(Array)
      begin
        return yield
      ensure
        battler.instance_variable_set(:@ability_id, main)
        battler.instance_variable_set(:@innate_ids, ids)
        battler.instance_variable_set(:@kifer_inline, inl)
      end
    end

    # Runs the block and returns [its result, the random rolls it used]. Works
    # inside the damage log's own record/replay runs.
    def self.with_rolls
      rng = KIFER.instance_variable_get(:@rng)
      if !KIFER.respond_to?(:rng_record)
        return [yield, []]
      elsif rng.nil?
        ret = nil
        rolls = KIFER.rng_record { ret = yield }
        return [ret, rolls]
      elsif rng[:mode] == :record
        n = rng[:rolls].length
        ret = yield
        return [ret, rng[:rolls][n..-1] || []]
      end
      i = rng[:i]
      ret = yield
      return [ret, (rng[:rolls][i...rng[:i]] || []).map { |v| v.nil? ? 0 : v }]
    end

    # Runs the block with these rolls in place of random numbers; the damage
    # log's own run is left as it was
    def self.replay(rolls)
      saved = KIFER.instance_variable_get(:@rng)
      KIFER.instance_variable_set(:@rng, { :mode => :replay, :rolls => rolls, :i => 0 })
      begin
        return yield
      ensure
        KIFER.instance_variable_set(:@rng, saved)
      end
    end

    def self.effective(stat, stage, crit, attacking)
      stage = [[stage.to_i, 0].max, 12].min
      stage = 6 if crit && attacking && stage < 6
      stage = 6 if crit && !attacking && stage > 6
      return stat.to_f * STAGE_MUL[stage] / STAGE_DIV[stage]
    end

    # Attacking stat: the lower of with and without the user's abilities
    def self.attack_stats(move, user, target)
      on = yield
      return on if !move.damagingMove? || !blocks?(user, target)
      off = strip(user) { yield }
      crit = target.damageState.critical
      return off if effective(off[0], off[1], crit, true) < effective(on[0], on[1], crit, true)
      return on
    end

    # Defending stat: the higher of with and without the user's abilities. If
    # the user's Unaware would skip the target's stat stages, they are put in
    # the stat itself.
    def self.defense_stats(move, user, target)
      on = yield
      return on if !move.damagingMove? || !blocks?(user, target)
      off = strip(user) { yield }
      crit = target.damageState.critical
      ret = (effective(off[0], off[1], crit, false) > effective(on[0], on[1], crit, false)) ? off : on
      if ret[1] != 6 && KIFER::AIInnates.has?(user, :UNAWARE)
        return [effective(ret[0], ret[1], crit, false).floor, 6]
      end
      return ret
    end

    # Damage multipliers: each one is the lower of "with the user's
    # abilities" and "without them, but with the cuts its damage handlers
    # made". The same random rolls are used for both.
    def self.blocked_mults(move, user, target, num, type, baseDmg, mults)
      h = Hash.new(1.0)
      on = mults.dup
      old = @h_rec
      @h_rec = [user, h]
      rolls = []
      begin
        _r, rolls = with_rolls { move.kifer_sp2_mults(user, target, num, type, baseDmg, on) }
      ensure
        @h_rec = old
      end
      off = mults.dup
      replay(rolls) { strip(user) { move.kifer_sp2_mults(user, target, num, type, baseDmg, off) } }
      mults.keys.each do |k|
        next if !on[k].is_a?(Numeric) || !off[k].is_a?(Numeric)
        mults[k] = [on[k], off[k] * h[k]].min
      end
      # Base power raised by the user's abilities (Weather Ball and the like)
      offBase = off_base_damage(move, user, target)
      if offBase.is_a?(Numeric) && baseDmg.is_a?(Numeric) && baseDmg > 0 && offBase < baseDmg
        mults[:base_damage_multiplier] *= offBase.to_f / baseDmg
      end
    end

    def self.off_base_damage(move, user, target)
      # copies: a move's own lists change in place (Beat Up shifts its hits)
      saved = move.instance_variables.map do |v|
        x = move.instance_variable_get(v)
        [v, (x.is_a?(Array) || x.is_a?(Hash)) ? x.dup : x]
      end
      begin
        return replay([]) { strip(user) { move.pbBaseDamage(move.baseDamage, user, target) } }
      rescue StandardError
        return nil
      ensure
        saved.each { |v, x| move.instance_variable_set(v, x) }
      end
    end

    # Notes the cuts the user's damage handlers make (Fort Knox's code has
    # already taken their boosts out)
    def self.note_handler(user, before, after)
      rec = @h_rec
      return if !rec || !rec[0].equal?(user)
      before.each do |k, v|
        next if !v.is_a?(Numeric) || v == 0 || !after[k].is_a?(Numeric)
        rec[1][k] *= after[k].to_f / v
      end
    end

    #---------------------------------------------------------------------------
    # Relic Stone
    #---------------------------------------------------------------------------
    def self.relic_on?(user)
      return false if !user || !user.battle
      user.battle.eachBattler do |b|
        next if b.equal?(user)
        return true if KIFER::AIInnates.has?(b, :RELICSTONE)
      end
      return false
    end

    #---------------------------------------------------------------------------
    # ER's infatuation
    #---------------------------------------------------------------------------
    def self.er_love_with?(user, target)
      return false unless user && target
      return false unless user.instance_variable_get(:@kifer_sp2_erlove)
      return user.effects[PBEffects::Attract] == target.index
    end

    # 50% chance: bearer's ability infatuates other (contact either way)
    def self.charm(ability, bearer, other, defending)
      battle = bearer.battle
      return if !KIFER.feature_on?(:erlove)
      return if bearer.fainted? || other.fainted? || bearer.equal?(other)
      return if other.effects[PBEffects::Attract] >= 0
      return if defending && !other.affectedByContactEffect?
      return if !other.pbCanAttract?(bearer, false)
      if !battle.moldBreaker   # an ally's Aroma Veil (PIF's check lets it through)
        veil = false
        other.eachAlly { |a| veil = true if a.hasActiveAbility?(:AROMAVEIL) }
        return if veil
      end
      return if battle.pbRandom(100) >= 50
      battle.pbShowAbilitySplash(bearer, false, true, KIFER.ability_name(ability))
      @love = true
      begin
        other.pbAttract(bearer)
      ensure
        @love = false
      end
      battle.pbHideAbilitySplash(bearer)
    end

    #---------------------------------------------------------------------------
    # Parasitic Spores
    #---------------------------------------------------------------------------
    def self.spored?(b)
      return b.instance_variable_get(:@kifer_sp2_spores) == true
    end

    def self.give_spores(b)
      return false if !KIFER.feature_on?(:spores)
      return false if b.fainted? || spored?(b) || b.pbHasType?(:GHOST)
      b.instance_variable_set(:@kifer_sp2_spores, true)
      b.battle.pbDisplay(_INTL("{1} was covered in spores!", b.pbThis))
      return true
    end

    def self.spore_damage(battle, priority)
      priority.each do |b|
        next if b.fainted? || !spored?(b) || b.pbHasType?(:GHOST)
        next if !b.takesIndirectDamage?
        oldHP = b.hp
        battle.scene.pbDamageAnimation(b)
        b.pbReduceHP([b.totalhp / 8, 1].max, false)
        battle.pbDisplay(_INTL("{1} is hurt by the spores!", b.pbThis))
        b.pbItemHPHealCheck
        b.pbAbilitiesOnDamageTaken(oldHP)
        b.pbFaint if b.fainted?
      end
    end

    #---------------------------------------------------------------------------
    # Pyro Shells – Outburst
    #---------------------------------------------------------------------------
    def self.outburst_id
      return GameData::Move.exists?(:OUTBURST) ? :OUTBURST : :EXPLOSION
    end

    def self.make_outburst(move)
      move.instance_variable_set(:@name, _INTL("Outburst"))
      move.instance_variable_set(:@type, :NORMAL)
      move.instance_variable_set(:@category, 1)
      move.instance_variable_set(:@addlEffect, 0)
      move.instance_variable_set(:@target, :AllNearOthers)
      flags = move.flags
      if flags.is_a?(String)
        move.instance_variable_set(:@flags, flags.delete("a"))
      elsif flags.is_a?(Array)
        move.instance_variable_set(:@flags, flags.reject { |f| f.to_s == "Contact" })
      end
      move.define_singleton_method(:pbSelfKO) { |_user| }
      move.instance_variable_set(:@kifer_sp2_outburst, true)
      return move
    end

    # Pyro Shells' / Aftermath's Explosion: no added effects, no fainting
    def self.make_explosion(move)
      move.instance_variable_set(:@addlEffect, 0)
      move.define_singleton_method(:pbSelfKO) { |_user| }
      move.instance_variable_set(:@kifer_sp2_outburst, true)
      return move
    end

    # The move id for a kind (:explosion / :outburst)
    def self.blast_id(kind)
      return (kind == :explosion) ? :EXPLOSION : outburst_id
    end

    # Once per turn, shared with batch D's extra moves
    def self.extra_used?(user)
      t = user.battle.turnCount
      return true if user.instance_variable_get(:@kifer_sp2_extra) == t
      d = user.instance_variable_get(:@kifer_d_extra)
      return true if d.is_a?(Array) && d[0] == t && d[1].equal?(user.pokemon)
      return false
    end

    def self.in_extra?(user)
      return true if user.instance_variable_get(:@kifer_sp2_in_extra)
      return true if user.instance_variable_get(:@kifer_f_extra)
      return true if user.instance_variable_get(:@kifer_d_in_extra)
      return false
    end

    def self.pyro_shells(user, ability, kind = :outburst)
      battle = user.battle
      return if battle.decision > 0 || user.fainted?
      return if [:SLEEP, :FROZEN].include?(user.status)
      return if extra_used?(user)
      user.instance_variable_set(:@kifer_sp2_extra, battle.turnCount)
      user.instance_variable_set(:@kifer_sp2_in_extra, true)
      @outburst = kind
      begin
        KIFER::BatchF.use_extra_move(user, blast_id(kind), -1, 50, ability)
      ensure
        @outburst = false
        user.instance_variable_set(:@kifer_sp2_in_extra, false)
      end
      battle.pbJudge
    end
  end
end

#-------------------------------------------------------------------------------
# Prim and Proper uses Fort Knox's checks; Solar Flare uses Chloroplast's
#-------------------------------------------------------------------------------
if defined?(KIFER::BatchH)
  class << KIFER::BatchH
    alias kifer_sp2_fort_knox? fort_knox? unless method_defined?(:kifer_sp2_fort_knox?)
    def fort_knox?(user, target)
      return true if kifer_sp2_fort_knox?(user, target)
      return KIFER::Specials2.prim?(user, target)
    end

    alias kifer_sp2_chloroplast? chloroplast? unless method_defined?(:kifer_sp2_chloroplast?)
    def chloroplast?(user)
      return true if kifer_sp2_chloroplast?(user)
      return KIFER::AIInnates.has?(user, :SOLARFLARE)
    end
  end
end

#-------------------------------------------------------------------------------
# Wonder Skin: notes the user's handler cuts. Relic Stone: the user's own
# damage handlers see the move's type as one of its types, so the ones that
# add a same-type boost for a type it doesn't have (they all check that) add
# nothing.
#-------------------------------------------------------------------------------
class << BattleHandlers
  alias kifer_sp2_triggerDamageCalcUserAbility triggerDamageCalcUserAbility unless method_defined?(:kifer_sp2_triggerDamageCalcUserAbility)
  def triggerDamageCalcUserAbility(ability, user, target, move, mults, *rest)
    type = rest[1]
    relic = type && KIFER::Specials2.relic_on?(user)
    rec = KIFER::Specials2.h_rec
    before = (rec && rec[0].equal?(user)) ? mults.dup : nil
    user.instance_variable_set(:@kifer_sp2_nostab, type) if relic
    begin
      ret = kifer_sp2_triggerDamageCalcUserAbility(ability, user, target, move, mults, *rest)
    ensure
      user.instance_variable_set(:@kifer_sp2_nostab, nil) if relic
    end
    KIFER::Specials2.note_handler(user, before, mults) if before
    return ret
  end
end

class PokeBattle_Move
  #-----------------------------------------------------------------------------
  # Damage multipliers: Relic Stone, ER's infatuation, Wonder Skin
  #-----------------------------------------------------------------------------
  alias kifer_sp2_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_sp2_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    if KIFER::Specials2.blocks?(user, target)
      return KIFER::Specials2.blocked_mults(self, user, target, numTargets, type, baseDmg, multipliers)
    end
    kifer_sp2_mults(user, target, numTargets, type, baseDmg, multipliers)
  end

  def kifer_sp2_mults(user, target, numTargets, type, baseDmg, multipliers)
    kifer_sp2_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    # Relic Stone: no same-type boost from its types (the game's own boost)
    if type && user.pbHasType?(type) && KIFER::Specials2.relic_on?(user)
      multipliers[:final_damage_multiplier] /= KIFER::AIInnates.has?(user, :ADAPTABILITY) ? 2 : 1.5
    end
    # ER's infatuation: half Attack / Sp. Atk against the one it loves
    if KIFER::Specials2.er_love_with?(user, target)
      multipliers[:attack_multiplier] *= 0.5
    end
  end

  #-----------------------------------------------------------------------------
  # Wonder Skin – attacking and defending stats, hit count
  #-----------------------------------------------------------------------------
  alias kifer_sp2_pbGetAttackStats pbGetAttackStats unless method_defined?(:kifer_sp2_pbGetAttackStats)
  def pbGetAttackStats(user, target)
    return KIFER::Specials2.attack_stats(self, user, target) { kifer_sp2_pbGetAttackStats(user, target) }
  end

  alias kifer_sp2_pbGetDefenseStats pbGetDefenseStats unless method_defined?(:kifer_sp2_pbGetDefenseStats)
  def pbGetDefenseStats(user, target)
    return KIFER::Specials2.defense_stats(self, user, target) { kifer_sp2_pbGetDefenseStats(user, target) }
  end

  alias kifer_sp2_pbNumHits pbNumHits unless method_defined?(:kifer_sp2_pbNumHits)
  def pbNumHits(user, targets)
    if targets.length == 1 && KIFER::Specials2.blocks?(user, targets[0])
      return KIFER::Specials2.strip(user, KIFER::Specials2::KEEP_MULTIHIT) { kifer_sp2_pbNumHits(user, targets) }
    end
    return kifer_sp2_pbNumHits(user, targets)
  end
end

# Psyshock and co. have their own defense stat
class PokeBattle_Move_122
  alias kifer_sp2_122_pbGetDefenseStats pbGetDefenseStats unless method_defined?(:kifer_sp2_122_pbGetDefenseStats)
  def pbGetDefenseStats(user, target)
    return KIFER::Specials2.defense_stats(self, user, target) { kifer_sp2_122_pbGetDefenseStats(user, target) }
  end
end

# Skill Link (2-5 hit moves)
class PokeBattle_Move_0C0
  alias kifer_sp2_0c0_pbNumHits pbNumHits unless method_defined?(:kifer_sp2_0c0_pbNumHits)
  def pbNumHits(user, targets)
    if targets.length == 1 && KIFER::Specials2.blocks?(user, targets[0])
      return KIFER::Specials2.strip(user, KIFER::Specials2::KEEP_MULTIHIT) { kifer_sp2_0c0_pbNumHits(user, targets) }
    end
    return kifer_sp2_0c0_pbNumHits(user, targets)
  end
end

#-------------------------------------------------------------------------------
# Pyro Shells – the move made for it becomes Outburst
#-------------------------------------------------------------------------------
class << PokeBattle_Move
  alias kifer_sp2_from_pokemon_move from_pokemon_move unless method_defined?(:kifer_sp2_from_pokemon_move)
  def from_pokemon_move(battle, move)
    ret = kifer_sp2_from_pokemon_move(battle, move)
    kind = KIFER::Specials2.outburst
    if kind == :explosion && ret.id == :EXPLOSION
      KIFER::Specials2.make_explosion(ret)
    elsif kind && kind != :explosion && ret.id == KIFER::Specials2.outburst_id
      KIFER::Specials2.make_outburst(ret)
    end
    return ret
  end
end

class PokeBattle_Battler
  #-----------------------------------------------------------------------------
  # Relic Stone – see the damage handler hook above
  #-----------------------------------------------------------------------------
  alias kifer_sp2_pbHasType? pbHasType? unless method_defined?(:kifer_sp2_pbHasType?)
  def pbHasType?(type)
    t = @kifer_sp2_nostab
    return true if t && type == t
    return kifer_sp2_pbHasType?(type)
  end

  #-----------------------------------------------------------------------------
  # ER's infatuation and spores end on switching out
  #-----------------------------------------------------------------------------
  alias kifer_sp2_pbInitEffects pbInitEffects unless method_defined?(:kifer_sp2_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_sp2_pbInitEffects(batonPass)
    @kifer_sp2_erlove = false
    @kifer_sp2_spores = false
  end

  # Every infatuation is ER's while the setting is On; PIF's while it is Off
  alias kifer_sp2_pbAttract pbAttract unless method_defined?(:kifer_sp2_pbAttract)
  def pbAttract(user, msg = nil)
    @kifer_sp2_erlove = (KIFER::Specials2.love || KIFER.feature_on?(:erlove)) ? true : false
    kifer_sp2_pbAttract(user, msg)
  end

  # ER's infatuation never stops it from moving
  alias kifer_sp2_pbTryUseMove pbTryUseMove unless method_defined?(:kifer_sp2_pbTryUseMove)
  def pbTryUseMove(*args)
    if @kifer_sp2_erlove && @effects[PBEffects::Attract] >= 0
      saved = @effects[PBEffects::Attract]
      @effects[PBEffects::Attract] = -1
      begin
        return kifer_sp2_pbTryUseMove(*args)
      ensure
        @effects[PBEffects::Attract] = saved if @effects[PBEffects::Attract] == -1
      end
    end
    return kifer_sp2_pbTryUseMove(*args)
  end

  #-----------------------------------------------------------------------------
  # Parasitic Spores – contact moves pass the spores on
  #-----------------------------------------------------------------------------
  alias kifer_sp2_pbEffectsOnMakingHit pbEffectsOnMakingHit unless method_defined?(:kifer_sp2_pbEffectsOnMakingHit)
  def pbEffectsOnMakingHit(move, user, target)
    kifer_sp2_pbEffectsOnMakingHit(move, user, target)
    return if !KIFER::Specials2.spored?(user) || user.equal?(target) || target.fainted?
    return if !move.pbContactMove?(user)
    ds = target.damageState
    return if ds.calcDamage <= 0 || ds.substitute
    KIFER::Specials2.give_spores(target)
  end

  #-----------------------------------------------------------------------------
  # Pyro Shells – its Outburst comes once the move is over
  #-----------------------------------------------------------------------------
  alias kifer_sp2_pbUseMove pbUseMove unless method_defined?(:kifer_sp2_pbUseMove)
  def pbUseMove(choice, specialUsage = false)
    @kifer_sp2_follow = nil if !@kifer_sp2_in_extra
    kifer_sp2_pbUseMove(choice, specialUsage)
    follow = @kifer_sp2_follow
    @kifer_sp2_follow = nil
    return if !follow || @kifer_sp2_in_extra
    KIFER::Specials2.pyro_shells(self, *Array(follow))
  end
end

#-------------------------------------------------------------------------------
# Parasitic Spores – damage at the end of each turn (after the weather)
#-------------------------------------------------------------------------------
class PokeBattle_Battle
  alias kifer_sp2_pbEORWeather pbEORWeather unless method_defined?(:kifer_sp2_pbEORWeather)
  def pbEORWeather(priority)
    kifer_sp2_pbEORWeather(priority)
    KIFER::Specials2.spore_damage(self, priority)
  end
end

BattleHandlers::AbilityOnSwitchIn.add(:PARASITICSPORES,
  proc { |ability, battler, battle|
    next if !KIFER.feature_on?(:spores) || KIFER::Specials2.spored?(battler)
    next if battler.pbHasType?(:GHOST)
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    KIFER::Specials2.give_spores(battler)
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Prim and Proper / Pure Love – infatuation on contact, either way
#-------------------------------------------------------------------------------
[:PRIMANDPROPER, :PURELOVE].each do |id|
  BattleHandlers::TargetAbilityOnHit.add(id,
    proc { |ability, user, target, move, battle|
      next if !move.pbContactMove?(user)
      KIFER::Specials2.charm(ability, target, user, true)
    }
  )
end

BattleHandlers::UserAbilityOnHit.add(:PRIMANDPROPER,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    KIFER::Specials2.charm(ability, user, target, false)
  }
)

BattleHandlers::UserAbilityOnHit.add(:PURELOVE,
  proc { |ability, user, target, move, battle|
    # Heals 1/4 of the damage done to an infatuated Pokemon
    lost = target.damageState.hpLost
    if target.effects[PBEffects::Attract] >= 0 && lost > 0 && user.canHeal?
      battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
      user.pbRecoverHP([lost / 4, 1].max)
      battle.pbDisplay(_INTL("{1}'s HP was restored.", user.pbThis))
      battle.pbHideAbilitySplash(user)
    end
    next if !move.pbContactMove?(user)
    KIFER::Specials2.charm(ability, user, target, false)
  }
)

#-------------------------------------------------------------------------------
# Solar Flare – Immolate's handlers (batch G); the sun part is above
#-------------------------------------------------------------------------------
if KIFER::Specials2::CODED.include?(:SOLARFLARE)
  BattleHandlers::MoveBaseTypeModifierAbility.copy(:IMMOLATE, :SOLARFLARE)
  BattleHandlers::DamageCalcUserAbility.copy(:IMMOLATE, :SOLARFLARE)
  BattleHandlers::UserAbilityOnHit.copy(:IMMOLATE, :SOLARFLARE)
end

#-------------------------------------------------------------------------------
# Pyro Shells – after a Mega Launcher move: a 50 power Explosion (physical
# move) or Outburst (special or status move)
#-------------------------------------------------------------------------------
if KIFER::Specials2::CODED.include?(:PYROSHELLS)
  BattleHandlers::UserAbilityEndOfMove.add(:PYROSHELLS,
    proc { |ability, user, targets, move, battle|
      next if KIFER::Specials2.in_extra?(user) || user.fainted? || user.lastMoveFailed
      next if !KIFER::BatchF::MEGA_LAUNCHER_MOVES.include?(move.id)
      next if !targets.any? { |b| !b.equal?(user) && !b.fainted? && !b.damageState.unaffected }
      next if KIFER::Specials2.extra_used?(user)
      user.instance_variable_set(:@kifer_sp2_follow, [ability, move.physicalMove? ? :explosion : :outburst])
    }
  )
end
