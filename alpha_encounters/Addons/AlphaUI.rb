# ============================================================
# AlphaUI - Visual / UI layer for Alpha Encounters
# All display-related class modifications live here so that
# the core logic file stays free of rendering concerns.
# ============================================================

# ---- EBDX-specific UI (guarded so vanilla scenes are unaffected) ----------

if defined?(PokeBattle_SceneEBDX)

  class PokeBattle_SceneEBDX < PokeBattle_Scene
    def initializeSprites
      # Player back sprites
      @battle.player.each_with_index do |pl, i|
        plfile = GameData::TrainerType.player_back_sprite_filename(pl.trainer_type)
        pbAddSprite("player_#{i}", 0, 0, plfile, @viewport)
        if @sprites["player_#{i}"].bitmap.nil?
          @sprites["player_#{i}"].bitmap = Bitmap.new(2, 2)
        end
        @sprites["player_#{i}"].x = 40 + i*100
        @sprites["player_#{i}"].y = Graphics.height - @sprites["player_#{i}"].bitmap.height
        @sprites["player_#{i}"].z = 50
        @sprites["player_#{i}"].opacity = 0
        @sprites["player_#{i}"].src_rect.width /= 5 if @sprites["player_#{i}"].bitmap.width > @sprites["player_#{i}"].bitmap.height
      end

      # Trainer front sprites (using basic Sprite for KIF compatibility)
      if @battle.opponent
        @battle.opponent.each_with_index do |t, i|
          trfile = GameData::TrainerType.front_sprite_filename(t.trainer_type)
          pbAddSprite("trainer_#{i}", 0, 0, trfile, @viewport)
          @sprites["trainer_#{i}"].z = 100
          if @sprites["trainer_#{i}"].bitmap
            @sprites["trainer_#{i}"].ox = @sprites["trainer_#{i}"].src_rect.width / 2
            @sprites["trainer_#{i}"].oy = @sprites["trainer_#{i}"].bitmap.height
          end
          @sprites["trainer_#{i}"].tone = Tone.new(-255, -255, -255, -255)
        end
      end

      # Pokemon sprites (using KIF's native PokemonBattlerSprite)
      battleAnimations = ($PokemonSystem.battlescene == 0) rescue true
      @battlers.each_with_index do |b, i|
        next if !b
        sideSize = @battle.pbSideSize(i % 2)
        @sprites["pokemon_#{i}"] = PokemonBattlerSprite.new(@viewport, sideSize, i, battleAnimations)
        @sprites["pokemon_#{i}"].z = 100 + i
        if b and b.alpha?
          @sprites["pokemon_#{i}"].z = 175 + i
        end
        @sprites["pokemon_#{i}"].ebdx_position_disabled = true if @sprites["pokemon_#{i}"].respond_to?(:ebdx_position_disabled=)
        @sprites["shadow_#{i}"] = PokemonBattlerShadowSprite.new(@viewport, sideSize, i) rescue nil
        @sprites["shadow_#{i}"].visible = false if @sprites["shadow_#{i}"]
      end
      loadWildBitmaps
    end
  end

  class BattleSceneRoom
    alias alpha_ui_daylightTint daylightTint
    def daylightTint
      if $PokemonTemp.encounterIsAlphaPokemon == true
        tintTone = Tone.new(100, -125, -125)
        @daylightTone = tintTone
      end

      if !@data["outdoor"] && !@data["sky"]
        return
      end

      if !defined?(PBDayNight)
        return
      end

      isNight = false
      isEvening = false
      begin
        isNight = PBDayNight.isNight?
        isEvening = PBDayNight.isEvening? || PBDayNight.isMorning?
      rescue => e
      end

      tintTone = Tone.new(0, 0, 0)
      if isNight && !@sunny
        tintTone = Tone.new(-120, -100, -60)
      elsif isEvening && !@sunny
        tintTone = Tone.new(-16, -52, -56)
      end

      if $PokemonTemp.encounterIsAlphaPokemon == true
        tintTone = Tone.new(100, -125, -125)
        @daylightTone = tintTone
      end

      @daylightTone = tintTone

      treeGrassCount = 0
      for key in @sprites.keys
        next if !@sprites[key]
        next if key.include?("trainer") || key.include?("battler") || key.include?("pokemon")
        next if key.include?("sky") || key.include?("sun") || key.include?("star") || key.include?("cloud") || key.include?("Light")
        next if @data[key].is_a?(Hash) && @data[key].has_key?(:shading) && !@data[key][:shading]
        @sprites[key].tone = tintTone.clone
        if key.include?("tree") || key.include?("grass")
          treeGrassCount += 1
        end
      end
    end
  end

  class DataBoxEBDX < SpriteWrapper
    alias alpha_ebdxrefresh refresh
    def refresh
      return if self.disposed?
      @pokemon = @battler.displayPokemon
      return if @pokemon.nil?
      @hidden = EliteBattle.get_data(@pokemon.species, :Species, :HIDENAME, (@pokemon.form rescue 0)) && !$Trainer.owned?(@pokemon.species)
      return if !@loaded
      self.updateHpBar
      @sprites["textName"].bitmap.clear
      str = ""
      str = _INTL("♂") if @pokemon.gender == 0 && !@hidden
      str = _INTL("♀") if @pokemon.gender == 1 && !@hidden
      w = @sprites["textName"].bitmap.text_size("#{@battler.name.force_encoding("UTF-8")}#{str.force_encoding("UTF-8")}Lv.#{@pokemon.level}").width
      o = (w > @hpBarWidth + 4) ? (w-(@hpBarWidth + 4))/2.0 : 0; o = o.ceil
      str = @battler.name.nil? ? "" : @battler.name
      str += " "
      color = @pokemon.shiny? ? Color.new(222,197,95) : Color.white
      pbDrawOutlineText(@sprites["textName"].bitmap,18-o,3,@sprites["textName"].bitmap.width-40,@sprites["textName"].bitmap.height,str,color,Color.new(0,0,0,125),0)
      x = @sprites["textName"].bitmap.text_size(str).width + 18
      str = ""
      str = _INTL("♂") if @pokemon.gender == 0 && !@hidden
      str = _INTL("♀") if @pokemon.gender == 1 && !@hidden
      color = (@pokemon.gender == 0) ? Color.new(53,107,208) : Color.new(180,37,77)
      pbDrawOutlineText(@sprites["textName"].bitmap,x-o,3,@sprites["textName"].bitmap.width-40,@sprites["textName"].bitmap.height,str,color,Color.new(0,0,0,125),0)
      str = "Lv.#{@battler.level}"
      pbDrawOutlineText(@sprites["textName"].bitmap,18+o,3,@sprites["textName"].bitmap.width-40,@sprites["textName"].bitmap.height,str,Color.white,Color.new(0,0,0,125),2)
      if @battler.mega?
        @sprites["mega"].bitmap = @megaBmp.clone
      elsif @battler.primal?
        @sprites["mega"].bitmap = @prKyogre.clone if @battler.isSpecies?(:KYOGRE)
        @sprites["mega"].bitmap = @prGroudon.clone if @battler.isSpecies?(:GROUDON)
      elsif @sprites["mega"].bitmap
        @sprites["mega"].bitmap.clear
        @sprites["mega"].bitmap = nil
      end
      self.updateHpBar
      self.updateExpBar

      # Alpha indicator (separate from Mega/Primal icon)
      if @pokemon && @pokemon.alpha?
        str = @battler.name.nil? ? "" : @battler.name
        str += " "
        color = @pokemon.shiny? ? Color.new(255, 197, 95) : Color.red

        pbDrawOutlineText(
          @sprites["textName"].bitmap,
          18-o, 3,
          @sprites["textName"].bitmap.width-40,
          @sprites["textName"].bitmap.height,
          str, color, Color.new(0, 0, 0, 125), 0
        )

        # Create the Alpha sprite using the Mega sprite's viewport
        megaSprite = @sprites["mega"]

		if !@sprites["alpha"]
		  viewport = megaSprite ? megaSprite.viewport : nil
		  @sprites["alpha"] = Sprite.new(viewport)
		  @sprites["alpha"].z = megaSprite ? megaSprite.z + 1 : 101

		  # Required by EBDX's relative positioning system
		  @sprites["alpha"].ex = 0
		  @sprites["alpha"].ey = 0
		end

        alphaSprite = @sprites["alpha"]

        if !alphaSprite.bitmap
          alphaSprite.bitmap = pbBitmap("Mods/alpha_encounters/Graphics/alpha")
        end

        # Position Alpha relative to the Mega/Primal icon
        if megaSprite && megaSprite.visible && megaSprite.bitmap
          alphaSprite.x = megaSprite.x + megaSprite.bitmap.width
          alphaSprite.y = megaSprite.y
        elsif megaSprite
          alphaSprite.x = megaSprite.x
          alphaSprite.y = megaSprite.y
        end

        alphaSprite.visible = true
      elsif @sprites["alpha"]
        @sprites["alpha"].visible = false
      end

  end

