###################################################################################################
# Author: An Unsocial Pigeon                                                                      #
# Discord: @anunsocialpigeon                                                                      #
# For any issues or inquiries, feel free to reach out on Discord.                                 #
#                                                                                                 #
# You are allowed to use this file in your own mod,                                               # 
# on condition that you correctly credit me (An Unsocial Pigeon) <3                               #
###################################################################################################

###################################################################################################
# Catchable alphas by CharmingLoopy
# makes alphas catchable, makes them know a random move of their type. they have 2 perfect ivs

  module RelicRegistry

    if defined?(RELICS)
      RELICS << Relic.new(:ALPHA_RELIC, "Alpha Relic", "Wild Alphas are guaranteed to be shiny but are 50% rarer.")

      end
    end

if defined?(ModSettingsMenu)
  ModSettingsMenu.register(:alpha_encounterchance, {
    name: "Alpha Encounter Chance",
    type: :slider,
    min: 1,
    max: 100,
    interval: 1,
    default: 1,
    description: "Chance to encounter an alpha pokemon (%)",
    category: "Encounters"
 })
  ModSettingsMenu.register(:alpha_trainer, {
                                                  name: "Trainer Alphas",
                                                  type: :toggle,
                                                  default: 1,
                                                  description: "Trainers can have alpha pokemon",
                                                  category: "Difficulty"
                                                 })

  ModSettingsMenu.register(:alpha_trainerchance, {
                                                    name: "Trainer Alpha Pokemon Chance",
                                                    type: :slider,
                                                    min: 1,
                                                    max: 100,
                                                    interval: 1,
                                                    default: 1,
                                                    description: "Chance for a trainer's pokemon to become an alpha pokemon (%)",
                                                    category: "Difficulty"
                                                   })

  echoln "Loaded Alpha Pokemon Settings"
end
#===============================================================================
# Start a wild battle
#===============================================================================
def pbWildBattleCore(*args)

  if defined?($mod_manager_settings)
    alpha_chance = defined?(ModSettingsMenu) ? (ModSettingsMenu.get(:alpha_encounterchance) || $mod_manager_settings["alpha_encounters"]["alpha_encounterchance"]) : $mod_manager_settings["alpha_encounters"]["alpha_encounterchance"]
  else
     alpha_chance = defined?(ModSettingsMenu) ? (ModSettingsMenu.get(:alpha_encounterchance) || 1) : 1
  end
  outcomeVar = $PokemonTemp.battleRules["outcomeVar"] || 1
  canLose    = $PokemonTemp.battleRules["canLose"] || false
  # Skip battle if the player has no able Pokémon, or if holding Ctrl in Debug mode
  if $Trainer.able_pokemon_count == 0 || ($DEBUG && Input.press?(Input::CTRL))
    pbMessage(_INTL("SKIPPING BATTLE...")) if $Trainer.pokemon_count > 0
    pbSet(outcomeVar,1)   # Treat it as a win
    $PokemonTemp.clearBattleRules
    $PokemonGlobal.nextBattleBGM       = nil
    $PokemonGlobal.nextBattleME        = nil
    $PokemonGlobal.nextBattleCaptureME = nil
    $PokemonGlobal.nextBattleBack      = nil
    $PokemonTemp.forced_alt_sprites=nil
    pbMEStop
    return 1   # Treat it as a win
  end
  $PokemonSystem.is_in_battle = true
  # Record information about party Pokémon to be used at the end of battle (e.g.
  # comparing levels for an evolution check)
  Events.onStartBattle.trigger(nil)
  # Generate wild Pokémon based on the species and level
  foeParty = []
  sp = nil
  for arg in args
    if arg.is_a?(Pokemon)
      foeParty.push(arg)
    elsif arg.is_a?(Array)
      species = GameData::Species.get(arg[0]).id
      pkmn = pbGenerateWildPokemon(species,arg[1])
      foeParty.push(pkmn)
    elsif sp
      species = GameData::Species.get(sp).id
      pkmn = pbGenerateWildPokemon(species,arg)
      foeParty.push(pkmn)
      sp = nil
    else
      sp = arg
    end
  end
  alpha_count = 0

  $PokemonTemp.battleRewards ||= []
  for pokemon in foeParty
    alpha = false
    if defined?(RelicSystem) and RelicSystem.active?(:ALPHA_RELIC)
      if rand(150) < alpha_chance
        alpha= true
        alpha_count += 1
        alpha_chance  /= 2
      end

    else
      if rand(100) < alpha_chance
        alpha= true
        alpha_count += 1
        alpha_chance  /= 2
      end
    end
    if alpha == true
      if defined?(RelicSystem) and RelicSystem.active?(:ALPHA_RELIC)
        pokemon.shiny=(true)
      end
      make_alpha(pokemon)
      setBattleRule("backdrop", "lava")


      $PokemonTemp.encounterIsAlphaPokemon = true


      # Drops
      $PokemonTemp.battleRewards << ["item", :RARECANDY] if rand(5) < 1 && pokemon.level > 50
      $PokemonTemp.battleRewards << ["item", :POTION] if rand(3) < 1
      $PokemonTemp.battleRewards << ["item", :POTION] if rand(3) < 1
      $PokemonTemp.battleRewards << ["item", :POTION] if rand(3) < 1
      $PokemonTemp.battleRewards << ["item", :SUPERPOTION] if rand(7) < 1 && pokemon.level > 35
      $PokemonTemp.battleRewards << ["item", :SUPERPOTION] if rand(7) < 1 && pokemon.level > 35
      $PokemonTemp.battleRewards << ["item", :REPEL] if rand(5) < 1
      $PokemonTemp.battleRewards << ["item", :REPEL] if rand(5) < 1
      $PokemonTemp.battleRewards << ["item", :POKEBALL] if rand(5) < 1
      $PokemonTemp.battleRewards << ["item", :POKEBALL] if rand(5) < 1

      # Max 3 items



    end
  end
  echoln foeParty.inspect
  raise _INTL("Expected a level after being given {1}, but one wasn't found.",sp) if sp
  # Calculate who the trainers and their party are
  playerTrainers    = [$Trainer]
  playerParty       = $Trainer.party
  playerPartyStarts = [0]
  room_for_partner = (foeParty.length > 1)
  if !room_for_partner && $PokemonTemp.battleRules["size"] &&
     !["single", "1v1", "1v2", "1v3"].include?($PokemonTemp.battleRules["size"])
    room_for_partner = true
  end
  if $PokemonGlobal.partner && !$PokemonTemp.battleRules["noPartner"] && room_for_partner
    ally = NPCTrainer.new($PokemonGlobal.partner[1],$PokemonGlobal.partner[0])
    ally.id    = $PokemonGlobal.partner[2]
    ally.party = $PokemonGlobal.partner[3]
    playerTrainers.push(ally)
    playerParty = []
    $Trainer.party.each { |pkmn| playerParty.push(pkmn) }
    playerPartyStarts.push(playerParty.length)
    ally.party.each { |pkmn| playerParty.push(pkmn) }
    setBattleRule("double") if !$PokemonTemp.battleRules["size"]
  end
  # Create the battle scene (the visual side of it)
  scene = pbNewBattleScene
  # Create the battle class (the mechanics side of it)
  battle = PokeBattle_Battle.new(scene,playerParty,foeParty,playerTrainers,nil)
  battle.party1starts = playerPartyStarts
  # Set various other properties in the battle class
  pbPrepareBattle(battle)
  $PokemonTemp.clearBattleRules
  # Perform the battle itself
  decision = 0
  pbBattleAnimation(pbGetWildBattleBGM(foeParty),(foeParty.length==1) ? 0 : 2,foeParty) {
    pbSceneStandby {
                    decision = battle.pbStartBattle
                   }
  pbAfterBattle(decision,canLose)
  }
  Input.update
  # Save the result of the battle in a Game Variable (1 by default)
  #    0 - Undecided or aborted
  #    1 - Player won
  #    2 - Player lost
  #    3 - Player or wild Pokémon ran from battle, or player forfeited the match
  #    4 - Wild Pokémon was caught
  #    5 - Draw
  pbSet(outcomeVar,decision)
  rewards = $PokemonTemp&.battleRewards || []

  # No rewards for losing
  if rewards.is_a?(Array) && rewards.length > 0 && [1, 4].include?(decision)
    rewards.each do |key, value|
      case key
      when "money" then
        amount = value.to_i
        $Trainer.money += amount if amount.positive?
        if amount>0
          pbMessage(_INTL("You got ${1} for winning!", amount.to_s_formatted))
        end

      when "item" then
        pbReceiveItem(value)
      end
    end
  end

  $PokemonTemp.battleRewards = nil
  return decision
