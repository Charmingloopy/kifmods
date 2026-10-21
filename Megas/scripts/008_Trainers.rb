#===============================================================================
# Trainers with Mega Stones (Cody): Gym Leaders, the Elite Four and the
# Champion (PIF's GYM_LEADERS_TYPES), and the Rival, all only after Silph Co
# (Cody, 2026-10-19: nobody has Megas before the player can buy stones). Their ace,
# the highest-level Pokémon that has a Mega (the last one on a tie), gets its
# stone at the start of battle. Randomized teams get the same rule. A team
# whose data already gives someone a stone is left alone.
#===============================================================================
module Megas
  RIVAL_TYPES     = [:RIVAL1, :RIVAL2] unless defined?(RIVAL_TYPES)
  SILPH_CO_SWITCH = 228 unless defined?(SILPH_CO_SWITCH)   # PIF: "beat silph co"

  def self.stone_trainer?(trainer)
    return false if !$game_switches || !$game_switches[SILPH_CO_SWITCH]
    t = trainer.trainer_type
    return RIVAL_TYPES.include?(t) || (defined?(::GYM_LEADERS_TYPES) && ::GYM_LEADERS_TYPES.include?(t)) ? true : false
  end

  def self.give_ace_stone(party)
    return if party.any? { |pk| pk && stone_species.key?(pk.item_id) }
    ace = nil
    stone = nil
    party.each do |pk|
      next if !pk || pk.egg? || pk.isFusion?
      _id, m = DATA.find { |_i, d| d[:base] == pk.species && d[:stone] && !d[:primal] && usable?(d) }
      next if !m
      ace, stone = pk, m[:stone] if !ace || pk.level >= ace.level
    end
    ace.item = stone if ace
  end
end

class PokeBattle_Battle
  alias megas_tr_pbStartBattle pbStartBattle unless method_defined?(:megas_tr_pbStartBattle)
  def pbStartBattle
    if trainerBattle?
      party = pbParty(1) || []
      @opponent.each_with_index do |t, i|
        next if !t || !Megas.stone_trainer?(t)
        Megas.give_ace_stone(party.select.with_index { |_pk, j| pbGetOwnerIndexFromPartyIndex(1, j) == i })
      end
    end
    return megas_tr_pbStartBattle   # then Permanent mode's start-of-battle step (003_Battle.rb)
  end
end
