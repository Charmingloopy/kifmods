#===============================================================================
# KIF: Elite Redux – ability handlers run for innates too
#   Every BattleHandlers.trigger*Ability(ability, ...) call runs the battler's
#   main ability first (unchanged), then each active innate:
#     :chain – the value the handler returns (speed multiplier, priority,
#              type, crit stage...) is passed on to the next innate
#     :any   – stops at the first ability that returns true (immunities,
#              blocking), so a message shows once
#     :all   – every ability runs (damage multipliers, switch-in, end of round)
#   Owner = the battler whose innates run: an argument index (ability not
#   counted), or [:ally, i] for the "ally" hashes, whose bearer is the ally of
#   argument i that has the ability passed in.
#===============================================================================
module KIFER
  TRIGGERS = {
    :SpeedCalcAbility                    => [0, :chain, 1],
    :WeightCalcAbility                   => [0, :chain, 1],
    :AbilityOnHPDroppedBelowHalf         => [0, :any],
    :StatusCheckAbilityNonIgnorable      => [0, :any],
    :StatusImmunityAbility               => [0, :any],
    :StatusImmunityAbilityNonIgnorable   => [0, :any],
    :StatusImmunityAllyAbility           => [[:ally, 0], :any],
    :AbilityOnStatusInflicted            => [0, :all],
    :StatusCureAbility                   => [0, :all],
    :StatLossImmunityAbility             => [0, :any],
    :StatLossImmunityAbilityNonIgnorable => [0, :any],
    :StatLossImmunityAllyAbility         => [0, :any],
    :AbilityOnStatGain                   => [0, :all],
    :AbilityOnStatLoss                   => [0, :all],
    :PriorityChangeAbility               => [0, :chain, 2],
    :PriorityBracketChangeAbility        => [0, :chain, 1],
    :PriorityBracketUseAbility           => [0, :all],
    :AbilityOnFlinch                     => [0, :all],
    :MoveBlockingAbility                 => [0, :any],
    :MoveImmunityTargetAbility           => [1, :any],
    :MoveBaseTypeModifierAbility         => [0, :chain, 2],
    :AccuracyCalcUserAbility             => [1, :all],
    :AccuracyCalcUserAllyAbility         => [[:ally, 1], :all],
    :AccuracyCalcTargetAbility           => [2, :all],
    :DamageCalcUserAbility               => [0, :all],
    :DamageCalcUserAllyAbility           => [[:ally, 0], :all],
    :DamageCalcTargetAbility             => [1, :all],
    :DamageCalcTargetAbilityNonIgnorable => [1, :all],
    :DamageCalcTargetAllyAbility         => [[:ally, 1], :all],
    :CriticalCalcUserAbility             => [0, :chain, 2],
    :CriticalCalcTargetAbility           => [1, :chain, 2],
    :TargetAbilityOnHit                  => [1, :all],
    :UserAbilityOnHit                    => [0, :all],
    :UserAbilityEndOfMove                => [0, :all],
    :TargetAbilityAfterMoveUse           => [0, :all],
    :EORWeatherAbility                   => [1, :all],
    :EORHealingAbility                   => [0, :all],
    :EOREffectAbility                    => [0, :all],
    :EORGainItemAbility                  => [0, :all],
    :CertainSwitchingUserAbility         => [0, :any],
    :TrappingTargetAbility               => [1, :any],
    :AbilityOnSwitchIn                   => [0, :all],
    :AbilityOnSwitchOut                  => [0, :all],
    :AbilityChangeOnBattlerFainting      => [0, :all],
    :AbilityOnBattlerFainting            => [0, :all],
    :RunFromBattleAbility                => [0, :any],
  }

  def self.ability_id(ability)
    return nil if ability.nil?
    return ability.respond_to?(:id) ? ability.id : ability
  end

  def self.trigger_owner(spec, ability, args)
    if spec.is_a?(Array)   # [:ally, i]
      b = args[spec[1]]
      return nil unless b.respond_to?(:eachAlly)
      want = ability_id(ability)
      hits = []
      b.eachAlly { |a| hits << a if a.instance_variable_get(:@ability_id) == want }
      return hits[0] if hits.length <= 1
      # triples: PIF asks once per ally, in eachAlly order, with only the
      # ability; two allies with the same one are taken in turn
      @ally_turn ||= {}
      k = [b.object_id, want]
      i = @ally_turn[k] = ((@ally_turn[k] || -1) + 1) % hits.length
      return hits[i]
    end
    b = args[spec]
    return b.is_a?(PokeBattle_Battler) ? b : nil
  end

  def self.run_trigger(handlers, orig, spec, ability, args)
    owner = nil
    inns = []
    begin
      owner = trigger_owner(spec[0], ability, args)
      inns = owner.active_innates if owner
    rescue StandardError => e
      log("trigger owner failed: #{e.class}: #{e.message}")
      owner = nil
      inns = []
    end
    return handlers.send(orig, ability, *args) if !owner || inns.empty?
    # PIF's Illusion check on Mega Evolution calls the on-hit trigger with no
    # attacker and no move: the innates' on-hit effects don't apply then
    return handlers.send(orig, ability, *args) if orig == :kifer_triggerTargetAbilityOnHit && (args[0].nil? || args[2].nil?)
    if orig == :kifer_triggerAbilityOnSwitchIn
      # once per switch-in: Skill Swap, Role Play, Trace and Mega Evolution run
      # the main ability's entry again, not the innates' (new innates still do)
      done = owner.instance_variable_get(:@kifer_entry_done) || []
      inns = inns - done
      owner.instance_variable_set(:@kifer_entry_done, done | inns)
      return handlers.send(orig, ability, *args) if inns.empty?
    end
    ret = with_context(owner, nil) { handlers.send(orig, ability, *args) }
    mode = spec[1]
    inns.each do |id|
      probe = worked_probe(owner, args)
      case mode
      when :chain
        args = args.dup
        args[spec[2]] = ret
        before = ret
        ret = with_context(owner, id) { handlers.send(orig, id, *args) }
        worked_check(owner, id, probe, args, ret != before)
      when :any
        break if ret
        ret = with_context(owner, id) { handlers.send(orig, id, *args) }
        # the caller shows the splash after this returns (PIF's status immunity):
        # name this innate there, not the main ability
        owner.instance_variable_set(:@kifer_inline, id) if ret
        worked_check(owner, id, probe, args, ret ? true : false)
      else
        r = with_context(owner, id) { handlers.send(orig, id, *args) }
        ret = r if !ret
        worked_check(owner, id, probe, args, false)
      end
    end
    return ret
  end