end
end
 # if defined?(PokeBattle_SceneEBDX)
class PokemonSprite < SpriteWrapper
def applyAlphaTint(pokemon)
  if pokemon && pokemon.respond_to?(:alpha?) && pokemon.alpha?
    self.color = Color.new(255, 40, 40, 100)
  else
    self.color = Color.new(0, 0, 0, 0)
  end
end
  def setPokemonBitmapPIFSprite(pif_sprite)
    @_iconbitmap.dispose if @_iconbitmap
    @_iconbitmap = nil
    spriteLoader = BattleSpriteLoader.new
    animatedBitmap = spriteLoader.load_pif_sprite_directly(pif_sprite)
    @_iconbitmap = SpriteWrapper.new
    @_iconbitmap.bitmap = animatedBitmap.bitmap if animatedBitmap&.bitmap

    self.bitmap = (@_iconbitmap) ? @_iconbitmap.bitmap : nil
applyAlphaTint(pokemon)
changeOrigin
  end

  def setPokemonBitmap(pokemon, back = false)
    # Dispose of existing icon bitmap if it exists
    @_iconbitmap.dispose if @_iconbitmap
    @_iconbitmap = nil
    return if !pokemon
    base_bitmap = (pokemon) ? GameData::Species.sprite_bitmap_from_pokemon(pokemon, back) : nil
    if pokemon.hat
      new_bitmap = Bitmap.new(base_bitmap.width, base_bitmap.height)
      new_bitmap.blt(0, 0, base_bitmap.bitmap, base_bitmap.bitmap.rect)
      add_hat_to_bitmap(new_bitmap, pokemon.hat, pokemon.hat_x, pokemon.hat_y, 1, pokemon.hat_mirrored_horizontal,pokemon.hat_mirrored_vertical)
      @_iconbitmap = SpriteWrapper.new
      @_iconbitmap.bitmap = new_bitmap
    else
      # No hat, just use the base bitmap
      @_iconbitmap = base_bitmap
    end

    # Assign the bitmap to the sprite
    self.bitmap = (@_iconbitmap) ? @_iconbitmap.bitmap : nil
