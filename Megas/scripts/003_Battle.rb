#===============================================================================
# Mega Evolution in battle. PIF ships Essentials' Mega code but switches it off
# in pbCanMegaEvolve?; this turns it back on with its own rules, minus the
# Mega Ring (the stone alone is enough).
#===============================================================================
class PokeBattle_Battle
  def pbCanMegaEvolve?(idxBattler)
    battler = @battlers[idxBattler]
    return false if !battler || !battler.hasMega?
    return false if Megas.permanent? && Megas.available(battler.pokemon, :mega)   # Permanent: already Mega from the start
    return false if wildBattle? && opposes?(idxBattler)
    return false if battler.effects[PBEffects::SkyDrop] >= 0
    side  = battler.idxOwnSide
    owner = pbGetOwnerIndexFromBattlerIndex(idxBattler)
    return @megaEvolution[side][owner] == -1   # -2 once this trainer has Mega Evolved
  end
end

# Mega and Primal Pokémon turn back at the end of battle (faint and capture
# already do it); Permanent mode makes the player's holders Mega again after
class PokeBattle_RealBattlePeer
  alias megas_pbOnLeavingBattle pbOnLeavingBattle unless method_defined?(:megas_pbOnLeavingBattle)
  def pbOnLeavingBattle(battle, pkmn, usedInBattle, endBattle = false)
    # Permanent: a Mega that stays one isn't turned back (that would reset its
    # KIF-ER ability pick); the sync after the battle sorts out the rest
    pkmn.makeUnmega if endBattle && pkmn && Megas.current(pkmn) && !(Megas.permanent? && pkmn.mega?)
    megas_pbOnLeavingBattle(battle, pkmn, usedInBattle, endBattle)
  end
end

class PokeBattle_Battle
  # Permanent mode: each trainer's holders are Mega before anyone is sent out
  # (wild Pokémon never Mega Evolve)
  alias megas_pbStartBattle pbStartBattle unless method_defined?(:megas_pbStartBattle)
  def pbStartBattle
    if Megas.permanent?
      Megas.trainer_parties(self, 0).each { |party| Megas.sync(party) }   # player, partner, rentals
      Megas.trainer_parties(self, 1).each { |party| Megas.sync(party) } if trainerBattle?
    end
    return megas_pbStartBattle
  end

  # PIF only resets the player's side (party 0); trainers' Pokémon turn back
  # too, so a reused party never starts a battle already Mega
  alias megas_pbEndOfBattle pbEndOfBattle unless method_defined?(:megas_pbEndOfBattle)
  def pbEndOfBattle
    (pbParty(1) || []).each { |pkmn| pkmn.makeUnmega if pkmn && Megas.current(pkmn) }
    ret = megas_pbEndOfBattle
    Megas.sync($Trainer.party) if Megas.permanent? && $Trainer
    return ret
  end

  # Manual Primal: the Mega button reverts Kyogre / Groudon instead. It
  # doesn't use up the trainer's Mega Evolution.
  alias megas_pbMegaEvolve pbMegaEvolve unless method_defined?(:megas_pbMegaEvolve)
  def pbMegaEvolve(idxBattler)
    b = @battlers[idxBattler]
    pk = b && b.pokemon
    if pk && !Megas.available(pk, :mega) && Megas.available(pk, :primal)
      side  = b.idxOwnSide
      owner = pbGetOwnerIndexFromBattlerIndex(idxBattler)
      Megas.primal_now = true
      begin
        pbPrimalReversion(idxBattler)
      ensure
        Megas.primal_now = false
      end
      @megaEvolution[side][owner] = -1 if @megaEvolution[side][owner] == idxBattler
      return
    end
    return megas_pbMegaEvolve(idxBattler)
  end
end

module Megas
  # One side's Pokémon split by trainer (one party per trainer, for One per party)
  def self.trainer_parties(battle, side)
    party = battle.pbParty(side) || []
    groups = Hash.new { |h, k| h[k] = [] }
    party.each_with_index { |pk, i| groups[battle.pbGetOwnerIndexFromPartyIndex(side, i)] << pk }
    return groups.values
  end
end

# A stone can't be knocked off, stolen or swapped while it can Mega Evolve its holder
# (while Mega, PIF's own check already covers it through species_data.mega_stone)
class PokeBattle_Battler
  alias megas_unlosableItem? unlosableItem? unless method_defined?(:megas_unlosableItem?)
  def unlosableItem?(check_item)
    if check_item && !@effects[PBEffects::Transform] && @pokemon && !@pokemon.mega?
      sp = Megas.stone_species[check_item]
      return true if sp && (sp == @pokemon.species || (@pokemon.isFusion? && Megas.fusion_halves(@pokemon).include?(sp)))
    end
    return megas_unlosableItem?(check_item)
  end
end

# Permanent mode outside battle: the Summary shows the party as it will battle
# (a stone given or taken, party order changed)
class PokemonSummary_Scene
  alias megas_pbStartScene pbStartScene unless method_defined?(:megas_pbStartScene)
  def pbStartScene(party, partyindex, inbattle = false, *args)
    Megas.sync($Trainer.party) if Megas.permanent? && !inbattle && $Trainer && party.equal?($Trainer.party)
    return megas_pbStartScene(party, partyindex, inbattle, *args)
  end
end

# Mega Evolution message without the Mega Ring (Cody: "Charizard's
# Charizardite X is reacting!"); PIF's text still has the trainer and ring
module Megas
  MEGA_TEXT = "{1}'s {2} is reacting to {3}'s {4}!" unless defined?(MEGA_TEXT)
  unless @mega_text_swapped
    KIF::TextSwap.add(MEGA_TEXT) { "{1}'s {2} is reacting!" }
    @mega_text_swapped = true
  end
end