end

module KIFER
  # "Worked this battle" notes for KIF's Battle Info (013_BattleInfo.rb): an
  # innate worked when its handler changed the result, showed a message or
  # changed a damage/accuracy multiplier. Not while the battle AI is only
  # estimating. Cheap no-op when Battle Info isn't there.
  def self.track_worked?
    return @track_worked if defined?(@track_worked) && !@track_worked.nil?
    @track_worked = defined?(KIF::BattleInfo) && KIF::BattleInfo.respond_to?(:register_abilities) ? true : false
  end

  def self.worked_probe(owner, args)
    return nil if !track_worked? || KIFER.ai_thinking?
    battle = owner.battle rescue nil
    return nil if !battle
    h = args.find { |a| a.is_a?(Hash) }
    return [battle.instance_variable_get(:@kifer_msgs).to_i, h, h && h.dup]
  rescue StandardError
    return nil
  end

  def self.worked_check(owner, id, probe, _args, changed)
    return if !probe
    battle = owner.battle
    msgs, h, h0 = probe
    worked = changed || battle.instance_variable_get(:@kifer_msgs).to_i > msgs || (h && h != h0)
    note_worked(battle, owner, id) if worked
  rescue StandardError => e
    log("worked note failed: #{e.class}: #{e.message}")
  end

  def self.note_worked(battle, battler, id)
    return if !battle || !battler || !battler.pokemon
    w = (battle.instance_variable_get(:@kifer_worked) || battle.instance_variable_set(:@kifer_worked, {}))
    list = (w[battler.pokemon.object_id] ||= [])
    list << id if !list.include?(id)
  end

  def self.worked?(battle, battler, id)
    w = battle.instance_variable_get(:@kifer_worked)
    return false if !w || !battler.pokemon
    return (w[battler.pokemon.object_id] || []).include?(id)
  end

  # set while the battle AI scores moves / switches (its estimates call the
  # same handlers)
  def self.ai_thinking?
    return (@ai_depth || 0) > 0
  end

  def self.while_ai
    @ai_depth = (@ai_depth || 0) + 1
    return yield
  ensure
    @ai_depth -= 1
  end
end

class << BattleHandlers
  KIFER::TRIGGERS.each do |name, spec|
    meth = :"trigger#{name}"
    next unless method_defined?(meth)
    orig = :"kifer_#{meth}"
    alias_method orig, meth unless method_defined?(orig)
    define_method(meth) do |ability, *args|
      KIFER.run_trigger(self, orig, spec, ability, args)
    end
  end
end
