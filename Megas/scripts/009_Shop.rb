#===============================================================================
# Stone shop: Saffron City's Poké Mart sells the stones unlocked so far
# (tiers in data/shop.rb). PIF's shared Mart map asks
# get_mart_exclusive_items(city) for each city's extra items.
#===============================================================================
module Megas   # SILPH_CO_SWITCH: 008_Trainers.rb
  LEAGUE_SWITCH   = 12  unless defined?(LEAGUE_SWITCH)     # PIF: "beat league"

  def self.shop_tier_open?(tier)
    sw = $game_switches
    return false if !sw || !sw[SILPH_CO_SWITCH]
    return sw[LEAGUE_SWITCH] ? true : false if tier == :league
    return ($Trainer ? $Trainer.badge_count : 0) >= tier if tier.is_a?(Integer)
    return true   # :silph
  end

  # Stones on sale now, in table order
  def self.shop_stock
    by_stone = {}
    DATA.each_value { |m| by_stone[m[:stone]] ||= m if m[:stone] }
    SHOP.select { |tier, _| shop_tier_open?(tier) }.values.flatten.select do |s|
      m = by_stone[s]
      m && GameData::Item.exists?(s) && (!m[:er_only] || er?)
    end
  end
end

alias megas_get_mart_exclusive_items get_mart_exclusive_items unless Object.method_defined?(:megas_get_mart_exclusive_items) || Object.private_method_defined?(:megas_get_mart_exclusive_items)
def get_mart_exclusive_items(city)
  items = megas_get_mart_exclusive_items(city)
  return items if city != :SAFFRON
  return items + Megas.shop_stock
end