applyAlphaTint(pokemon)
changeOrigin
  end


  def setPokemonBitmapFromId(id, back = false, shiny = false, bodyShiny = false, headShiny = false,spriteform_body=nil,spriteform_head=nil)
    @_iconbitmap.dispose if @_iconbitmap
    @_iconbitmap = GameData::Species.sprite_bitmap_from_pokemon_id(id, back, shiny, bodyShiny, headShiny)
    self.bitmap = (@_iconbitmap) ? @_iconbitmap.bitmap : nil
applyAlphaTint(pokemon)
changeOrigin
  end



end
# ---- Vanilla battle data box -----------------------------------------------
class PokeBattle_Scene
def pbApplyAlphaTint(idxBattler, pokemon = nil)
  sprite = @sprites["pokemon_#{idxBattler}"]
  return if !sprite

  if pokemon && pokemon.respond_to?(:alpha?) && pokemon.alpha?
    sprite.color = Color.new(250, 30, 30, 100)
  else
    sprite.color = Color.new(0, 0, 0, 0)
  end
end
  def pbUpdate(cw=nil)
    pbGraphicsUpdate
    pbInputUpdate
    pbFrameUpdate(cw)
	pbUpdateAlphaTints
  end
def pbUpdateAlphaTints
  @battle.battlers.each_with_index do |battler, i|
    next if !battler
    sprite = @sprites["pokemon_#{i}"]
    next if !sprite || sprite.disposed?

    if battler.pokemon && battler.pokemon.alpha?
      sprite.color = Color.new(250, 30, 30, 100)
    else
      sprite.color = Color.new(0, 0, 0, 0)
    end
  end
end
  def pbChangePokemon(idxBattler,pkmn)
    idxBattler = idxBattler.index if idxBattler.respond_to?("index")
    pkmnSprite   = @sprites["pokemon_#{idxBattler}"]
    shadowSprite = @sprites["shadow_#{idxBattler}"]
    back = !@battle.opposes?(idxBattler)
    shadowSprite.setPokemonBitmap(pkmn)
    pkmnSprite.setPokemonBitmap(pkmn,back)
    pkmnSprite.mirror=true if back
    # Set visibility of battler's shadow
    shadowSprite.visible = true#pkmn.species_data.shows_shadow? if shadowSprite #&& !back
	pbApplyAlphaTint(idxBattler, pkmn)
  end
  end