end
def pbTrainerBattleCore(*args)
  outcomeVar = $PokemonTemp.battleRules["outcomeVar"] || 1
  canLose    = $PokemonTemp.battleRules["canLose"] || false
  # Skip battle if the player has no able Pokémon, or if holding Ctrl in Debug mode
  if $Trainer.able_pokemon_count == 0 || ($DEBUG && Input.press?(Input::CTRL))
    pbMessage(_INTL("SKIPPING BATTLE...")) if $DEBUG
    pbMessage(_INTL("AFTER WINNING...")) if $DEBUG && $Trainer.able_pokemon_count > 0
    pbSet(outcomeVar,($Trainer.able_pokemon_count == 0) ? 0 : 1)   # Treat it as undecided/a win
    $PokemonTemp.clearBattleRules
    $PokemonGlobal.nextBattleBGM       = nil
    $PokemonGlobal.nextBattleME        = nil
    $PokemonGlobal.nextBattleCaptureME = nil
    $PokemonGlobal.nextBattleBack      = nil
    $PokemonTemp.forced_alt_sprites=nil
    pbMEStop
    return ($Trainer.able_pokemon_count == 0) ? 0 : 1   # Treat it as undecided/a win
  end
  $PokemonSystem.is_in_battle = true
  # Record information about party Pokémon to be used at the end of battle (e.g.
  # comparing levels for an evolution check)
  Events.onStartBattle.trigger(nil)
  # Generate trainers and their parties based on the arguments given
  foeTrainers    = []
  foeItems       = []
  foeEndSpeeches = []
  foeParty       = []
  foePartyStarts = []
  for arg in args
    if arg.is_a?(NPCTrainer)
      foeTrainers.push(arg)
      foePartyStarts.push(foeParty.length)
      arg.party.each { |pkmn| foeParty.push(pkmn) }
      foeEndSpeeches.push(arg.lose_text)
      foeItems.push(arg.items)
    elsif arg.is_a?(Array)   # [trainer type, trainer name, ID, speech (optional)]
      trainer = pbLoadTrainer(arg[0],arg[1],arg[2])
      if !trainer && $game_switches[SWITCH_MODERN_MODE] #retry without modern mode
        $game_switches[SWITCH_MODERN_MODE]=false
        trainer = pbLoadTrainer(arg[0],arg[1],arg[2])
        $game_switches[SWITCH_MODERN_MODE]=true
      end

      pbMissingTrainer(arg[0],arg[1],arg[2]) if !trainer
      return 0 if !trainer

      #infinite fusion edit
      name_override = arg[4]
      type_override = arg[5]
      if type_override != nil
        trainer.trainer_type = type_override
      end
      if name_override != nil
        trainer.name = name_override
      end
      #####
      Events.onTrainerPartyLoad.trigger(nil,trainer)
      foeTrainers.push(trainer)
      foePartyStarts.push(foeParty.length)
      trainer.party.each { |pkmn| foeParty.push(pkmn) }
      foeEndSpeeches.push(arg[3] || trainer.lose_text)
      foeItems.push(trainer.items)
    else
      raise _INTL("Expected NPCTrainer or array of trainer data, got {1}.", arg)
    end
  end
  alpha_count = 0
  if defined?($mod_manager_settings)

    alpha_enabled = defined?(ModSettingsMenu) ? (ModSettingsMenu.get(:alpha_trainer) || $mod_manager_settings["alpha_encounters"]["alpha_trainer"]) : $mod_manager_settings["alpha_encounters"]["alpha_trainer"]
    alpha_chance = defined?(ModSettingsMenu) ? (ModSettingsMenu.get(:alpha_trainerchance) || $mod_manager_settings["alpha_encounters"]["alpha_trainerchance"]) : $mod_manager_settings["alpha_encounters"]["alpha_trainerchance"]

  else
    alpha_enabled = defined?(ModSettingsMenu) ? (ModSettingsMenu.get(:alpha_trainer) || 0) : 0
    alpha_chance = defined?(ModSettingsMenu) ? (ModSettingsMenu.get(:alpha_trainerchance) || 1) : 1
  end


  for pokemon in foeParty
    alpha = false

    if rand(100) < alpha_chance and alpha_enabled == 1
      alpha= true
      alpha_count += 1
      alpha_chance  /= 2
    end
    if alpha == true
      make_alpha(pokemon,1.2)
    end
  end
  # Calculate who the player trainer(s) and their party are
  playerTrainers    = [$Trainer]
  playerParty       = $Trainer.party
  playerPartyStarts = [0]
  room_for_partner = (foeParty.length > 1)
  if !room_for_partner && $PokemonTemp.battleRules["size"] &&
     !["single", "1v1", "1v2", "1v3"].include?($PokemonTemp.battleRules["size"])
    room_for_partner = true
  end
  if $PokemonGlobal.partner && !$PokemonTemp.battleRules["noPartner"] && room_for_partner
    ally = NPCTrainer.new($PokemonGlobal.partner[1], $PokemonGlobal.partner[0])
    ally.id    = $PokemonGlobal.partner[2]
    ally.party = $PokemonGlobal.partner[3]
    playerTrainers.push(ally)
    playerParty = []
    $Trainer.party.each { |pkmn| playerParty.push(pkmn) }
    playerPartyStarts.push(playerParty.length)
    ally.party.each { |pkmn| playerParty.push(pkmn) }
    setBattleRule("double") if !$PokemonTemp.battleRules["size"]
  end
  # Create the battle scene (the visual side of it)
  scene = pbNewBattleScene
  # Create the battle class (the mechanics side of it)
  battle = PokeBattle_Battle.new(scene,playerParty,foeParty,playerTrainers,foeTrainers)
  battle.party1starts = playerPartyStarts
  battle.party2starts = foePartyStarts
  battle.items        = foeItems
  battle.endSpeeches  = foeEndSpeeches
  # Set various other properties in the battle class
  pbPrepareBattle(battle)
  $PokemonTemp.clearBattleRules
  # End the trainer intro music
  Audio.me_stop
  # Perform the battle itself
  decision = 0
  pbBattleAnimation(pbGetTrainerBattleBGM(foeTrainers),(battle.singleBattle?) ? 1 : 3,foeTrainers) {
    pbSceneStandby {
                    decision = battle.pbStartBattle
                   }
  pbAfterBattle(decision,canLose)
  }
  Input.update
  # Save the result of the battle in a Game Variable (1 by default)
  #    0 - Undecided or aborted
  #    1 - Player won
  #    2 - Player lost
  #    3 - Player or wild Pokémon ran from battle, or player forfeited the match
  #    5 - Draw
  pbSet(outcomeVar,decision)
  return decision
