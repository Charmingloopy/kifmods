# ============================================================
# AlphaMod - Double Move Extension
# All alphas use a scored status move before attacking.
# Falls back to true random when all moves score equally.
# 1-turn cooldown prevents the same status move twice in a row.
# ============================================================

module AlphaMod
  DOUBLE_MOVE_CHANCE = 100
  DEBUG_MODE         = true   # Set to false once working

  ALPHA_STATUS_POOL  = [
    :SWORDSDANCE,
    :CALMMIND,
    :BULKUP,
    :GROWTH,
    :AGILITY,
    :SWAGGER,
    :SCREECH,
    :TOXIC,
    :WILLOWISP,
    :THUNDERWAVE,
    :REFLECT,
    :LIGHTSCREEN,
    :TAILWIND,
    :SOAK,
    :TRICKORTREAT,
    :ROAR,
    :RECOVER
  ]

  # If you add powder moves (e.g. :STUNSPORE, :SLEEPPOWDER, :POISONPOWDER),
  # add this check inside their when block:
  #   return 0 if (target.pbHasType?(PBTypes::GRASS) rescue false)

  def self.debug(msg)
    return unless DEBUG_MODE
    p "[AlphaMod] #{msg}"
  end
	def self.safe_num(value, default = 0)
	  value.is_a?(Numeric) ? value : default
	end
  def self.score_status_move(move_sym, battler, target)
	score = 0
	atk  = safe_num(battler.pokemon.baseStats[:ATTACK] rescue nil)
	satk = safe_num(battler.pokemon.baseStats[:SPATK] rescue nil)

	physical_count = battler.moves.count { |m| m && m.category == 0 }
	special_count  = battler.moves.count { |m| m && m.category == 1 }
    case move_sym

      # ---- Stat boosts (self) ----
    when :SWORDSDANCE
      score += physical_count * 2
      score += 2 if safe_num(atk) >= safe_num(satk)
      score -= 8 if safe_num(battler.stages[PBStats::ATTACK]) >= 2

    when :CALMMIND
      score += special_count * 2
      score += 2 if satk > atk
      score -= 4 if (battler.stages[PBStats::SPATK] rescue 0) >= 2
      score -= 4 if (battler.stages[PBStats::SPDEF] rescue 0) >= 2

    when :BULKUP
      score += physical_count * 2
      score += 2 if atk >= satk
      score -= 4 if (battler.stages[PBStats::ATTACK]  rescue 0) >= 2
      score -= 4 if (battler.stages[PBStats::DEFENSE] rescue 0) >= 2

    when :GROWTH
      score += special_count * 2
      score += 2 if satk > atk
      score -= 8 if (battler.stages[PBStats::SPATK] rescue 0) >= 2

    when :AGILITY
      if target
        battler_speed = (battler.pbSpeed rescue 0)
        target_speed  = (target.pbSpeed  rescue 0)
        score += 4 if safe_num(target_speed) > safe_num(battler_speed)
        score += (physical_count + special_count)
        score -= 6 if (battler.stages[PBStats::SPEED] rescue 0) >= 2
      end

      # ---- Healing (self) ----
    when :RECOVER
      hp_ratio = (battler.hp.to_f / battler.totalhp rescue 1.0)
      return 0 if hp_ratio >= 0.9
      score += ((1.0 - hp_ratio) * 10).round

      # ---- Target debuffs ----
    when :SWAGGER
      if target
        return 0 if (target.pbHasType?(PBTypes::GHOST) rescue false)
        confused = (target.effects[PBEffects::Confusion].to_i > 0 rescue false)
        score   += confused ? 0 : 4
        score   -= 4 if (target.stages[PBStats::ATTACK] rescue 0) >= 2
      end

    when :SCREECH
      if target
        return 0 if (target.pbHasType?(PBTypes::GHOST) rescue false)
        score += physical_count * 2
        score += 2
        score -= 6 if (target.stages[PBStats::DEFENSE] rescue 0) <= -2
      end

      # ---- Status conditions ----
    when :TOXIC
      if target
        return 0 if (target.status != 0 rescue false)
        return 0 if (target.pbHasType?(PBTypes::STEEL)  rescue false)
        return 0 if (target.pbHasType?(PBTypes::POISON) rescue false)
        hp_ratio = (target.hp.to_f / target.totalhp rescue 0.5)
        score += (hp_ratio * 6).round
        score += 2
      end

    when :WILLOWISP
      if target
        return 0 if (target.status != 0 rescue false)
        return 0 if (target.pbHasType?(PBTypes::FIRE)             rescue false)
        return 0 if (target.ability == PBAbilities::FLASHFIRE     rescue false)
        return 0 if (target.ability == PBAbilities::WATERVEIL     rescue false)
        target_atk  = (target.pokemon.baseStats[:ATTACK] rescue 0)
        target_satk = (target.pokemon.baseStats[:SPATK]  rescue 0)
        score += 4 if target_atk > target_satk
        score += 2
      end

    when :THUNDERWAVE
      if target
        return 0 if (target.status != 0 rescue false)
        return 0 if (target.pbHasType?(PBTypes::ELECTRIC)         rescue false)
        return 0 if (target.pbHasType?(PBTypes::GROUND)           rescue false)
        return 0 if (target.ability == PBAbilities::LIGHTNINGROD  rescue false)
        return 0 if (target.ability == PBAbilities::VOLTABSORB    rescue false)
        return 0 if (target.ability == PBAbilities::MOTORDRIVE    rescue false)
        battler_speed = (battler.pbSpeed rescue 0)
        target_speed  = (target.pbSpeed  rescue 0)
        score += 4 if target_speed > battler_speed
        score += 2
      end

      # ---- Screens ----
    when :REFLECT
      if target
        already_up = (battler.pbOwnSide.effects[PBEffects::Reflect] > 0 rescue false)
        score -= 8 if already_up
        target_atk  = (target.pokemon.baseStats[:ATTACK] rescue 0)
        target_satk = (target.pokemon.baseStats[:SPATK]  rescue 0)
        score += 4 if target_atk > target_satk
        score += 2
      end

    when :LIGHTSCREEN
      if target
        already_up = (battler.pbOwnSide.effects[PBEffects::LightScreen] > 0 rescue false)
        score -= 8 if already_up
        target_atk  = (target.pokemon.baseStats[:ATTACK] rescue 0)
        target_satk = (target.pokemon.baseStats[:SPATK]  rescue 0)
        score += 4 if target_satk > target_atk
        score += 2
      end

    when :TAILWIND
      already_up = (battler.pbOwnSide.effects[PBEffects::Tailwind] > 0 rescue false)
      return 0 if already_up
      battler_speed = (battler.pbSpeed rescue 0)
      target_speed  = (target ? (target.pbSpeed rescue 0) : 0)
      score += 4 if target_speed > battler_speed
      score += (physical_count + special_count)
      score -= 4 if (battler.stages[PBStats::SPEED] rescue 0) >= 2

      # ---- Type manipulation ----
    when :SOAK
      if target
        return 0 if (target.pbHasType?(PBTypes::WATER) rescue false)
        se_count = battler.moves.count { |m|
                                         next false unless m && m.category != 2
                                       (PBTypes.effectiveness(m.type, PBTypes::WATER, 0) rescue 8) > 8
                                       }
        return 0 if se_count == 0
        score += se_count * 3
      end

    when :TRICKORTREAT
      if target
        return 0 if (target.pbHasType?(PBTypes::GHOST) rescue false)
        se_count = battler.moves.count { |m|
                                         next false unless m && m.category != 2
                                       (PBTypes.effectiveness(m.type, PBTypes::GHOST, 0) rescue 8) > 8
                                       }
        return 0 if se_count == 0
        score += se_count * 3
      end

      # ---- Utility ----
    when :ROAR
      if target
        return 0 if (target.pbHasType?(PBTypes::GHOST) rescue false)
        pos_stages = [
          PBStats::ATTACK, PBStats::DEFENSE,
          PBStats::SPATK,  PBStats::SPDEF,
          PBStats::SPEED
        ].count { |s| (target.stages[s] rescue 0) > 0 }
        score += (pos_stages * 2) + 1
      end

    end
    score
  end
