#===============================================================================
# KIF: Elite Redux: KIF's own "Frostbite" option while ER's frostbite is on
#===============================================================================
# While Innates and "New battle effects" are on, freezing becomes ER's frostbite
# (031_ER_Statuses.rb), so KIF's Battles > "Frostbite" option has nothing
# left to do:
#   - its row is hidden from KIF's Battles menu and the Modules menu
#   - KIF::Mechanics.frostbite? answers true, so a Pokémon that is still
#     Frozen (from an older save, or frozen by something outside the mod)
#     acts as frostbitten, the same as with KIF's option On
#   - that Frozen Pokemon loses 1/8 of its max HP a round, as ER's frostbite
#     does (031), instead of KIF's 1/16
# The option's saved value isn't changed: turning New battle effects off brings
# the row and the player's own choice back.
#===============================================================================
module KIFER
  module KIFFrostbite
    @rows = ObjectSpace::WeakMap.new   # builder proc => row?; dropped with the proc

    def self.er_on?
      return KIFER.feature_on?(:frostbite)
    end

    # Is this KIF options builder the "Frostbite" row? (checked once each)
    def self.frostbite_row?(builder)
      if !@rows.key?(builder)
        opt = (builder.call rescue nil)
        @rows[builder] = opt.respond_to?(:name) && opt.name == _INTL("Frostbite")
      end
      return @rows[builder]
    end
  end
end

if defined?(KIF::Options) && KIF::Options.respond_to?(:entries)
  class << KIF::Options
    alias kifer_kfb_entries entries unless method_defined?(:kifer_kfb_entries)
    def entries(menu)
      list = kifer_kfb_entries(menu)
      return list if !KIFER::KIFFrostbite.er_on?
      return list.reject { |_s, b| KIFER::KIFFrostbite.frostbite_row?(b) }
    end
  end
end

if defined?(KIF::Mechanics) && KIF::Mechanics.respond_to?(:frostbite?)
  class << KIF::Mechanics
    alias kifer_kfb_frostbite? frostbite? unless method_defined?(:kifer_kfb_frostbite?)
    def frostbite?
      return true if KIFER::KIFFrostbite.er_on?
      return kifer_kfb_frostbite?
    end
  end
end

if defined?(PokeBattle_Battle) && PokeBattle_Battle.method_defined?(:kif_frostbite_damage)
  class PokeBattle_Battle
    alias kifer_kfb_kif_frostbite_damage kif_frostbite_damage unless method_defined?(:kifer_kfb_kif_frostbite_damage)
    def kif_frostbite_damage(priority)
      return kifer_kfb_kif_frostbite_damage(priority) if !KIFER::KIFFrostbite.er_on?
      priority.each do |b|
        next if b.fainted? || b.status != :FROZEN || !b.takesIndirectDamage?
        oldHP = b.hp
        b.pbContinueStatus { b.pbReduceHP(KIFER::Statuses.frostbite_damage(b), false) }
        b.pbItemHPHealCheck
        b.pbAbilitiesOnDamageTaken(oldHP)
        b.pbFaint if b.fainted?
      end
    end
  end
end