end

# ---

# alpha variable ---
class Pokemon
  attr_accessor :body_alpha

  attr_accessor :head_alpha

  attr_accessor :alpha
  attr_accessor :alpha_moves
  def getMoveList
    list =  species_data.moves
    if @alpha_moves
    @alpha_moves.each do | m|
      list << [0,m]
    end
    end
    return list
  end
  def alpha?

    if body_alpha == true or head_alpha == true or alpha == true

      return true
    end
    return false

  end
end

class PBFusion

  def pbFusionScreen(cancancel = false, superSplicer = false, firstOptionSelected = false)
    metaplayer1 = SpriteMetafilePlayer.new(@metafile1, @sprites["rsprite1"])
    metaplayer2 = SpriteMetafilePlayer.new(@metafile2, @sprites["rsprite2"])
    metaplayer3 = SpriteMetafilePlayer.new(@metafile3, @sprites["rsprite3"])
    metaplayer4 = SpriteMetafilePlayer.new(@metafile4, @sprites["dnasplicer"])

    metaplayer1.play
    metaplayer2.play
    metaplayer3.play
    metaplayer4.play

    pbBGMStop()
    pbPlayCry(@pokemon)
    Kernel.pbMessageDisplay(@sprites["msgwindow"],
                            _INTL("The Pokémon are being fused!", @pokemon1.name))

    Kernel.pbMessageWaitForInput(@sprites["msgwindow"], 100, true)
    pbPlayDecisionSE()
    oldstate = pbSaveSpriteState(@sprites["rsprite1"])
    oldstate2 = pbSaveSpriteState(@sprites["rsprite2"])
    oldstate3 = pbSaveSpriteState(@sprites["rsprite3"])

    pbBGMPlay("fusion")

    canceled = false
    noMoves = false
    begin
      metaplayer1.update
      metaplayer2.update
      metaplayer3.update
      metaplayer4.update

      Graphics.update
      Input.update
      if Input.trigger?(Input::B) && Input.trigger?(Input::C) # && Input.trigger?(Input::A)# && cancancel
        noMoves = true
        pbSEPlay("buzzer")
        Graphics.update
      end
    end while metaplayer1.playing? && metaplayer2.playing?
    if canceled
      pbBGMStop()
      pbPlayCancelSE()
      # Kernel.pbMessageDisplay(@sprites["msgwindow"],
      @pbEndScreen
      _INTL("Huh? The fusion was cancelled!")
    else
      frames = pbCryFrameLength(@newspecies)
      pbBGMStop()
      pbPlayCry(@newspecies)
      frames.times do
        Graphics.update
      end
      # pbMEPlay("Voltorb Flip Win")
      newSpecies = GameData::Species.get(@newspecies)
      newspeciesname = newSpecies.real_name
      oldspeciesname = GameData::Species.get(@pokemon1.species).real_name

      overlay = BitmapSprite.new(Graphics.width, Graphics.height, @viewport).bitmap

      sprite_bitmap = @sprites["rsprite2"].getBitmap
      # drawSpriteCredits(sprite_bitmap.filename, sprite_bitmap.path, @viewport)
      pbBGMPlay(pbGetWildVictoryME)
      Kernel.pbMessageDisplay(@sprites["msgwindow"],
                              _INTL("\\se[]Congratulations! Your Pokémon were fused into {2}!\\wt[80]", @pokemon1.name, newspeciesname))


      #exp
      @pokemon1.head_gender = @pokemon2.gender
      @pokemon1.head_nickname = @pokemon2.nicknamed?
      @pokemon1.exp_when_fused_head = @pokemon2.exp
      @pokemon1.exp_when_fused_body = @pokemon1.exp
      @pokemon1.exp_gained_since_fused = 0
      @pokemon1.kuray_no_evo = 0
      @pokemon1.kuraycustomfile = nil
      @pokemon2.kuraycustomfile = nil

      # 2 = head
      # 1 = body
      if @pokemon2.item != nil && $PokemonBag.pbCanStore?(@pokemon2.item, 1)
        $PokemonBag.pbStoreItem(@pokemon2.item, 1)
      end
      #KurayX - KURAYX_ABOUT_SHINIES
      if @pokemon2.alpha == true
        @pokemon1.head_alpha = true
        @pokemon1.alpha_moves = @pokemon2.alpha_moves
      end
      if @pokemon1.alpha == true
        @pokemon1.body_alpha = true

      end


      if @pokemon2.shiny?
        @pokemon1.head_shiny = true
        @pokemon1.head_shinyhue = @pokemon2.shinyValue?
        @pokemon1.head_shinyimprovpif = @pokemon2.shinyimprovpif?
        @pokemon1.head_shinyr = @pokemon2.shinyR?
        @pokemon1.head_shinyg = @pokemon2.shinyG?
        @pokemon1.head_shinyb = @pokemon2.shinyB?
        @pokemon1.head_shinykrs = @pokemon2.shinyKRS?.clone
        if $PokemonSystem.shinyfusedye == 1
          @pokemon1.shinyR = @pokemon2.shinyR?
          @pokemon1.shinyG = @pokemon2.shinyG?
          @pokemon1.shinyB = @pokemon2.shinyB?
          @pokemon1.shinyValue = @pokemon2.shinyValue?
          @pokemon1.shinyKRS = @pokemon2.shinyKRS?.clone
          @pokemon1.shinyimprovpif = @pokemon2.shinyimprovpif?
        end
        # if $PokemonSystem.shinyfusedye == 1 || !@pokemon1.shiny?
        #   @pokemon1.shinyR = @pokemon2.shinyR?
        #   @pokemon1.shinyG = @pokemon2.shinyG?
        #   @pokemon1.shinyB = @pokemon2.shinyB?
        #   @pokemon1.shinyValue = @pokemon2.shinyValue?
        #   @pokemon1.shinyKRS = @pokemon2.shinyKRS?.clone
        # end
      end
      if @pokemon1.shiny?
        @pokemon1.body_shiny = true
        @pokemon1.body_shinyhue = @pokemon1.shinyValue?
        @pokemon1.body_shinyimprovpif = @pokemon1.shinyimprovpif?
        @pokemon1.body_shinyr = @pokemon1.shinyR?
        @pokemon1.body_shinyg = @pokemon1.shinyG?
        @pokemon1.body_shinyb = @pokemon1.shinyB?
        @pokemon1.body_shinykrs = @pokemon1.shinyKRS?.clone
      end
      if @pokemon2.shiny? && @pokemon1.shiny? && $PokemonSystem.shinyfusedye == 0
        @pokemon1.shinyR = @pokemon2.shinyR?
        @pokemon1.shinyG = @pokemon2.shinyG?
        @pokemon1.shinyB = @pokemon2.shinyB?
        @pokemon1.shinyValue = @pokemon2.shinyValue?
        @pokemon1.shinyKRS = @pokemon2.shinyKRS?.clone
        @pokemon1.shinyimprovpif = @pokemon2.shinyimprovpif?
      end
      if $PokemonSystem.shinyfusedye == 2
        @pokemon1.shinyimprovpif = rollimproveshiny()
        @pokemon1.head_shinyimprovpif = rollimproveshiny()
        @pokemon1.body_shinyimprovpif = rollimproveshiny()
        @pokemon1.shinyValue = rand(0..360) - 180
        @pokemon1.shinyR = kurayRNGforChannels
        @pokemon1.shinyG = kurayRNGforChannels
        @pokemon1.shinyB = kurayRNGforChannels
        @pokemon1.shinyKRS = kurayKRSmake
        @pokemon1.body_shinyhue = rand(0..360) - 180
        @pokemon1.body_shinyr = kurayRNGforChannels
        @pokemon1.body_shinyg = kurayRNGforChannels
        @pokemon1.body_shinyb = kurayRNGforChannels
        @pokemon1.body_shinykrs = kurayKRSmake
        @pokemon1.head_shinyhue = rand(0..360) - 180
        @pokemon1.head_shinyr = kurayRNGforChannels
        @pokemon1.head_shinyg = kurayRNGforChannels
        @pokemon1.head_shinyb = kurayRNGforChannels
      end
    end