class PokemonDataBox < SpriteWrapper
  def refresh
    self.bitmap.clear
    return if !@battler.pokemon
    textPos = []
    imagePos = []
    self.bitmap.blt(0,0,@databoxBitmap.bitmap,Rect.new(0,0,@databoxBitmap.width,@databoxBitmap.height))
    nameWidth = self.bitmap.text_size(@battler.name).width
    nameOffset = 0
    nameOffset = nameWidth-116 if nameWidth>116
    textPos.push([@battler.name,@spriteBaseX+8-nameOffset,0,false,NAME_BASE_COLOR,NAME_SHADOW_COLOR])
    kuraygender1t = "♂"
    kuraygender2t = "♀"
    kuraygender1r = [55, 148, 229]
    kuraygender1s = [68, 98, 125]
    kuraygender2r = [229, 55, 203]
    kuraygender2s = [137, 73, 127]
    if @battler.displayGenderPizza
      imagePos.push(["Graphics/Pictures/Storage/gender4", @spriteBaseX+126-18, 5])
    else
      case @battler.displayGender
      when 0
        textPos.push([_INTL(kuraygender1t), @spriteBaseX+126, 0, false, Color.new(kuraygender1r[0], kuraygender1r[1], kuraygender1r[2]), Color.new(kuraygender1s[0], kuraygender1s[1], kuraygender1s[2])])
      when 1
        textPos.push([_INTL(kuraygender2t), @spriteBaseX+126, 0, false, Color.new(kuraygender2r[0], kuraygender2r[1], kuraygender2r[2]), Color.new(kuraygender2s[0], kuraygender2s[1], kuraygender2s[2])])
      when 2
        imagePos.push(["Graphics/Pictures/Storage/gender3", @spriteBaseX+126-14, 14])
      end
    end
    pbDrawTextPositions(self.bitmap,textPos)
    show_level = true
    if $game_switches[SWITCH_NO_LEVELS_MODE] && ($PokemonSystem.showlevel_nolevelmode && $PokemonSystem.showlevel_nolevelmode == 0)
      show_level = false
    end
    imagePos.push(["Graphics/Pictures/Battle/overlay_lv",@spriteBaseX+140,16]) if show_level
    pbDrawNumber(@battler.level,self.bitmap,@spriteBaseX+162,16) if show_level
    if @battler.shiny? || @battler.fakeshiny?
      shinyX = (@battler.opposes?(0)) ? 206 : -6
      shinyY = 35
      if $PokemonSystem.typedisplay != 0
        shinyX = (@battler.opposes?(0)) ? -8 : -6
        shinyY = 13
      end
      addShinyStarsToGraphicsArray(imagePos,@spriteBaseX+shinyX,shinyY, @battler.pokemon.bodyShiny?,@battler.pokemon.headShiny?,@battler.pokemon.debugShiny?,nil,nil,nil,nil,false,false,@battler.pokemon.fakeshiny?,[@battler.pokemon.shinyR?,@battler.pokemon.shinyG?,@battler.pokemon.shinyB?,@battler.pokemon.shinyKRS?])
    end
    if @battler and @battler.alpha?
      imagePos.push([sprintf("Mods/alpha_encounters/Graphics/alpha"),@spriteBaseX+16,34])
    end
    if @battler.mega?
      imagePos.push(["Graphics/Pictures/Battle/icon_mega",@spriteBaseX+8,34])
    elsif @battler.primal?
      primalX = (@battler.opposes?) ? 208 : -28
      if @battler.isSpecies?(:KYOGRE)
        imagePos.push(["Graphics/Pictures/Battle/icon_primal_Kyogre",@spriteBaseX+primalX,4])
      elsif @battler.isSpecies?(:GROUDON)
        imagePos.push(["Graphics/Pictures/Battle/icon_primal_Groudon",@spriteBaseX+primalX,4])
      end
    end
    if @battler.owned? && @battler.opposes?(0)
      imagePos.push(["Graphics/Pictures/Battle/icon_own",@spriteBaseX-8,42])
    end
    pbDrawImagePositions(self.bitmap,imagePos)
    refreshHP
    refreshExp
    refreshStatus
    if $PokemonSystem.typedisplay != 0 && $PokemonSystem.typedisplay != nil
      refreshtypeDisplay
    end
  end