end

class PokeBattle_Battle
  alias alpha_double_move_pbAttackPhaseMoves pbAttackPhaseMoves

  def pbAttackPhaseMoves
    # Show charging messages (Focus Punch)
    pbPriority.each do |b|
      next unless @choices[b.index][0] == :UseMove && !b.fainted?
      next if b.movedThisRound?
      @choices[b.index][2].pbDisplayChargeMessage(b)
    end

    # Main move processing loop
    loop do
      priority = pbPriority

      # Forced to go next
      advance = false
      priority.each do |b|
        next unless b.effects[PBEffects::MoveNext] && !b.fainted?
        next unless @choices[b.index][0] == :UseMove ||
                    @choices[b.index][0] == :Shift
        next if b.movedThisRound?

        advance = pbProcessAlphaTurn(b)
        break if advance
      end
      return if @decision > 0
      next if advance

      # Regular priority order
      priority.each do |b|
        next if b.effects[PBEffects::Quash] > 0 || b.fainted?
        next unless @choices[b.index][0] == :UseMove ||
                    @choices[b.index][0] == :Shift
        next if b.movedThisRound?

        advance = pbProcessAlphaTurn(b)
        break if advance
      end
      return if @decision > 0
      next if advance

      # Quashed
      quashLevel = 0
      loop do
        quashLevel += 1
        moreQuash = false

        priority.each do |b|
          moreQuash = true if b.effects[PBEffects::Quash] > quashLevel
          next unless b.effects[PBEffects::Quash] == quashLevel && !b.fainted?
          next unless @choices[b.index][0] == :UseMove ||
                      @choices[b.index][0] == :Shift
          next if b.movedThisRound?

          advance = pbProcessAlphaTurn(b)
          break if advance
        end

        break if advance || !moreQuash
      end
      return if @decision > 0
      next if advance

      # Check for all done
      priority.each do |b|
        if !b.fainted? && !b.movedThisRound?
          advance = true if @choices[b.index][0] == :UseMove ||
                            @choices[b.index][0] == :Shift
        end
        break if advance
      end
      next if advance

      # All Pokémon have moved; end the loop
      break
    end
  end

  # Process a battler's turn, including the alpha bonus move.
  def pbProcessAlphaTurn(battler)
    index = battler.index
    choice = @choices[index]

    if defined?(AlphaMod) &&
       battler.alpha? &&
       !battler.fainted? &&
       choice && choice[0] == :UseMove

      chosen_move = choice[2]

      if chosen_move &&
         chosen_move.category != 2 &&
         rand(100) < AlphaMod::DOUBLE_MOVE_CHANCE

        target_index = choice[3]
        target = @battlers[target_index]

        @alpha_last_status_move ||= {}
        last_move = @alpha_last_status_move[battler.index]

        pool = AlphaMod::ALPHA_STATUS_POOL.reject do |sym|
          sym == last_move
        end
        pool = AlphaMod::ALPHA_STATUS_POOL if pool.empty?

        # Randomly choose among the highest-scoring moves.
        scores = pool.map do |sym|
          [sym, AlphaMod.score_status_move(sym, battler, target)]
        end
        best_score = scores.map { |entry| entry[1] }.max
        best_moves = scores.select { |entry| entry[1] == best_score }
        move_sym = best_moves.sample[0]

        AlphaMod.debug("Alpha battler #{index}: bonus move #{move_sym}")

        move_id = PBMoves.const_get(move_sym) rescue nil

        if move_id
          pbmove = PBMove.new(move_id)
          bonus_move = PokeBattle_Move.pbFromPBMove(self, pbmove) rescue nil

          if bonus_move
            @alpha_last_status_move[battler.index] = move_sym

            bonus_choice = [:UseMove, 0, bonus_move, target_index]

            pbDisplayPaused(
              _INTL("{1} surged with alpha energy!", battler.pbThis)
            )

            # Execute the bonus move before the normal attack.
            pbProcessTurn(bonus_choice, false)

            return true if @decision > 0
          end
        end
      end
    end

    # Process the battler's original turn normally.
    return battler.pbProcessTurn(choice)
  end
end