end
end
class PokemonTemp
  attr_accessor :encounterIsAlphaPokemon
end

class PokeBattle_Battler

  def alpha?
    if @pokemon
      return @pokemon.alpha?
    end
  return false
  end
end
module BallHandlers

  def self.onCatch(ball,battle,pkmn)
    pkmn.item=(nil)if pkmn.alpha? == true
    OnCatch.trigger(ball,battle,pkmn)
  end
end


module PokeBattle_BattleCommon
  alias originalCaptureCalc pbCaptureCalc

  def pbCaptureCalc(pkmn, battler, catch_rate, ball)
    if pkmn.alpha? and catch_rate != nil
      catch_rate *= 0.8
    end
    return originalCaptureCalc(pkmn, battler, catch_rate, ball) 
  end
end



ALL_MOVES =
 [[:BUG, :MEGAHORN], [:BUG, :ATTACKORDER], [:BUG, :BUGBUZZ], [:BUG, :FIRSTIMPRESSION], [:BUG, :POLLENPUFF], [:BUG, :LEECHLIFE], [:BUG, :LUNGE], [:BUG, :XSCISSOR], [:BUG, :SIGNALBEAM], [:BUG,   :UTURN], [:BUG, :STEAMROLLER], [:BUG, :BUGBITE], [:BUG, :SILVERWIND], [:BUG, :FELLSTINGER],

  [:BUG, :STRUGGLEBUG], [:BUG, :FURYCUTTER], [:BUG, :PINMISSILE], [:BUG, :TWINEEDLE], [:BUG, :INFESTATION], [:BUG, :DEFENDORDER], [:BUG, :HEALORDER], [:BUG, :POWDER], [:BUG, :QUIVERDANCE], [:BUG, :RAGEPOWDER],
  [:BUG, :SPIDERWEB], [:BUG, :STICKYWEB], [:BUG, :STRINGSHOT], [:BUG, :TAILGLOW], [:DARK, :HYPERSPACEFURY], [:DARK, :FOULPLAY], [:DARK,  :DARKESTLARIAT], [:DARK, :NIGHTDAZE], [:DARK, :CRUNCH], [:DARK, :DARKPULSE], [:DARK, :THROATCHOP], [:DARK, :NIGHTSLASH], [:DARK, :SUCKERPUNCH], [:DARK, :KNOCKOFF], [:DARK, :ASSURANCE], [:DARK, :BITE], [:DARK, :BRUTALSWING],
  [:DARK, :FEINTATTACK], [:DARK, :THIEF], [:DARK, :SNARL], [:DARK, :PAYBACK], [:DARK, :PURSUIT], [:DARK, :BEATUP],
  [:DARK, :FLING], [:DARK, :POWERTRIP], [:DARK, :PUNISHMENT], [:DARK, :DARKVOID], [:DARK, :EMBARGO], [:DARK, :FAKETEARS], [:DARK, :FLATTER], [:DARK, :HONECLAWS], [:DARK, :MEMENTO], [:DARK, :NASTYPLOT], [:DARK, :PARTINGSHOT], [:DARK, :QUASH], [:DARK, :SNATCH], [:DARK, :SWITCHEROO], [:DARK, :TAUNT], [:DARK, :TOPSYTURVY], [:DARK, :TORMENT], [:DRAGON, :ROAROFTIME], [:DRAGON, :DRACOMETEOR], [:DRAGON, :OUTRAGE], [:DRAGON, :CLANGINGSCALES], [:DRAGON, :COREENFORCER], [:DRAGON, :DRAGONRUSH], [:DRAGON, :SPACIALREND], [:DRAGON, :DRAGONHAMMER], [:DRAGON, :DRAGONPULSE], [:DRAGON, :DRAGONCLAW], [:DRAGON, :DRAGONBREATH],
  [:DRAGON, :DRAGONTAIL], [:DRAGON, :DUALCHOP], [:DRAGON, :TWISTER], [:DRAGON, :DRAGONRAGE], [:DRAGON, :DRAGONDANCE], [:ELECTRIC, :BOLTSTRIKE], [:ELECTRIC, :VOLTTACKLE], [:ELECTRIC, :ZAPCANNON], [:ELECTRIC, :THUNDER],
  [:ELECTRIC, :FUSIONBOLT], [:ELECTRIC, :PLASMAFISTS], [:ELECTRIC, :THUNDERBOLT], [:ELECTRIC, :WILDCHARGE], [:ELECTRIC, :DISCHARGE], [:ELECTRIC, :ZINGZAP], [:ELECTRIC, :THUNDERPUNCH], [:ELECTRIC, :VOLTSWITCH], [:ELECTRIC, :PARABOLICCHARGE], [:ELECTRIC, :SPARK],
  [:ELECTRIC, :THUNDERFANG], [:ELECTRIC, :SHOCKWAVE], [:ELECTRIC, :ELECTROWEB], [:ELECTRIC, :CHARGEBEAM], [:ELECTRIC, :THUNDERSHOCK], [:ELECTRIC, :NUZZLE], [:ELECTRIC, :ELECTROBALL], [:ELECTRIC, :CHARGE], [:ELECTRIC, :EERIEIMPULSE], [:ELECTRIC, :ELECTRICTERRAIN], [:ELECTRIC, :ELECTRIFY], [:ELECTRIC, :IONDELUGE], [:ELECTRIC, :MAGNETRISE], [:ELECTRIC, :MAGNETICFLUX], [:ELECTRIC, :THUNDERWAVE], [:FAIRY, :LIGHTOFRUIN], [:FAIRY, :FLEURCANNON], [:FAIRY, :MOONBLAST], [:FAIRY, :PLAYROUGH], [:FAIRY, :DAZZLINGGLEAM], [:FAIRY, :DRAININGKISS],
  [:FAIRY, :DISARMINGVOICE], [:FAIRY, :FAIRYWIND],
  [:FAIRY, :NATURESMADNESS], [:FAIRY, :AROMATICMIST], [:FAIRY, :BABYDOLLEYES], [:FAIRY, :CHARM], [:FAIRY, :CRAFTYSHIELD], [:FAIRY, :FAIRYLOCK], [:FAIRY, :FLORALHEALING], [:FAIRY, :FLOWERSHIELD], [:FAIRY, :GEOMANCY], [:FAIRY, :MISTYTERRAIN], [:FAIRY, :MOONLIGHT], [:FAIRY, :SWEETKISS], [:FIGHTING, :FOCUSPUNCH], [:FIGHTING, :HIJUMPKICK], [:FIGHTING, :CLOSECOMBAT], [:FIGHTING, :FOCUSBLAST], [:FIGHTING, :SUPERPOWER], [:FIGHTING, :CROSSCHOP], [:FIGHTING, :DYNAMICPUNCH], [:FIGHTING, :FLYINGPRESS], [:FIGHTING, :HAMMERARM], [:FIGHTING, :JUMPKICK], [:FIGHTING, :SACREDSWORD], [:FIGHTING, :SECRETSWORD], [:FIGHTING, :SKYUPPERCUT], [:FIGHTING, :AURASPHERE],
  [:FIGHTING, :SUBMISSION], [:FIGHTING, :BRICKBREAK], [:FIGHTING, :DRAINPUNCH], [:FIGHTING, :VITALTHROW], [:FIGHTING, :WAKEUPSLAP], [:FIGHTING, :LOWSWEEP], [:FIGHTING, :CIRCLETHROW], [:FIGHTING, :FORCEPALM],
  [:FIGHTING, :REVENGE], [:FIGHTING, :ROLLINGKICK], [:FIGHTING, :STORMTHROW], [:FIGHTING, :KARATECHOP], [:FIGHTING, :MACHPUNCH], [:FIGHTING, :POWERUPPUNCH], [:FIGHTING, :ROCKSMASH], [:FIGHTING, :VACUUMWAVE], [:FIGHTING, :DOUBLEKICK], [:FIGHTING, :ARMTHRUST], [:FIGHTING, :TRIPLEKICK], [:FIGHTING, :COUNTER], [:FIGHTING, :FINALGAMBIT], [:FIGHTING, :LOWKICK], [:FIGHTING, :REVERSAL], [:FIGHTING, :SEISMICTOSS], [:FIGHTING, :BULKUP], [:FIGHTING, :DETECT], [:FIGHTING, :MATBLOCK], [:FIGHTING, :QUICKGUARD], [:FIRE, :VCREATE], [:FIRE, :BLASTBURN], [:FIRE, :ERUPTION], [:FIRE, :MINDBLOWN], [:FIRE, :SHELLTRAP], [:FIRE, :BLUEFLARE], [:FIRE, :BURNUP], [:FIRE, :OVERHEAT], [:FIRE, :FLAREBLITZ], [:FIRE, :FIREBLAST], [:FIRE, :FUSIONFLARE], [:FIRE, :INFERNO], [:FIRE, :MAGMASTORM], [:FIRE, :SACREDFIRE], [:FIRE, :SEARINGSHOT], [:FIRE, :HEATWAVE], [:FIRE, :FLAMETHROWER], [:FIRE, :BLAZEKICK], [:FIRE, :FIERYDANCE], [:FIRE, :FIRELASH], [:FIRE, :FIREPLEDGE], [:FIRE, :LAVAPLUME], [:FIRE, :FIREPUNCH], [:FIRE, :MYSTICALFIRE], [:FIRE, :FLAMEBURST], [:FIRE, :FIREFANG], [:FIRE, :FLAMEWHEEL], [:FIRE, :INCINERATE], [:FIRE, :FLAMECHARGE], [:FIRE, :EMBER], [:FIRE, :FIRESPIN], [:FIRE, :HEATCRASH], [:FIRE, :SUNNYDAY], [:FIRE, :WILLOWISP], [:FLYING, :SKYATTACK], [:FLYING, :BRAVEBIRD], [:FLYING, :DRAGONASCENT], [:FLYING, :HURRICANE], [:FLYING, :AEROBLAST], [:FLYING, :BEAKBLAST], [:FLYING, :FLY], [:FLYING, :BOUNCE], [:FLYING, :DRILLPECK], [:FLYING, :OBLIVIONWING], [:FLYING, :AIRSLASH], [:FLYING, :CHATTER], [:FLYING, :AERIALACE], [:FLYING, :AIRCUTTER], [:FLYING, :PLUCK], [:FLYING, :SKYDROP], [:FLYING, :WINGATTACK], [:FLYING, :ACROBATICS], [:FLYING, :GUST], [:FLYING, :PECK], [:FLYING, :DEFOG], [:FLYING, :FEATHERDANCE], [:FLYING, :MIRRORMOVE], [:FLYING, :ROOST], [:FLYING, :TAILWIND], [:GHOST, :SHADOWFORCE], [:GHOST, :MOONGEISTBEAM], [:GHOST, :PHANTOMFORCE], [:GHOST, :SPECTRALTHIEF], [:GHOST, :SHADOWBONE], [:GHOST, :SHADOWBALL], [:GHOST, :SPIRITSHACKLE], [:GHOST, :SHADOWCLAW], [:GHOST, :HEX], [:GHOST, :OMINOUSWIND], [:GHOST, :SHADOWPUNCH], [:GHOST, :SHADOWSNEAK], [:GHOST, :ASTONISH], [:GHOST, :LICK], [:GHOST, :NIGHTSHADE], [:GHOST, :CONFUSERAY], [:GHOST, :CURSE], [:GHOST, :DESTINYBOND], [:GHOST, :GRUDGE], [:GHOST, :NIGHTMARE], [:GHOST, :SPITE], [:GHOST, :TRICKORTREAT], [:GRASS, :FRENZYPLANT], [:GRASS, :LEAFSTORM], [:GRASS, :SOLARBLADE], [:GRASS, :PETALDANCE], [:GRASS, :POWERWHIP], [:GRASS, :SEEDFLARE], [:GRASS, :SOLARBEAM], [:GRASS, :WOODHAMMER], [:GRASS, :ENERGYBALL], [:GRASS, :LEAFBLADE], [:GRASS, :PETALBLIZZARD], [:GRASS, :GRASSPLEDGE], [:GRASS, :SEEDBOMB], [:GRASS, :GIGADRAIN], [:GRASS, :HORNLEECH], [:GRASS, :TROPKICK], [:GRASS, :LEAFTORNADO], [:GRASS, :MAGICALLEAF], [:GRASS, :NEEDLEARM], [:GRASS, :RAZORLEAF], [:GRASS, :VINEWHIP], [:GRASS, :LEAFAGE], [:GRASS, :MEGADRAIN], [:GRASS, :BULLETSEED], [:GRASS, :ABSORB], [:GRASS, :GRASSKNOT], [:GRASS, :AROMATHERAPY], [:GRASS, :COTTONGUARD], [:GRASS, :COTTONSPORE], [:GRASS, :FORESTSCURSE], [:GRASS, :GRASSWHISTLE], [:GRASS, :GRASSYTERRAIN], [:GRASS, :INGRAIN], [:GRASS, :LEECHSEED], [:GRASS, :SLEEPPOWDER], [:GRASS, :SPIKYSHIELD], [:GRASS, :SPORE], [:GRASS, :STRENGTHSAP], [:GRASS, :STUNSPORE], [:GRASS, :SYNTHESIS], [:GRASS, :WORRYSEED], [:GROUND, :PRECIPICEBLADES], [:GROUND, :EARTHQUAKE], [:GROUND, :HIGHHORSEPOWER], [:GROUND, :EARTHPOWER], [:GROUND, :LANDSWRATH], [:GROUND, :THOUSANDARROWS], [:GROUND, :THOUSANDWAVES], [:GROUND, :DIG], [:GROUND, :DRILLRUN], [:GROUND, :STOMPINGTANTRUM], [:GROUND, :BONECLUB], [:GROUND, :MUDBOMB], [:GROUND, :BULLDOZE], [:GROUND, :MUDSHOT], [:GROUND, :BONEMERANG], [:GROUND, :SANDTOMB], [:GROUND, :BONERUSH], [:GROUND, :MUDSLAP], [:GROUND, :FISSURE], [:GROUND, :MAGNITUDE], [:GROUND, :MUDSPORT], [:GROUND, :ROTOTILLER], [:GROUND, :SANDATTACK], [:GROUND, :SHOREUP],
  [:GROUND, :SPIKES], [:ICE, :FREEZESHOCK], [:ICE, :ICEBURN], [:ICE, :BLIZZARD], [:ICE, :ICEHAMMER], [:ICE, :ICEBEAM], [:ICE, :ICICLECRASH], [:ICE, :ICEPUNCH], [:ICE, :FREEZEDRY], [:ICE, :AURORABEAM], [:ICE, :GLACIATE],
  [:ICE, :ICEFANG], [:ICE, :AVALANCHE], [:ICE, :FROSTBREATH], [:ICE, :ICYWIND], [:ICE, :ICESHARD], [:ICE, :POWDERSNOW], [:ICE, :ICEBALL], [:ICE, :ICICLESPEAR], [:ICE, :SHEERCOLD], [:ICE, :AURORAVEIL], [:ICE, :HAIL], [:ICE, :HAZE], [:ICE, :MIST], [:NORMAL, :EXPLOSION], [:NORMAL, :SELFDESTRUCT], [:NORMAL, :GIGAIMPACT], [:NORMAL, :HYPERBEAM], [:NORMAL, :BOOMBURST], [:NORMAL, :LASTRESORT], [:NORMAL, :SKULLBASH], [:NORMAL, :DOUBLEEDGE], [:NORMAL, :HEADCHARGE], [:NORMAL, :MEGAKICK], [:NORMAL, :TECHNOBLAST], [:NORMAL, :THRASH], [:NORMAL, :EGGBOMB], [:NORMAL, :JUDGMENT], [:NORMAL, :HYPERVOICE], [:NORMAL, :MULTIATTACK], [:NORMAL, :REVELATIONDANCE], [:NORMAL, :ROCKCLIMB], [:NORMAL, :TAKEDOWN], [:NORMAL, :UPROAR], [:NORMAL, :BODYSLAM], [:NORMAL, :EXTREMESPEED], [:NORMAL, :HYPERFANG], [:NORMAL, :MEGAPUNCH], [:NORMAL, :RAZORWIND], [:NORMAL, :SLAM], [:NORMAL, :STRENGTH], [:NORMAL, :TRIATTACK], [:NORMAL, :CRUSHCLAW], [:NORMAL, :RELICSONG], [:NORMAL, :CHIPAWAY], [:NORMAL, :DIZZYPUNCH], [:NORMAL, :FACADE], [:NORMAL, :HEADBUTT], [:NORMAL, :RETALIATE], [:NORMAL, :SECRETPOWER], [:NORMAL, :SLASH], [:NORMAL, :SMELLINGSALT], [:NORMAL, :HORNATTACK], [:NORMAL, :STOMP], [:NORMAL, :COVET], [:NORMAL, :HIDDENPOWER], [:NORMAL, :ROUND], [:NORMAL, :SWIFT], [:NORMAL, :VICEGRIP], [:NORMAL, :CUT], [:NORMAL, :SNORE], [:NORMAL, :STRUGGLE], [:NORMAL, :WEATHERBALL], [:NORMAL, :ECHOEDVOICE], [:NORMAL, :FAKEOUT], [:NORMAL, :FALSESWIPE], [:NORMAL, :HOLDBACK], [:NORMAL, :PAYDAY], [:NORMAL, :POUND], [:NORMAL, :QUICKATTACK], [:NORMAL, :SCRATCH], [:NORMAL, :TACKLE], [:NORMAL, :DOUBLEHIT], [:NORMAL, :FEINT], [:NORMAL, :TAILSLAP], [:NORMAL, :RAGE], [:NORMAL, :RAPIDSPIN], [:NORMAL, :SPIKECANNON], [:NORMAL, :COMETPUNCH], [:NORMAL, :FURYSWIPES], [:NORMAL, :BARRAGE], [:NORMAL, :BIND], [:NORMAL, :DOUBLESLAP], [:NORMAL, :FURYATTACK], [:NORMAL, :WRAP], [:NORMAL, :CONSTRICT], [:NORMAL, :BIDE], [:NORMAL, :CRUSHGRIP], [:NORMAL, :ENDEAVOR], [:NORMAL, :FLAIL], [:NORMAL, :FRUSTRATION], [:NORMAL, :GUILLOTINE], [:NORMAL, :HORNDRILL], [:NORMAL, :NATURALGIFT], [:NORMAL, :PRESENT], [:NORMAL, :RETURN], [:NORMAL, :SONICBOOM], [:NORMAL, :SPITUP], [:NORMAL, :SUPERFANG], [:NORMAL, :TRUMPCARD], [:NORMAL, :WRINGOUT], [:NORMAL, :ACUPRESSURE], [:NORMAL, :AFTERYOU], [:NORMAL, :ASSIST], [:NORMAL, :ATTRACT], [:NORMAL, :BATONPASS], [:NORMAL, :BELLYDRUM], [:NORMAL, :BESTOW], [:NORMAL, :BLOCK], [:NORMAL, :CAMOUFLAGE], [:NORMAL, :CAPTIVATE], [:NORMAL, :CELEBRATE], [:NORMAL, :CONFIDE], [:NORMAL, :CONVERSION], [:NORMAL, :CONVERSION2], [:NORMAL, :COPYCAT], [:NORMAL, :DEFENSECURL], [:NORMAL, :DISABLE], [:NORMAL, :DOUBLETEAM], [:NORMAL, :ENCORE], [:NORMAL, :ENDURE], [:NORMAL, :ENTRAINMENT], [:NORMAL, :FLASH], [:NORMAL, :FOCUSENERGY], [:NORMAL, :FOLLOWME], [:NORMAL, :FORESIGHT], [:NORMAL, :GLARE], [:NORMAL, :GROWL], [:NORMAL, :GROWTH], [:NORMAL, :HAPPYHOUR], [:NORMAL, :HARDEN], [:NORMAL, :HEALBELL], [:NORMAL, :HELPINGHAND], [:NORMAL, :HOLDHANDS], [:NORMAL, :HOWL], [:NORMAL, :LASERFOCUS], [:NORMAL, :LEER], [:NORMAL, :LOCKON], [:NORMAL, :LOVELYKISS], [:NORMAL, :LUCKYCHANT], [:NORMAL, :MEFIRST], [:NORMAL, :MEANLOOK], [:NORMAL, :METRONOME], [:NORMAL, :MILKDRINK], [:NORMAL, :MIMIC], [:NORMAL, :MINDREADER], [:NORMAL, :MINIMIZE], [:NORMAL, :MORNINGSUN], [:NORMAL, :NATUREPOWER], [:NORMAL, :NOBLEROAR], [:NORMAL, :ODORSLEUTH], [:NORMAL, :PAINSPLIT], [:NORMAL, :PERISHSONG], [:NORMAL, :PLAYNICE], [:NORMAL, :PROTECT], [:NORMAL, :PSYCHUP], [:NORMAL, :RECOVER], [:NORMAL, :RECYCLE], [:NORMAL, :REFLECTTYPE], [:NORMAL, :REFRESH], [:NORMAL, :ROAR], [:NORMAL, :SAFEGUARD], [:NORMAL, :SCARYFACE], [:NORMAL, :SCREECH], [:NORMAL, :SHARPEN], [:NORMAL, :SHELLSMASH], [:NORMAL, :SIMPLEBEAM], [:NORMAL, :SING], [:NORMAL, :SKETCH], [:NORMAL, :SLACKOFF], [:NORMAL, :SLEEPTALK],
  [:NORMAL, :SMOKESCREEN],
  [:NORMAL, :SOFTBOILED], [:NORMAL, :SPLASH], [:NORMAL, :SPOTLIGHT], [:NORMAL, :STOCKPILE], [:NORMAL, :SUBSTITUTE], [:NORMAL, :SUPERSONIC], [:NORMAL, :SWAGGER], [:NORMAL, :SWALLOW], [:NORMAL, :SWEETSCENT], [:NORMAL, :SWORDSDANCE], [:NORMAL, :TAILWHIP], [:NORMAL, :TEARFULLOOK], [:NORMAL, :TEETERDANCE], [:NORMAL, :TICKLE], [:NORMAL, :TRANSFORM], [:NORMAL, :WHIRLWIND], [:NORMAL, :WISH], [:NORMAL, :WORKUP], [:NORMAL, :YAWN], [:POISON, :BELCH], [:POISON, :GUNKSHOT], [:POISON, :SLUDGEWAVE], [:POISON, :SLUDGEBOMB], [:POISON, :POISONJAB], [:POISON, :CROSSPOISON], [:POISON, :SLUDGE], [:POISON, :VENOSHOCK], [:POISON, :CLEARSMOG], [:POISON, :POISONFANG], [:POISON, :POISONTAIL], [:POISON, :ACID], [:POISON, :ACIDSPRAY], [:POISON, :SMOG], [:POISON, :POISONSTING], [:POISON, :ACIDARMOR], [:POISON, :BANEFULBUNKER], [:POISON, :COIL], [:POISON, :GASTROACID], [:POISON, :POISONGAS], [:POISON, :POISONPOWDER], [:POISON, :PURIFY], [:POISON, :TOXIC], [:POISON, :TOXICSPIKES], [:POISON, :TOXICTHREAD], [:POISON, :VENOMDRENCH], [:PSYCHIC, :PRISMATICLASER], [:PSYCHIC, :PSYCHOBOOST], [:PSYCHIC, :FUTURESIGHT], [:PSYCHIC, :SYNCHRONOISE], [:PSYCHIC, :DREAMEATER], [:PSYCHIC, :PHOTONGEYSER], [:PSYCHIC, :PSYSTRIKE], [:PSYCHIC, :PSYCHIC], [:PSYCHIC, :PSYCHICFANGS], [:PSYCHIC, :EXTRASENSORY], [:PSYCHIC, :HYPERSPACEHOLE], [:PSYCHIC, :PSYSHOCK], [:PSYCHIC, :ZENHEADBUTT], [:PSYCHIC, :LUSTERPURGE], [:PSYCHIC, :MISTBALL], [:PSYCHIC, :PSYCHOCUT], [:PSYCHIC, :PSYBEAM], [:PSYCHIC, :HEARTSTAMP], [:PSYCHIC, :CONFUSION], [:PSYCHIC, :STOREDPOWER], [:PSYCHIC, :MIRRORCOAT], [:PSYCHIC, :PSYWAVE], [:PSYCHIC, :AGILITY], [:PSYCHIC, :ALLYSWITCH], [:PSYCHIC, :AMNESIA], [:PSYCHIC, :BARRIER], [:PSYCHIC, :CALMMIND], [:PSYCHIC, :COSMICPOWER], [:PSYCHIC, :GRAVITY], [:PSYCHIC, :GUARDSPLIT], [:PSYCHIC, :GUARDSWAP], [:PSYCHIC, :HEALBLOCK], [:PSYCHIC, :HEALPULSE], [:PSYCHIC, :HEALINGWISH], [:PSYCHIC, :HEARTSWAP], [:PSYCHIC, :HYPNOSIS], [:PSYCHIC, :IMPRISON], [:PSYCHIC, :INSTRUCT], [:PSYCHIC, :KINESIS], [:PSYCHIC, :LIGHTSCREEN], [:PSYCHIC, :LUNARDANCE], [:PSYCHIC, :MAGICCOAT], [:PSYCHIC, :MAGICROOM], [:PSYCHIC, :MEDITATE], [:PSYCHIC, :MIRACLEEYE], [:PSYCHIC, :POWERSPLIT], [:PSYCHIC, :POWERSWAP], [:PSYCHIC, :POWERTRICK], [:PSYCHIC, :PSYCHICTERRAIN], [:PSYCHIC, :PSYCHOSHIFT], [:PSYCHIC, :REFLECT], [:PSYCHIC, :REST], [:PSYCHIC, :ROLEPLAY], [:PSYCHIC, :SKILLSWAP], [:PSYCHIC, :SPEEDSWAP], [:PSYCHIC, :TELEKINESIS], [:PSYCHIC, :TELEPORT], [:PSYCHIC, :TRICK], [:PSYCHIC, :TRICKROOM], [:PSYCHIC, :WONDERROOM], [:ROCK, :HEADSMASH], [:ROCK, :ROCKWRECKER], [:ROCK, :DIAMONDSTORM], [:ROCK, :STONEEDGE], [:ROCK, :POWERGEM], [:ROCK, :ROCKSLIDE], [:ROCK, :ANCIENTPOWER], [:ROCK, :ROCKTOMB], [:ROCK, :ROCKTHROW], [:ROCK, :SMACKDOWN], [:ROCK, :ACCELEROCK], [:ROCK, :ROLLOUT], [:ROCK, :ROCKBLAST], [:ROCK, :ROCKPOLISH], [:ROCK, :SANDSTORM], [:ROCK, :STEALTHROCK], [:ROCK, :WIDEGUARD], [:STEEL, :DOOMDESIRE], [:STEEL, :IRONTAIL], [:STEEL, :SUNSTEELSTRIKE], [:STEEL, :METEORMASH], [:STEEL, :ANCHORSHOT], [:STEEL, :FLASHCANNON], [:STEEL, :IRONHEAD], [:STEEL, :SMARTSTRIKE], [:STEEL, :STEELWING], [:STEEL, :DOUBLEIRONBASH], [:STEEL, :MIRRORSHOT], [:STEEL, :MAGNETBOMB], [:STEEL, :GEARGRIND], [:STEEL, :METALCLAW], [:STEEL, :BULLETPUNCH], [:STEEL, :GYROBALL], [:STEEL, :HEAVYSLAM], [:STEEL, :METALBURST], [:STEEL, :AUTOTOMIZE], [:STEEL, :GEARUP], [:STEEL, :IRONDEFENSE], [:STEEL, :KINGSSHIELD], [:STEEL, :METALSOUND], [:STEEL, :SHIFTGEAR], [:WATER, :HYDROCANNON], [:WATER, :WATERSPOUT], [:WATER, :HYDROPUMP], [:WATER, :ORIGINPULSE], [:WATER, :STEAMERUPTION], [:WATER, :CRABHAMMER], [:WATER, :AQUATAIL], [:WATER, :MUDDYWATER], [:WATER, :SPARKLINGARIA], [:WATER, :SURF], [:WATER, :LIQUIDATION], [:WATER, :DIVE], [:WATER, :SCALD], [:WATER, :WATERPLEDGE], [:WATER, :WATERFALL], [:WATER, :RAZORSHELL], [:WATER, :BRINE], [:WATER, :BUBBLEBEAM], [:WATER, :OCTAZOOKA], [:WATER, :WATERPULSE], [:WATER, :AQUAJET], [:WATER, :BUBBLE], [:WATER, :WATERGUN], [:WATER, :CLAMP],
  [:WATER, :WHIRLPOOL], [:WATER, :WATERSHURIKEN], [:WATER, :AQUARING], [:WATER, :RAINDANCE], [:WATER, :SOAK], [:WATER, :WATERSPORT], [:WATER, :WITHDRAW], [:DARK, :FAINTATTACK], [:NORMAL, :HIDDENPOWER2], [:NORMAL, :TRIATTACK2], [:QMARKS, :FAKEMOVE]]