end

# ---- Storage screen --------------------------------------------------------

class PokemonStorageScene
  def pbUpdateOverlay(selection, party = nil)
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    buttonbase = Color.new(248, 248, 248)
    buttonshadow = Color.new(80, 80, 80)
    pbDrawTextPositions(overlay, [
      [_INTL("Party: {1}", (@storage.party.length rescue 0)), 270, 326, 2, buttonbase, buttonshadow, 1],
      [_INTL("Exit"), 446, 326, 2, buttonbase, buttonshadow, 1],
    ])
    pokemon = nil
    if @screen.pbHolding? && !@screen.fusionMode
      pokemon = @screen.pbHeldPokemon
    elsif selection >= 0
      pokemon = (party) ? party[selection] : @storage[@storage.currentBox, selection]
    end
    if !pokemon
      @sprites["pokemon"].visible = false
      return
    end
    @sprites["pokemon"].visible = true
    base = Color.new(88, 88, 80)
    shadow = Color.new(168, 184, 184)
    nonbase = Color.new(208, 208, 208)
    nonshadow = Color.new(224, 224, 224)
    pokename = pokemon.name
    textstrings = [
      [pokename, 10, 2, false, base, shadow]
    ]
    if !pokemon.egg?
      imagepos = []
      kuraygender1t = "♂"
      kuraygender2t = "♀"
      kuraygender1r = [55, 148, 229]
      kuraygender1s = [68, 98, 125]
      kuraygender2r = [229, 55, 203]
      kuraygender2s = [137, 73, 127]
      if pokemon.pizza?
        imagepos.push(["Graphics/Pictures/Storage/gender4", 136, 9])
      elsif pokemon.male?
        textstrings.push([_INTL(kuraygender1t), 148, 2, false, Color.new(kuraygender1r[0], kuraygender1r[1], kuraygender1r[2]), Color.new(kuraygender1s[0], kuraygender1s[1], kuraygender1s[2])])
      elsif pokemon.female?
        textstrings.push([_INTL(kuraygender2t), 148, 2, false, Color.new(kuraygender2r[0], kuraygender2r[1], kuraygender2r[2]), Color.new(kuraygender2s[0], kuraygender2s[1], kuraygender2s[2])])
      elsif pokemon.genderless?
        imagepos.push(["Graphics/Pictures/Storage/gender3", 136, 15])
      end
      imagepos.push(["Graphics/Pictures/Storage/overlay_lv", 6, 246])
      textstrings.push([pokemon.level.to_s, 28, 228, false, base, shadow])
      if pokemon.ability
        textstrings.push([pokemon.ability.name, 86, 300, 2, base, shadow])
      else
        textstrings.push([_INTL("No ability"), 86, 300, 2, nonbase, nonshadow])
      end
      if pokemon.item
        textstrings.push([pokemon.item.name, 86, 336, 2, base, shadow])
      else
        textstrings.push([_INTL("No item"), 86, 336, 2, nonbase, nonshadow])
      end
      if pokemon.shiny? || pokemon.fakeshiny?
        addShinyStarsToGraphicsArray(imagepos,156,198,pokemon.bodyShiny?,pokemon.headShiny?,pokemon.debugShiny?,nil,nil,nil,nil,false,true,pokemon.fakeshiny?,[pokemon.shinyR?,pokemon.shinyG?,pokemon.shinyB?,pokemon.shinyKRS?])
      end
      if pokemon and pokemon.alpha?
        imagepos.push([sprintf("Mods/alpha_encounters/Graphics/alpha"), 160, 198])
      end
      typebitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/types"))
      type1_number = GameData::Type.get(pokemon.type1).id_number
      type2_number = GameData::Type.get(pokemon.type2).id_number
      type1rect = Rect.new(0, type1_number * 28, 64, 28)
      type2rect = Rect.new(0, type2_number * 28, 64, 28)
      if pokemon.type1 == pokemon.type2
        overlay.blt(52, 272, typebitmap.bitmap, type1rect)
      else
        overlay.blt(18, 272, typebitmap.bitmap, type1rect)
        overlay.blt(88, 272, typebitmap.bitmap, type2rect)
      end
      drawMarkings(overlay, 70, 240, 128, 20, pokemon.markings)
      pbDrawImagePositions(overlay, imagepos)
    end
    pbDrawTextPositions(overlay, textstrings)
    @sprites["pokemon"].setPokemonBitmap(pokemon)
    if pokemon.egg?
      @sprites["pokemon"].zoom_x = Settings::EGGSPRITE_SCALE
      @sprites["pokemon"].zoom_y = Settings::EGGSPRITE_SCALE
    else
      @sprites["pokemon"].zoom_x = Settings::FRONTSPRITE_SCALE
      @sprites["pokemon"].zoom_y = Settings::FRONTSPRITE_SCALE
    end
  end
