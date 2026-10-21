#===============================================================================
# Mega Stones as items. Registered after every game data load.
# A stone another mod already added (same symbol) is left as it is.
#===============================================================================
module Megas
  FIRST_ITEM_NUMBER = 7000 unless defined?(FIRST_ITEM_NUMBER)   # free range; Yoko's Mega Stones mod uses 6000+

  # stone => the species it Mega Evolves
  def self.stone_species
    @stone_species ||= DATA.each_with_object({}) { |(_id, m), h| h[m[:stone]] = m[:base] if m[:stone] }
  end

  def self.register_items
    used = {}
    GameData::Item.each { |it| used[it.id_number] = true }
    n = FIRST_ITEM_NUMBER
    DATA.each_value do |m|
      # the item randomizer never hands out a Mega Stone (no Megas before Silph Co)
      if m[:stone] && !m[:primal] && defined?(NON_RANDOMIZE_ITEMS) && !NON_RANDOMIZE_ITEMS.include?(m[:stone])
        NON_RANDOMIZE_ITEMS << m[:stone]
      end
      next if !m[:stone] || GameData::Item.exists?(m[:stone])   # Rayquaza needs a move, not a stone
      n += 1 while used[n]
      used[n] = true
      name = m[:stone_name]
      species = GameData::Species.get(m[:base]).real_name
      desc = m[:primal] ? _INTL("Have {1} hold it, and it reverts to its Primal form in battle.", species) :
                          _INTL("Have {1} hold it, and it can Mega Evolve once in battle.", species)
      GameData::Item.register({ :id => m[:stone], :id_number => n, :name => name,
                                :name_plural => name + "s", :pocket => 1, :price => SHOP_PRICE,
                                :description => desc, :field_use => 0, :battle_use => 0,
                                :type => m[:primal] ? 0 : 12 })   # 12: PIF's Mega Stone type (Fling)
      GameData::Item::DATA[m[:stone]].instance_variable_set(:@megas_own, true)   # gets the generic icon if it has none
      MessageTypes.set(MessageTypes::Items, n, name)
      MessageTypes.set(MessageTypes::ItemPlurals, n, name + "s")
      MessageTypes.set(MessageTypes::ItemDescriptions, n, desc)
    end
  end
end

KIF::DataLoad.after_load_all("Megas: stones") { Megas.register_items }
# Data may already be loaded when the mod loads (reload, Mod Manager)
Megas.register_items if GameData::Item.respond_to?(:exists?) && GameData::Item.exists?(:POTION)