def make_alpha(pokemon,level_multi = 1.5,player = false)

  return if pokemon == nil


  return if pokemon.alpha? == true
  player_highest_level = 1
    $Trainer.party.each { |pkmn| player_highest_level = pkmn.level if pkmn.level > player_highest_level }

  pokemon.level = ((pokemon.level * level_multi) + (5)  ).clamp(1 + (player_highest_level * 0.8), 100).round
  # pokemon.name += " A"
  ivs = pokemon.iv
  firstiv = ivs.keys.sample
  secondiv = ivs.keys.sample
  while firstiv == secondiv
    secondiv = ivs.keys.sample
  end
  pokemon.iv[firstiv] = 31
  pokemon.iv[secondiv] = 31
  pokemon.alpha = true
  if player == false
    pbAlphaTryEvolveForm(pokemon)
  end
  items = [:LEFTOVERS,:ROCKYHELMET,:RAZORCLAW,:WIDELENS,:QUICKCLAW,:SITRUSBERRY,:ENIGMABERRY,:KINGSROCK,:WEAKNESSPOLICY,:FOCUSSASH,:ASSAULTVEST]
  customitems = [:ALPHABOND,:ALPHADEFENSE]
  items.shuffle!
  customitems.shuffle!
  pokemon.item = items[0]
  if rand(15) < 1
    pokemon.item = customitems[0]
  end
  learnable_moves = pokemon.getMoveList
  learnable_moves += pokemon.getMoveRelearnerList
  learnable_moves += pokemon.getEventMoveList
  species = pokemon.species_data

  if rand(100) < 1
    pokemon.shiny = true
  end
  if pokemon.shiny?
    if defined?(PokemonFamilyConfig::FAMILY_SYSTEM_ENABLED)
      if rand(50) < 1 and PokemonFamilyConfig::FAMILY_SYSTEM_ENABLED == true and pokemon.family == false
      # Deterministic weighted family selection using personalID
      pokemon.family = select_weighted_family(pkmn.personalID)
      # Deterministic weighted subfamily selection
      pokemon.subfamily = select_weighted_subfamily(pkmn.family, pkmn.personalID)
      pokemon.family_assigned_at = Time.now.to_i
    end
    end
  end
  species.get_evolutions(true).each do |evo|
    # [new_species, method, parameter, boolean]

    next if evo[3] # Prevolution
    poke = Pokemon.new(evo[0],100)
    learnable_moves += poke.getMoveList
    learnable_moves += poke.getMoveRelearnerList
    learnable_moves += poke.getEventMoveList
  end

