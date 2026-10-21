
module AlphaEncounters
  module LoadOrder
    FILES = [
      "Core/AlphaBattleFramework.rb",
      "Core/AlphaRaids.rb",
      "Addons/AlphaUI.rb",
      "Addons/AlphaBuffs.rb",
      "Addons/AlphaEvolve.rb",
      "Core/Hordes.rb",
      "Addons/AlphaEscort.rb",
      "Addons/AlphaItems.rb",
    ].freeze

    def self.files
      FILES.dup
    end
  end
end