end

# ---- Party panel -----------------------------------------------------------

class PokemonPartyPanel < SpriteWrapper
  def refresh
    return if disposed?
    return if @refreshing
    @refreshing = true
    if @panelbgsprite && !@panelbgsprite.disposed?
      if self.selected
        if self.preselected
          @panelbgsprite.changeBitmap("swapsel2")
        elsif @switching
          @panelbgsprite.changeBitmap("swapsel")
        elsif @pokemon.fainted?
          @panelbgsprite.changeBitmap("faintedsel")
        else
          @panelbgsprite.changeBitmap("ablesel")
        end
      else
        if self.preselected
          @panelbgsprite.changeBitmap("swap")
        elsif @pokemon.fainted?
          @panelbgsprite.changeBitmap("fainted")
        else
          @panelbgsprite.changeBitmap("able")
        end
      end
      @panelbgsprite.x = self.x
      @panelbgsprite.y = self.y
      @panelbgsprite.color = self.color
    end
    if @hpbgsprite && !@hpbgsprite.disposed?
      @hpbgsprite.visible = (!@pokemon.egg? && !(@text && @text.length > 0))
      if @hpbgsprite.visible
        if self.preselected || (self.selected && @switching)
          @hpbgsprite.changeBitmap("swap")
        elsif @pokemon.fainted?
          @hpbgsprite.changeBitmap("fainted")
        else
          @hpbgsprite.changeBitmap("able")
        end
        @hpbgsprite.x = self.x + 96
        @hpbgsprite.y = self.y + 50
        @hpbgsprite.color = self.color
      end
    end
    if @ballsprite && !@ballsprite.disposed?
      @ballsprite.changeBitmap((self.selected) ? "sel" : "desel")
      @ballsprite.x = self.x + 10
      @ballsprite.y = self.y
      @ballsprite.color = self.color
    end
    if @pkmnsprite && !@pkmnsprite.disposed?
      @pkmnsprite.x = self.x + 60
      @pkmnsprite.y = self.y + 40
      @pkmnsprite.color = self.color
      @pkmnsprite.selected = self.selected
    end
    if @helditemsprite && !@helditemsprite.disposed?
      if @helditemsprite.visible
        @helditemsprite.x = self.x + 62
        @helditemsprite.y = self.y + 48
        @helditemsprite.color = self.color
      end
    end
    if @overlaysprite && !@overlaysprite.disposed?
      @overlaysprite.x = self.x
      @overlaysprite.y = self.y
      @overlaysprite.color = self.color
    end
    if @refreshBitmap
      @refreshBitmap = false
      @overlaysprite.bitmap.clear if @overlaysprite.bitmap
      basecolor = Color.new(248, 248, 248)
      shadowcolor = Color.new(40, 40, 40)
      pbSetSystemFont(@overlaysprite.bitmap)
      textpos = []
      textpos.push([@pokemon.name, 96, 10, 0, basecolor, shadowcolor])
      if !@pokemon.egg?
        if !@text || @text.length == 0
          textpos.push([sprintf("% 3d /% 3d", @pokemon.hp, @pokemon.totalhp), 224, 54, 1, basecolor, shadowcolor])
          if @pokemon.hp > 0
            w = @pokemon.hp * 96 * 1.0 / @pokemon.totalhp
            w = 1 if w < 1
            w = ((w / 2).round) * 2
            hpzone = 0
            hpzone = 1 if @pokemon.hp <= (@pokemon.totalhp / 2).floor
            hpzone = 2 if @pokemon.hp <= (@pokemon.totalhp / 4).floor
            hprect = Rect.new(0, hpzone * 8, w, 8)
            @overlaysprite.bitmap.blt(128, 52, @hpbar.bitmap, hprect)
          end
          status = 0
          if @pokemon.fainted?
            status = GameData::Status::DATA.keys.length / 2
          elsif @pokemon.status != :NONE
            status = GameData::Status.get(@pokemon.status).id_number
          elsif @pokemon.pokerusStage == 1
            status = GameData::Status::DATA.keys.length / 2 + 1
          end
          status -= 1
          if status >= 0
            statusrect = Rect.new(0, 16 * status, 44, 16)
            @overlaysprite.bitmap.blt(78, 68, @statuses.bitmap, statusrect)
          end
        end
        imagePos = []
        kuraygender1t = "♂"
        kuraygender2t = "♀"
        kuraygender1r = [55, 148, 229]
        kuraygender1s = [68, 98, 125]
        kuraygender2r = [229, 55, 203]
        kuraygender2s = [137, 73, 127]
        if @pokemon.pizza?
          imagePos.push(["Graphics/Pictures/Storage/gender4", 206, 15])
        elsif @pokemon.male?
          textpos.push([_INTL(kuraygender1t), 224, 10, 0, Color.new(kuraygender1r[0], kuraygender1r[1], kuraygender1r[2]), Color.new(kuraygender1s[0], kuraygender1s[1], kuraygender1s[2])])
        elsif @pokemon.female?
          textpos.push([_INTL(kuraygender2t), 224, 10, 0, Color.new(kuraygender2r[0], kuraygender2r[1], kuraygender2r[2]), Color.new(kuraygender2s[0], kuraygender2s[1], kuraygender2s[2])])
        elsif @pokemon.genderless?
          imagePos.push(["Graphics/Pictures/Storage/gender3", 210, 24])
        end
        if @pokemon.shiny? || @pokemon.fakeshiny?
          addShinyStarsToGraphicsArray(imagePos,80,48,@pokemon.bodyShiny?,@pokemon.headShiny?,@pokemon.debugShiny?,0,0,16,16,false,false,@pokemon.fakeshiny?,[@pokemon.shinyR?,@pokemon.shinyG?,@pokemon.shinyB?,@pokemon.shinyKRS?])
        end
        if @pokemon and @pokemon.alpha?
          imagePos.push([sprintf("Mods/alpha_encounters/Graphics/alpha"), 195, 15])
        end
        if imagePos
          pbDrawImagePositions(@overlaysprite.bitmap, imagePos)
        end
      end
      pbDrawTextPositions(@overlaysprite.bitmap, textpos)
      if !@pokemon.egg?
        pbDrawImagePositions(@overlaysprite.bitmap, [[
          "Graphics/Pictures/Party/overlay_lv", 20, 70, 0, 0, 22, 14]])
        pbSetSmallFont(@overlaysprite.bitmap)
        pbDrawTextPositions(@overlaysprite.bitmap, [
          [@pokemon.level.to_s, 42, 57, 0, basecolor, shadowcolor]
        ])
      end
      if @text && @text.length > 0
        pbSetSystemFont(@overlaysprite.bitmap)
        pbDrawTextPositions(@overlaysprite.bitmap, [
          [@text, 96, 52, 0, basecolor, shadowcolor]
        ])
      end
    end
    @refreshing = false
  end