# Dynamically build [type, move_id] entries from GameData::Move.
move_list = []

GameData::Move.each do |move_data|
  move_id   = move_data.id
  move_type = move_data.type

  move_list << [move_type, move_id]
end

move_list.uniq! { |entry| entry[1] }
move_list.shuffle!

  blacklisted_moves = [
    :GROWL, :TACKLE, :LEER, :STRINGSHOT, :SCRATCH, :HEALPULSE,
    :EERIEIMPULSE, :SPLASH, :SWALLOW, :TAILWHIP,
    :REFLECTTYPE, :RECYCLE, :REFRESH, :SAFEGUARD, :SLEEPTALK,
    :LUCKYCHANT, :MEFIRST, :EXPLOSION, :SELFDESTRUCT,
    :HELPINGHAND, :MIRRORMOVE, :COPYCAT, :TRANSFORM,
    :METRONOME, :HARDEN, :SPOTLIGHT, :LASTRESORT,
    :PERISHSONG, :AFTERYOU, :ASSIST, :DESTINYBOND,
    :SPITUP, :FLING, :ELECTRIFY, :TRICKORTREAT,
    :TRICK, :SOAK, :BURNUP, :FAINTATTACK,
    :HIDDENPOWER2, :TRIATTACK2, :FAKEMOVE,
    :EMBER, :ABSORB, :WATERGUN,
    :FORESIGHT, :ODORSLEUTH, :FOLLOWME,
    :ALLYSWITCH, :POWERTRICK, :ROLEPLAY,
    :INSTRUCT, :GUARDSPLIT, :POWERSPLIT,
    :GUARDSWAP, :MEDITATE, :POISONGAS,
    :STRUGGLE,:BESTOW
  ]

  pokemon.alpha_moves = []

  # Current moves as IDs
  known_moves = pokemon.moves.map(&:id)

  # Remove banned existing moves
  banned_moves = %i[
    SELFDESTRUCT EXPLOSION MISTYEXPLOSION
    MEMENTO FINALGAMBIT HEALINGWISH LUNARDANCE
]

