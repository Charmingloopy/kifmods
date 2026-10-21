#===============================================================================
# KIF: Elite Redux – ER's damage rules for moves (data: :rule in er_moves.rb)
#   USE_HIGHEST_OFFENSE: physical when the user's Attack is at least its
#     Sp. Atk (stat stages count), otherwise special.
#   USE_HIGHEST_DAMAGE (Shell Side Arm): physical when Attack / the target's
#     Defense beats Sp. Atk / the target's Sp. Def, otherwise special.
#   The move's category is set for the whole use (damage, contact-based and
#   category-based abilities, screens) and for the AI's damage estimate, then
#   put back. PIF moves: only while Moves is applied and the move is ready.
#===============================================================================
module KIFER
  module DamageRules
    module_function

    def rule(move)
      return nil unless KIFER::Moves.applied?
      id = move.id
      e = KIFER::ER_ONLY_MOVES[id]
      return e[:rule] if e
      e = KIFER::MOVES[id]
      return nil unless e && e[:rule] && KIFER::Moves.ready?(id)
      return e[:rule]
    end

    def ratio(user, target, atk, dfn)
      v = KIFER::ERVersions.staged(user, atk).to_f
      return v if !target
      d = KIFER::ERVersions.staged(target, dfn).to_f
      return d > 0 ? v / d : v
    end

    # 0 physical, 1 special, nil: the move's own
    def category(move, user, target = nil)
      case rule(move)
      when :USE_HIGHEST_OFFENSE
        return KIFER::ERVersions.highest_attack(user) == :ATTACK ? 0 : 1
      when :USE_HIGHEST_DAMAGE
        t = target && !target.equal?(user) ? target : nil
        return ratio(user, t, :ATTACK, :DEFENSE) >= ratio(user, t, :SPECIAL_ATTACK, :SPECIAL_DEFENSE) ? 0 : 1
      end
      return nil
    end

    def with(move, user, target = nil)
      cat = nil
      begin
        cat = category(move, user, target) if move.is_a?(PokeBattle_Move) && user && !move.statusMove?
      rescue StandardError => e
        KIFER.log("damage rule: #{e.class}: #{e.message}")
      end
      return yield if cat.nil?
      old = move.instance_variable_get(:@category)
      move.instance_variable_set(:@category, cat)
      begin
        return yield
      ensure
        move.instance_variable_set(:@category, old)
      end
    end
  end
end

class PokeBattle_Battler
  alias kifer_dr_pbUseMove pbUseMove unless method_defined?(:kifer_dr_pbUseMove)
  def pbUseMove(choice, specialUsage = false)
    move = choice.is_a?(Array) ? choice[2] : nil
    t = choice.is_a?(Array) && choice[3].is_a?(Integer) && choice[3] >= 0 ? @battle.battlers[choice[3]] : nil
    return KIFER::DamageRules.with(move, self, t) { kifer_dr_pbUseMove(choice, specialUsage) }
  end
end

class PokeBattle_AI
  alias kifer_dr_pbRoughDamage pbRoughDamage unless method_defined?(:kifer_dr_pbRoughDamage)
  def pbRoughDamage(move, user, target, *args)
    return KIFER::DamageRules.with(move, user, target) { kifer_dr_pbRoughDamage(move, user, target, *args) }
  end
end