end

# ---- Summary screen --------------------------------------------------------

class PokemonSummary_Scene
  alias originaldrawpage drawPage
  def drawPage(page)
    if @pokemon.egg?
      drawPageOneEgg
      return
    end
    @sprites["itemicon"].item = @pokemon.item_id
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    base = Color.new(248, 248, 248)
    shadow = Color.new(104, 104, 104)
    @sprites["background"].setBitmap("Graphics/Pictures/Summary/bg_#{page}") if page < NB_PAGES
    imagepos = []
    ballimage = sprintf("Graphics/Pictures/Summary/icon_ball_%s", @pokemon.poke_ball)
    if !pbResolveBitmap(ballimage)
      ballimage = sprintf("Graphics/Pictures/Summary/icon_ball_%02d", pbGetBallType(@pokemon.poke_ball))
    end
    imagepos.push([ballimage, 14, 60])
    status = 0
    if @pokemon.fainted?
      status = GameData::Status::DATA.keys.length / 2
    elsif @pokemon.status != :NONE
      status = GameData::Status.get(@pokemon.status).id_number
    elsif @pokemon.pokerusStage == 1
      status = GameData::Status::DATA.keys.length / 2 + 1
    end
    status -= 1
    if status >= 0
      imagepos.push(["Graphics/Pictures/statuses", 124, 100, 0, 16 * status, 44, 16])
    end
    if @pokemon.pokerusStage == 2
      imagepos.push([sprintf("Graphics/Pictures/Summary/icon_pokerus"), 176, 100])
    end
    if @pokemon.shiny? || @pokemon.fakeshiny?
      addShinyStarsToGraphicsArray(imagepos,2,134,@pokemon.bodyShiny?,@pokemon.headShiny?,@pokemon.debugShiny?,nil,nil,nil,nil,true,false,@pokemon.fakeshiny?,[@pokemon.shinyR?,@pokemon.shinyG?,@pokemon.shinyB?,@pokemon.shinyKRS?])
    end
    if @pokemon and @pokemon.alpha?
      imagepos.push([sprintf("Mods/alpha_encounters/Graphics/alpha"), 2, 164])
    end
    pagename = [_INTL("INFO"),
                _INTL("TRAINER MEMO"),
                _INTL("SKILLS"),
                _INTL("MOVES"),
                _INTL("MOVES")][page - 1]
    textpos = [
      [pagename, 26, 10, 0, base, shadow],
      [@pokemon.name, 46, 56, 0, base, shadow],
      [@pokemon.level.to_s, 46, 86, 0, Color.new(64, 64, 64), Color.new(176, 176, 176)],
      [_INTL("Item"), 66, 312, 0, base, shadow]
    ]
    if @pokemon.hasItem?
      textpos.push([@pokemon.item.name, 16, 346, 0, Color.new(64, 64, 64), Color.new(176, 176, 176)])
    else
      textpos.push([_INTL("None"), 16, 346, 0, Color.new(192, 200, 208), Color.new(208, 216, 224)])
    end
    kuraygender1t = "♂"
    kuraygender2t = "♀"
    kuraygender1r = [55, 148, 229]
    kuraygender1s = [68, 98, 125]
    kuraygender2r = [229, 55, 203]
    kuraygender2s = [137, 73, 127]
    if @pokemon.pizza?
      imagepos.push(["Graphics/Pictures/Storage/gender4", 160, 61])
    elsif @pokemon.male?
      textpos.push([_INTL(kuraygender1t), 178, 56, 0, Color.new(kuraygender1r[0], kuraygender1r[1], kuraygender1r[2]), Color.new(kuraygender1s[0], kuraygender1s[1], kuraygender1s[2])])
    elsif @pokemon.female?
      textpos.push([_INTL(kuraygender2t), 178, 56, 0, Color.new(kuraygender2r[0], kuraygender2r[1], kuraygender2r[2]), Color.new(kuraygender2s[0], kuraygender2s[1], kuraygender2s[2])])
    elsif @pokemon.genderless?
      imagepos.push(["Graphics/Pictures/Storage/gender3", 164, 69])
    end
    pbDrawTextPositions(overlay, textpos)
    pbDrawImagePositions(overlay, imagepos)
    drawMarkings(overlay, 84, 292)
    case page
    when 1 then drawPageOne
    when 2 then drawPageTwo
    when 3 then drawPageThree
    when 4 then drawPageFour
    when 5 then drawPageFive
    end
  end
