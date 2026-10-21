#===============================================================================
# Battle/summary sprite while Mega: the mod's own image, shiny-shifted the way
# PIF shifts any sprite. No image for a Mega = the normal sprite.
#===============================================================================
module Megas
  # Path to a file in the mod's Graphics folder the game can load, or nil
  # (relative to the game folder when the mod is inside it)
  def self.graphic(dir, name)
    full = File.join(ROOT, "Graphics", dir, name.to_s)
    return nil if !File.exist?(full + ".png")
    here = Dir.pwd.tr("\\", "/") + "/"
    full = full.tr("\\", "/")
    return full.start_with?(here) ? full[here.length..-1] : full
  end

  def self.sprite_path(id); graphic("Battlers", id); end

  # A shiny Mega's hue. Not PIF's shiftAllColors: that saves its result as the
  # base species' shiny file (Graphics/Battlers/Shiny/<dex>/<dex>.png), which
  # every normal shiny of the species then shows. Species with colour rules
  # (text, not a number) get PIF's plain hue method instead.
  def self.shiny_hue(pkmn)
    dex = pkmn.id_number
    off = GameData::Species.calculateShinyHueOffset(dex, pkmn.body_shiny, pkmn.head_shiny)
    return off if off.is_a?(Numeric)
    body = dex > Settings::NB_POKEMON ? getBodyID(dex) : dex
    head = dex > Settings::NB_POKEMON ? getHeadID(dex, body) : dex
    return GameData::Species.calculateShinyHueOffsetDefaultMethod(body, head, dex, pkmn.body_shiny, pkmn.head_shiny).to_i
  end

  # KIF's shiny engine when it draws this Pokémon, else PIF's hue
  def self.make_shiny!(bmp, pkmn)
    kif = defined?(KIF::Shiny) && KIF::Shiny.kif_render?(pkmn)
    KIF::Shiny.privatize(bmp) if defined?(KIF::Shiny)
    bmp.shiftColors(shiny_hue(pkmn)) if !kif || KIF::Shiny.decide(pkmn)[0]
    KIF::Shiny.colorize!(bmp, pkmn, :sprite, true) if kif
    return bmp
  end
end

module GameData
  class Species
    class << self
      alias megas_sprite_bitmap_from_pokemon sprite_bitmap_from_pokemon unless method_defined?(:megas_sprite_bitmap_from_pokemon)
      def sprite_bitmap_from_pokemon(pkmn, *args)
        id = pkmn && !pkmn.egg? && Megas.current(pkmn)
        return Megas.decorate!(megas_sprite_bitmap_from_pokemon(pkmn, *args)) if id.is_a?(Array)   # Mega fusion: badge + aura
        path = id && Megas.sprite_path(id)
        return megas_sprite_bitmap_from_pokemon(pkmn, *args) if !path
        bmp = AnimatedBitmap.new(path)   # 192px file (ER 64px at 3x, like PIF) drawn as is
        make_shiny = args[2] != false   # 4th argument (KIF): false = draw it not shiny
        Megas.make_shiny!(bmp, pkmn) if make_shiny && pkmn.shiny?
        return bmp
      end
    end
  end
end

# Stone icons (Graphics/Items in the mod folder)
module GameData
  class Item
    class << self
      alias megas_icon_filename icon_filename unless method_defined?(:megas_icon_filename)
      def icon_filename(item)
        data = item && try_get(item)
        return megas_icon_filename(item) if !data || !Megas.stone_species.key?(data.id)   # stones only: no disk check per item
        path = Megas.graphic("Items", data.id)
        path ||= Megas.graphic("Items", "MEGASTONE") if data.instance_variable_get(:@megas_own)   # a stone with no icon of its own
        return path || megas_icon_filename(item)
      end
    end
  end
end