pokemon.moves.delete_if { |m| banned_moves.include?(m.id) }
known_moves = pokemon.moves.map(&:id)

# Build candidate list
if pokemon.type1 == :NORMAL and pokemon.type2 != :NORMAL
	moves = move_list.select do |type, move|
	  (type == pokemon.type2) &&
		  !learnable_moves.include?(move) &&
		  !known_moves.include?(move) &&
		  !blacklisted_moves.include?(move)
	end
else
	moves = move_list.select do |type, move|
	  (type == pokemon.type1 || type == pokemon.type2) &&
		  !learnable_moves.include?(move) &&
		  !known_moves.include?(move) &&
		  !blacklisted_moves.include?(move)
	end
end
# Remove duplicate move IDs
moves.uniq! { |_, move| move }
moves.shuffle!

# First alpha move
if moves.any?
  move = moves.shift

  if pokemon.moves.size >= 4
    pokemon.moves[0] = Pokemon::Move.new(move[1])
  else
    pokemon.moves << Pokemon::Move.new(move[1])
  end

  pokemon.alpha_moves << move[1]
  known_moves << move[1]
end

# Chance for second alpha move
if rand(30) < 1
  moves.reject! { |_, move| known_moves.include?(move) }

  if moves.any?
    move = moves.shift

    if pokemon.moves.size >= 4
      pokemon.moves[rand(2) + 1] = Pokemon::Move.new(move[1])
    else
      pokemon.moves << Pokemon::Move.new(move[1])
    end

    pokemon.alpha_moves << move[1]
    known_moves << move[1]
  end