end

def pbPlayAlphaEvolveAnimation(battler, new_species)

  pkmnSprite = @scene.sprites["pokemon_#{battler.index}"]
  return if pkmnSprite.nil? || pkmnSprite.bitmap.nil?

  path = "Graphics/Animations/AlphaEvolve"
  return if !FileTest.exist?("#{path}.png") && !FileTest.exist?("#{path}.gif")

  sheet = Bitmap.new(path)
  return if sheet.nil?

  frame_size  = sheet.height
  frame_count = sheet.width / frame_size

  sprite_height = pkmnSprite.bitmap.height
  centre_x = pkmnSprite.x
  centre_y = pkmnSprite.y - sprite_height / 2

  overlay = Sprite.new(@scene.viewport)
  overlay.bitmap = sheet
  overlay.ox     = frame_size / 2
  overlay.oy     = frame_size / 2
  overlay.x      = centre_x
  overlay.y      = centre_y
  overlay.z      = 200

  frames_per_tick = 7
  transformed = false
  frame_count.times do |i|
    overlay.src_rect.set(i * frame_size, 0, frame_size, frame_size)
    if i >= frame_count - 2 and transformed == false
      transformed = true
      battler.changeSpecies(battler.pokemon, battler.pokemon.species, new_species)


    end
    frames_per_tick.times { Graphics.update


                            }

  end


  overlay.dispose
  sheet.dispose
end
