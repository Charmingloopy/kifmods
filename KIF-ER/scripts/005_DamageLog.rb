#===============================================================================
# KIF: Elite Redux – damage log (Mod Settings > KIF: Elite Redux > Damage log, default Off)
#   For every hit where the attacker or the target has innates, writes one
#   line to KIF_log.txt:
#     the damage the hit would do with no innates,
#     the damage it should do with innates,
#     the damage it actually did (after Sturdy, Focus Sash, Substitute...),
#     and each innate that changed the number (damage without just that one).
#   Moves with set damage (Dragon Rage, Seismic Toss...) skip the damage
#   formula; they get a "set damage" line instead.
#   The comparisons are dry runs of the game's own damage formula with the
#   same random rolls (damage roll, critical hit) as the real hit, so only the
#   innates differ. The real hit is calculated first and is not changed.
#===============================================================================
module KIFER
  @rng = nil   # nil, or { :mode => :record/:replay, :rolls => [], :i => 0 }

  def self.rng_record
    @rng = { :mode => :record, :rolls => [] }
    begin
      yield
    ensure
      rolls = @rng[:rolls]
      @rng = nil
    end
    return rolls
  end

  def self.rng_replay(rolls)
    @rng = { :mode => :replay, :rolls => rolls, :i => 0 }
    begin
      return yield
    ensure
      @rng = nil
    end
  end

  # nil = use the real random number
  def self.rng_value(x)
    return nil if @rng.nil? || @rng[:mode] != :replay
    v = @rng[:rolls][@rng[:i]]
    @rng[:i] += 1
    return v.nil? ? 0 : [v, x - 1].min   # a dry run that rolls more than the real hit never touches the real RNG
  end

  def self.rng_note(v)
    @rng[:rolls] << v if @rng && @rng[:mode] == :record
  end

  def self.innate_holders(user, target)
    list = [user, target]
    begin
      user.eachAlly { |b| list << b } if user.respond_to?(:eachAlly)
      target.eachAlly { |b| list << b } if target.respond_to?(:eachAlly)
    rescue StandardError
    end
    return list.compact.uniq.select { |b| b.respond_to?(:active_innates) && !b.active_innates.empty? }
  end

  DS_FIELDS = [:@calcDamage, :@critical, :@substitute, :@disguise]

  def self.dry_damage(move, user, target, num, rolls)
    ds = target.damageState
    saved = DS_FIELDS.map { |f| ds.instance_variable_get(f) }
    begin
      rng_replay(rolls) { move.kifer_pbCalcDamage(user, target, num) }
      return ds.calcDamage
    ensure
      DS_FIELDS.each_with_index { |f, i| ds.instance_variable_set(f, saved[i]) }
    end
  end

  def self.pending_damage
    @pending_damage ||= {}
  end

  # The last line written and the random rolls of that hit (for tests)
  class << self
    attr_accessor :last_damage
  end
end

class PokeBattle_Battle
  alias kifer_pbRandom pbRandom unless method_defined?(:kifer_pbRandom)
  def pbRandom(x)
    v = KIFER.rng_value(x)
    return v unless v.nil?
    v = kifer_pbRandom(x)
    KIFER.rng_note(v)
    return v
  end
end

class PokeBattle_Move
  alias kifer_pbCalcDamage pbCalcDamage unless method_defined?(:kifer_pbCalcDamage)
  def pbCalcDamage(user, target, numTargets = 1)
    logging = false
    holders = []
    begin
      logging = KIFER.enabled? && KIFER.damage_log? && !statusMove? && !user.equal?(target)
      holders = KIFER.innate_holders(user, target) if logging
      logging = false if holders.empty?
    rescue StandardError => e
      KIFER.log("damage log setup failed: #{e.class}: #{e.message}")
      logging = false
    end
    return kifer_pbCalcDamage(user, target, numTargets) unless logging
    rolls = KIFER.rng_record { kifer_pbCalcDamage(user, target, numTargets) }
    begin
      real = target.damageState.calcDamage
      none = KIFER.suppress(:all) { KIFER.dry_damage(self, user, target, numTargets, rolls) }
      check = KIFER.dry_damage(self, user, target, numTargets, rolls)
      parts = []
      holders.each do |b|
        inn = b.active_innates
        inn.uniq.each do |id|
          # copies of one ability are taken off together and named once
          without = KIFER.suppress([b, id]) { KIFER.dry_damage(self, user, target, numTargets, rolls) }
          next if without == real
          n = inn.count(id)
          label = GameData::Ability.get(id).name + (n > 1 ? " x#{n}" : "")
          parts << "#{b.pbThis(true)}'s #{label}: #{without} -> #{real}"
        end
      end
      KIFER.pending_damage[target.object_id] = {
        :text => "#{user.pbThis}'s #{name} on #{target.pbThis(true)}",
        :none => none, :real => real, :check => check, :parts => parts,
        :crit => target.damageState.critical, :rolls => rolls
      }
    rescue StandardError => e
      KIFER.log("damage log failed: #{e.class}: #{e.message}")
    end
  end

  alias kifer_pbReduceDamage pbReduceDamage unless method_defined?(:kifer_pbReduceDamage)
  def pbReduceDamage(user, target)
    kifer_pbReduceDamage(user, target)
    begin
      p = KIFER.pending_damage.delete(target.object_id)
      ds = target.damageState
      if p.nil?
        # Moves with set damage (Dragon Rage, Seismic Toss, Super Fang...)
        # skip the damage formula, so innates can't change them
        return if !KIFER.enabled? || !KIFER.damage_log? || statusMove? || user.equal?(target)
        return if KIFER.innate_holders(user, target).empty?
        line = "Damage: #{user.pbThis}'s #{name} on #{target.pbThis(true)} - set damage #{ds.calcDamage}, " \
               "dealt #{ds.hpLost} (innates can't change set damage)"
        line += " (to the substitute)" if ds.substitute
        KIFER.log(line)
        KIFER.last_damage = { :line => line }
        return
      end
      line = "Damage: #{p[:text]}#{p[:crit] ? ' (critical hit)' : ''} - no innates #{p[:none]}, " \
             "with innates #{p[:real]}, dealt #{ds.hpLost}"
      line += " (to the substitute)" if ds.substitute
      line += " | " + p[:parts].join("; ") if !p[:parts].empty?
      line += " | innates had no effect" if p[:parts].empty? && p[:none] == p[:real]
      line += " | CHECK: a repeat of this hit gave #{p[:check]}" if p[:check] != p[:real]
      KIFER.log(line)
      KIFER.last_damage = { :line => line, :rolls => p[:rolls], :none => p[:none], :real => p[:real] }
    rescue StandardError => e
      KIFER.log("damage log failed: #{e.class}: #{e.message}")
    end
  end
end
