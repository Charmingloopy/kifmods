
  ALPHA_MID_EVOLVE_HP_THRESHOLD = 50  # HP percent (0-100) below which evolution can trigger
  ALPHA_MID_EVOLVE_CHANCE_MIN   = 50  # Percent chance at the threshold HP level
  ALPHA_MID_EVOLVE_CHANCE_MAX   = 75  # Percent chance at 1 HP
  ALPHA_MID_EVOLVE_HEAL_TO      = 50  # HP percent to heal back up to on evolution

  class PokeBattle_Battle
    alias alpha_evolve_pbEndOfRoundPhase pbEndOfRoundPhase

    def pbEndOfRoundPhase
      alpha_evolve_pbEndOfRoundPhase

      return if !wildBattle?

      eachOtherSideBattler(0) do |b|
        next if !b.pokemon || !b.pokemon.alpha? || b.fainted?
        next if b.pokemon.instance_variable_get(:@alpha_evolved)  # only evolve once

        hp_percent = b.hp * 100 / b.totalhp
        next if hp_percent >= ALPHA_MID_EVOLVE_HP_THRESHOLD

        # Scale chance linearly between MIN (at threshold) and MAX (at 0 HP)
        hp_ratio = hp_percent.to_f / ALPHA_MID_EVOLVE_HP_THRESHOLD
        chance   = (ALPHA_MID_EVOLVE_CHANCE_MAX - (ALPHA_MID_EVOLVE_CHANCE_MAX - ALPHA_MID_EVOLVE_CHANCE_MIN) * hp_ratio).round
        next if rand(100) >= chance

        valid_evos = []
        b.pokemon.species_data.get_evolutions(true).each do |evo|
          next if evo[3]  # skip prevolution entries
          valid_evos << evo[0]
        end
        next if valid_evos.empty?

        new_species = valid_evos.sample
        old_name    = b.name

        b.pokemon.instance_variable_set(:@alpha_evolved, true)

        pbDisplay(_INTL("The wild {1} is evolving!", old_name))

        pbPlayAlphaEvolveAnimation(b,new_species)

        # Recalculate stats for new species then sync battler
        b.pokemon.calc_stats

        b.pbUpdate(true)

        b.name = b.pokemon.name
        b.battle.scene.pbRefreshOne(b.index)
        # Heal up to ALPHA_MID_EVOLVE_HEAL_TO percent of the new max HP
        heal_target = (b.totalhp * ALPHA_MID_EVOLVE_HEAL_TO / 100.0).round
        if b.hp < heal_target
          old_hp = b.hp
          b.hp   = heal_target
          @scene.pbHPChanged(b, old_hp)
        end

        pbDisplay(_INTL("The wild {1} evolved into {2}!", old_name, b.name))
      end
    end
  end