end
end
if defined?(MoveRelearnerScreen)
  class MoveRelearnerScreen
    alias pbGetRelearnableMoves_alpha pbGetRelearnableMoves
    def pbGetRelearnableMoves(pkmn)
      base = pbGetRelearnableMoves_alpha(pkmn)
      if defined?(pkmn.alpha_moves) and pkmn.alpha_moves != nil
        pkmn.alpha_moves.each do |m |
          next if base.include?(m)
          base << m
          end
      end
      return base
      end
    end
  end



ALPHA_EVOLVED_FORM_CHANCE = 5  # Percent chance an alpha spawns as an evolved form


 def pbAlphaTryEvolveForm(pokemon)
    return if rand(100) >= ALPHA_EVOLVED_FORM_CHANCE

    # Collect all level-based evolutions the pokemon could have at its current level
    valid_evos = []
    pokemon.species_data.get_evolutions(true).each do |evo|
      next if evo[3]          # skip prevolution entries
      method = evo[1]
      param  = evo[2]

      # Only allow level-based evolutions where the level requirement is already met
      next unless [:Level, :LevelMale, :LevelFemale, :LevelDay, :LevelNight,
                   :LevelRain, :AttackGreater, :AtkDefEqual, :DefenseGreater,
                   :Ninjask, :Shedinja].include?(method)
      next if param.is_a?(Integer) && pokemon.level < param

      valid_evos << evo[0]
    end

    return if valid_evos.empty?

    new_species = valid_evos.sample
    pokemon.species = new_species
    pokemon.reset_moves
    pokemon.calc_stats
  end
  class PokeBattle_FakeBattler
    def alpha?
      return false
    end
  end
