#===============================================================================
# AlphaEscort.rb
# Drop-in companion to the AlphaMod script.
# When a wild alpha Pokemon is encountered, there is a chance it spawns with
# one or two escorts — wild Pokemon of the same species or its pre-evolution.
# Escorts are normal (non-alpha) Pokemon.
#===============================================================================

ALPHA_ESCORT_CHANCE        = 20  # Percent chance (0-100) of a first escort spawning
ALPHA_ESCORT_SECOND_CHANCE = 10  # Percent chance (0-100) of a second escort, if first spawned

class PokeBattle_Battle
  alias alpha_escort_pbSetUpSides pbSetUpSides

  def pbSetUpSides
    if wildBattle? && @sideSizes == [1, 1] && @party2.length == 1
      wild_pkmn = @party2[0]

      if wild_pkmn && wild_pkmn.alpha? && rand(100) < ALPHA_ESCORT_CHANCE
        escort1 = pbAlphaCreateEscort(wild_pkmn)

        if escort1
          @party2.push(escort1)
          @party2order.push(1)
          @usedInBattle[1].push(false)
          @initialItems[1].push(escort1.item_id)
          @recycleItems[1].push(nil)
          @belch[1].push(false)
          @battleBond[1].push(false)
          instance_variable_set(:@sideSizes, [1, 2])

          # Roll for a second escort
          if rand(100) < ALPHA_ESCORT_SECOND_CHANCE
            escort2 = pbAlphaCreateEscort(wild_pkmn)

            if escort2
              @party2.push(escort2)
              @party2order.push(2)
              @usedInBattle[1].push(false)
              @initialItems[1].push(escort2.item_id)
              @recycleItems[1].push(nil)
              @belch[1].push(false)
              @battleBond[1].push(false)
              instance_variable_set(:@sideSizes, [1, 3])
            end
          end
        end
      end
    end

    alpha_escort_pbSetUpSides
  end

  private

  def pbAlphaCreateEscort(alpha_pkmn)
    species_data = alpha_pkmn.species_data
    prev_species = species_data.get_previous_species

    escort_species = (prev_species != species_data.species) ? prev_species : species_data.species

    base_level = alpha_pkmn.level
    escort_level = (escort_species == species_data.species) ? base_level : [base_level - 5, 1].max

    escort = Pokemon.new(escort_species, escort_level)
    escort.reset_moves
    return escort
  rescue
    return nil
  end
end
