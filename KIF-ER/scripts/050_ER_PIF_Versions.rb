#===============================================================================
# KIF: Elite Redux – Elite Redux versions of abilities PIF already has
#   Setting: "Ability versions" (Elite Redux / PIF, under KIF: Elite Redux; 001_Core.rb).
#   While it is Elite Redux (and Innates is on), the abilities below work as in
#   Elite Redux 2.65, as main abilities and as innates (both use the same
#   BattleHandlers). On PIF, PIF's own handlers run untouched. The switch is
#   read every time an ability triggers, so changing it mid-game is fine.
#   The ability description shown in game follows the setting too.
#   Mechanics follow ER's C source first, then its in-game texts. PIF runs
#   generation 5 mechanics, so some PIF numbers below are generation 5 ones.
#
# Changed numbers (PIF -> Elite Redux)
#   Drizzle, Drought, Sand Stream, Snow Warning – weather lasts until replaced
#                      -> 8 turns (12 with the weather rock)
#   Psychic/Misty/Grassy Surge – terrain 5 turns (8 with Terrain Extender)
#                      -> 8 turns (12)
#   Swift Swim, Chlorophyll, Sand Rush, Slush Rush – Speed x2 -> x1.5 (Slush
#                      Rush also takes no hail damage, as Sand Rush in sand)
#   Rain Dish, Ice Body – heal 1/16 each turn -> 1/8 (not on the turn it came
#                      in, as ER)
#   Overgrow, Blaze, Torrent, Swarm – x1.5 at 1/3 HP or less -> x1.2 always,
#                      x1.5 at 1/3 HP or less
#   Hustle             – Atk x1.5 and 80% accuracy on physical moves -> power
#                      x1.4 and 90% accuracy on all damaging moves
#   Cute Charm         – 30% when hit by contact -> 50%, also when it attacks
#                      with contact, and with no gender rule
#   Plus, Minus        – Sp. Atk x1.5 for special moves with a Plus/Minus ally
#                      -> x2 for all attacks
#   Iron Fist 1.2 -> 1.3, Strong Jaw 1.5 -> 1.3, Mega Launcher 1.5 -> 1.3
#                      (PIF's pulse moves), Tough Claws 1.33 -> 1.3,
#                      Neuroforce 1.25 -> 1.35
#   Filter, Solid Rock, Prism Armor – super effective hits x0.75 -> x0.65
#   Friend Guard       – ally takes x0.75 in both (ER 2.65.4.1b's text; it
#                      was x0.5 before)
#   Victory Star       – accuracy x1.1 -> x1.2 (itself and its ally)
#   Defeatist          – halves Atk/Sp. Atk at 1/2 HP or less -> 1/3 or less
#   Bad Dreams         – sleeping foes lose 1/8 -> 1/4 of their max HP
#   Cursed Body        – disables for 2 more turns -> 4 more turns
#   Weak Armor         – -1 Def, +1 Speed (PIF is generation 5) -> +2 Speed
#   Lightning Rod, Storm Drain, Sap Sipper – absorb raises Sp. Atk / Atk ->
#                      raises its higher attacking stat
#   Berserk            – +1 Sp. Atk -> +1 to its higher attacking stat, once
#                      per battle
#   Moody              – any stat incl. accuracy/evasion -> Atk, Def, Sp. Atk,
#                      Sp. Def, Speed only; not on the turn it came in
#   Download           – sum of all foes' Def vs Sp. Def, a tie raises Sp. Atk
#                      -> the foe opposite (stat stages count), a tie raises Atk
#
# Added effects (PIF's effect stays, Elite Redux adds)
#   Battle Armor, Shell Armor – also takes x0.8 damage from attacks
#   Damp               – also: contact either way makes the other Pokemon pure
#                      Water type
#   Limber             – also: half recoil and crash damage; its own moves
#                      can't lower its stats
#   Clear Body, Full Metal Body – also block drops from its own moves
#   Static             – also when it attacks; 10% chance without contact
#   Flame Body         – also when it attacks; 20% chance without contact
#   Poison Point       – also when it attacks with contact
#   Poison Touch       – also when it is hit by contact
#   Immunity           – also takes x0.5 damage from Poison moves
#   Magma Armor        – also takes x0.7 damage from Water and Ice moves
#   Levitate           – also Flying moves x1.25
#   Illuminate         – accuracy x1.2, and its hits remove the target's Ghost
#                      type (PIF's Illuminate does nothing in battle)
#   Inner Focus        – also Focus Blast never misses
#   Oblivious, Own Tempo, Inner Focus, Scrappy – also immune to Intimidate and
#                      Scare; with Vital Spirit also immune to Taunt
#   Oblivious          – also immune to Disable, Encore and Torment; gaining
#                      it cures them and Taunt (PIF, generation 5: only
#                      infatuation)
#   Triage             – also drain moves (PIF counts them from generation 6);
#                      still only moves that restore HP
#   Keen Eye           – also accuracy x1.2
#   Hyper Cutter       – also blocks Sp. Atk drops; contact moves +1 crit stage
#   Shield Dust        – also immune to entry hazards and powder moves
#   Water Veil         – also Aqua Ring on entry
#   Pressure           – also on entry: foes lose their stat raises, it loses
#                      its own stat drops
#   Cloud Nine         – also clears the weather on entry (not primal weather)
#   Air Lock           – also clears the weather and sets a 3-turn Tailwind
#                      on entry
#   Run Away           – also +2 Speed when a foe lowers its stats
#   Anger Point        – also +1 Atk on any hit (max on a critical hit)
#   Stamina            – a critical hit maximizes Defense
#   Rattled            – also +1 Speed when it flinches
#   Vital Spirit       – also: its Fighting moves cure its status
#   Heatproof          – no burn damage (was half) and no burn Attack drop
#   Flare Boost        – no burn damage, no burn Attack drop, burns itself
#                      when fog starts or it enters fog
#   Toxic Boost        – no poison damage
#   Gluttony           – also heals 1/3 of its max HP after eating its berry
#   Light Metal        – also Speed x1.3
#   Illusion           – also x1.3 damage while the illusion holds
#   Water Compaction   – also takes x0.5 damage from Water moves
#   Long Reach         – also physical moves x1.2
#   Overcoat           – also takes x0.8 damage from special moves
#   Merciless          – also crits paralyzed, bleeding or Speed-lowered
#                      targets, or ones holding an Iron Ball
#   Frisk              – also for the foe; the foes' items stop working for 2
#                      turns (Embargo)
#   Turboblaze, Teravolt – also add the Fire / Electric type on entry
#   Corrosion          – also Poison moves are super effective on Steel
#   Normalize          – also x1.1 power; Normal moves ignore resistances (not
#                      immunities). PIF is generation 5, so it had no boost.
#   Healer             – also cures itself when no ally needs it
#   Prankster          – its boosted status moves fail on Dark-type foes (PIF
#                      only does this from generation 7)
#   Anticipation       – also dodges the first super effective hit it gets in
#                      a battle
#
# Completely different (PIF -> Elite Redux)
#   Color Change       – becomes the move's type after a hit -> before a hit,
#                      becomes the type that resists it best (immunity
#                      first); once per turn
#   White Smoke        – no stat drops -> on entry: smoke on its side for 3
#                      turns (5 with Light Clay), its team's evasion x1.25
#   Big Pecks          – no Defense drops -> contact moves x1.3
#   Pickup             – picks up used items -> clears hazards on its side on
#                      entry
#   Truant             – loafs every other turn -> loafs only after a turn it
#                      chose an attacking move
#   Rivalry            – x1.25 same gender, x0.75 opposite gender -> x1.25 vs
#                      same gender, takes x0.75 from the opposite gender
#   Stall              – moves last -> takes x0.7 damage before it moves
#   Leaf Guard         – no status in sun -> cures its status at the end of
#                      the turn in sun
#   Solar Power        – Sp. Atk x1.5 in sun, loses 1/8 HP -> higher attacking
#                      stat x1.5 in sun, no HP loss
#   Sand Force         – Rock/Ground/Steel moves x1.3 in sand -> higher
#                      attacking stat x1.5 in sand
#   Justified          – +1 Atk when hit by Dark -> immune to Dark moves, +1 to
#                      its higher attacking stat
#   Stakeout           – x2 on a foe switching out -> x2 on a foe that came in
#                      this turn
#   Liquid Voice       – sound moves become Water -> Normal sound moves become
#                      Water; sound moves x1.2
#   Steelworker        – Steel moves x1.5 -> Normal moves become Steel; not
#                      Steel type: Steel STAB; Steel type: Ghost and Dark hits
#                      on it x0.5
#   Aerilate, Pixilate, Refrigerate, Galvanize – Normal moves change type and
#                      get x1.2 -> they change type with no boost; not that
#                      type: STAB for it; that type: 10% to infatuate
#                      (Pixilate), paralyze (Galvanize), frostbite (Refrigerate,
#                      only with "New battle effects" On) with those moves; Aerilate:
#                      Speed x1.1 when using a Flying move
#   Forewarn           – names a foe's strongest move -> on entry: an 80 power
#                      Future Sight that can't miss on the foe opposite
#   Aftermath          – KO'd by contact: attacker loses 1/4 HP -> KO'd by an
#                      attack: uses a 100 power Explosion (Attack higher) or
#                      Outburst (Sp. Atk higher, see 035) once the attack is
#                      over; it doesn't faint again. Its explosion moves
#                      (Explosion, Self-Destruct, Misty Explosion, Outburst)
#                      always flinch.
#   Wonder Skin        – status moves aimed at it 50% accurate -> foes'
#                      abilities can't boost their damage against it (Fort
#                      Knox's code, 027/035; Parental Bond and Multi-Headed
#                      still work)
#
# Same in both games (no change): Stench (its Toxic Terrain part is in 033),
#   Speed Boost, Sturdy, Volt Absorb, Water Absorb, Compound Eyes, Insomnia,
#   Flash Fire, Suction Cups, Intimidate, Shadow Tag, Rough Skin, Wonder Guard,
#   Effect Spore, Natural Cure, Serene Grace, Trace, Huge Power, Magnet Pull,
#   Soundproof, Sand Veil, Thick Fat, Early Bird, Arena Trap, Motor Drive,
#   Steadfast, Snow Cloak, Unburden, Simple, Dry Skin, Poison Heal,
#   Adaptability, Skill Link, Hydration, Quick Feet, Sniper, Magic Guard, No
#   Guard, Technician, Klutz, Mold Breaker, Super Luck, Unaware, Tinted Lens,
#   Sticky Hold, Shed Skin, Guts, Marvel Scale, Liquid Ooze, Rock Head,
#   Reckless (its enrage part is in 033), Multitype, Pickpocket, Sheer Force,
#   Contrary, Unnerve, Defiant, Competitive, Multiscale, Harvest, Telepathy,
#   Regenerator, Analytic, Imposter, Infiltrator, Mummy, Moxie, Magic Bounce,
#   Iron Barbs, Aroma Veil, Flower Veil, Sweet Veil, Protean (ER: once per turn;
#   a Pokemon moves once a turn anyway), Fur Coat, Magician, Bulletproof, Gale
#   Wings, Grass Pelt, Symbiosis, Gooey, Tangling Hair, Parental Bond, Dark
#   Aura, Fairy Aura, Wimp Out, Emergency Exit, Water Bubble, Comatose,
#   Queenly Majesty, Dazzling, Innards Out, Dancer, Fluffy, Soul-Heart,
#   Receiver, Beast Boost, Shadow Shield, Stance Change.
#
# Not changed yet:
#   Forecast      – ER's Weather Ball follow-up after weather moves needs an
#                   extra move use inside a move
#   Disguise      – ER restores it in fog; needs Mimikyu's form change back
#   Shields Down  – ER's Shell Smash form change; a form change PIF can't do
#                   for fusions
#   Immunity      – the newer ER source also blocks burn, paralysis,
#                   frostbite and bleeding; 2.65's text says poison only, so
#                   only poison is blocked (and Poison damage halved, above)
#===============================================================================
module KIFER
  module ERVersions
    # Abilities whose ER version is coded here (their description follows the
    # setting)
    CHANGED = [
      :DRIZZLE, :DROUGHT, :SANDSTREAM, :SNOWWARNING, :PSYCHICSURGE, :MISTYSURGE,
      :GRASSYSURGE, :SWIFTSWIM, :CHLOROPHYLL, :SANDRUSH, :SLUSHRUSH, :RAINDISH,
      :ICEBODY, :OVERGROW, :BLAZE, :TORRENT, :SWARM, :HUSTLE, :CUTECHARM, :PLUS,
      :MINUS, :IRONFIST, :STRONGJAW, :MEGALAUNCHER, :TOUGHCLAWS, :NEUROFORCE,
      :FILTER, :SOLIDROCK, :PRISMARMOR, :FRIENDGUARD, :VICTORYSTAR, :DEFEATIST,
      :BADDREAMS, :CURSEDBODY, :WEAKARMOR, :LIGHTNINGROD, :STORMDRAIN, :SAPSIPPER,
      :BERSERK, :MOODY, :DOWNLOAD,
      :BATTLEARMOR, :SHELLARMOR, :DAMP, :LIMBER, :CLEARBODY, :FULLMETALBODY,
      :STATIC, :FLAMEBODY, :POISONPOINT, :POISONTOUCH, :IMMUNITY, :MAGMAARMOR,
      :LEVITATE, :ILLUMINATE, :INNERFOCUS, :OBLIVIOUS, :OWNTEMPO, :SCRAPPY,
      :VITALSPIRIT, :KEENEYE, :HYPERCUTTER, :SHIELDDUST, :WATERVEIL, :PRESSURE,
      :CLOUDNINE, :AIRLOCK, :RUNAWAY, :ANGERPOINT, :STAMINA, :RATTLED, :HEATPROOF,
      :FLAREBOOST, :TOXICBOOST, :GLUTTONY, :LIGHTMETAL, :ILLUSION,
      :WATERCOMPACTION, :LONGREACH, :OVERCOAT, :MERCILESS, :FRISK, :TURBOBLAZE,
      :TERAVOLT, :CORROSION, :NORMALIZE, :HEALER, :PRANKSTER, :ANTICIPATION,
      :COLORCHANGE, :WHITESMOKE, :BIGPECKS, :PICKUP, :TRUANT, :RIVALRY, :STALL,
      :LEAFGUARD, :SOLARPOWER, :SANDFORCE, :JUSTIFIED, :STAKEOUT, :LIQUIDVOICE,
      :STEELWORKER, :AERILATE, :PIXILATE, :REFRIGERATE, :GALVANIZE, :FOREWARN,
      :TRIAGE, :AFTERMATH, :WONDERSKIN
    ].freeze

    PRIMAL      = [:HarshSun, :HeavyRain, :StrongWinds]
    ATE_TYPES   = { :AERILATE => :FLYING, :PIXILATE => :FAIRY, :REFRIGERATE => :ICE,
                    :GALVANIZE => :ELECTRIC, :STEELWORKER => :STEEL }
    SELF_DROP_BLOCK = [:LIMBER, :CLEARBODY, :FULLMETALBODY]
    INTIMIDATE_IMMUNE = [:OBLIVIOUS, :OWNTEMPO, :INNERFOCUS, :SCRAPPY]
    TAUNT_IMMUNE      = [:OBLIVIOUS, :OWNTEMPO, :INNERFOCUS, :SCRAPPY, :VITALSPIRIT]
    MAIN_STATS  = [:ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]

    # Elite Redux versions are on: Innates on and "Ability versions" = Elite Redux
    def self.on?
      return KIFER.er_versions?
    rescue StandardError
      return false
    end

    # Replaces the handlers of ids in hash: while on, the ER block runs (no
    # block = nothing happens); while off, PIF's handler (if it had one).
    def self.wrap(hash, *ids, &er)
      ids.flatten.each do |id|
        orig = hash[id]
        hash.add(id, proc { |*args|
          if KIFER::ERVersions.on?
            er ? er.call(*args) : nil
          else
            orig ? orig.call(*args) : nil
          end
        })
      end
    end

    def self.splash(battler, ability)
      battler.battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    end

    def self.hide(battler)
      battler.battle.pbHideAbilitySplash(battler)
    end

    def self.staged(battler, stat)
      value = case stat
              when :ATTACK          then battler.attack
              when :DEFENSE         then battler.defense
              when :SPECIAL_ATTACK  then battler.spatk
              when :SPECIAL_DEFENSE then battler.spdef
              else battler.speed
              end
      st = (battler.stages[stat] || 0) + 6
      return value * STAGE_MUL[st] / STAGE_DIV[st]
    end

    # ER's GetHighestAttackingStatId(battler, TRUE): stat stages count, a tie
    # is Attack
    def self.highest_attack(battler)
      return staged(battler, :SPECIAL_ATTACK) > staged(battler, :ATTACK) ? :SPECIAL_ATTACK : :ATTACK
    end

    # The move uses the user's higher attacking stat (for "x1.5 to its
    # higher attacking stat" abilities)
    def self.uses_highest?(user, move)
      hi = highest_attack(user)
      return move.physicalMove? if hi == :ATTACK
      return move.specialMove?
    end

    def self.genders_opposite?(a, b)
      return false if a.gender == 2 || b.gender == 2
      return a.gender != b.gender
    end

    # Battle-long notes (Anticipation, Berserk): kept on the battle, by side
    # and party slot, so nothing is saved on the Pokemon
    def self.note(battle, key, battler)
      h = battle.instance_variable_get(:@kifer_v_notes)
      h = battle.instance_variable_set(:@kifer_v_notes, {}) if !h
      return h[[key, battler.idxOwnSide, battler.pokemonIndex]]
    end

    def self.set_note(battle, key, battler)
      h = battle.instance_variable_get(:@kifer_v_notes)
      h = battle.instance_variable_set(:@kifer_v_notes, {}) if !h
      h[[key, battler.idxOwnSide, battler.pokemonIndex]] = true
    end

    # Weather from an entry ability: 8 turns, 12 with the weather rock
    def self.weather_ability(weather, battler, battle, ability)
      return if PRIMAL.include?(battle.field.weather)
      return if battle.field.weather == weather
      splash(battler, ability)
      battle.pbStartWeather(battler, weather, true)   # hides the splash
      d = battle.field.weatherDuration
      battle.field.weatherDuration = (d > 5) ? 12 : 8 if d > 0 && battle.field.weather == weather
    end

    # Terrain from an entry ability: 8 turns, 12 with Terrain Extender
    def self.terrain_ability(terrain, battler, battle, ability)
      return if battle.field.terrain == terrain
      splash(battler, ability)
      battle.pbStartTerrain(battler, terrain)   # hides the splash
      d = battle.field.terrainDuration
      battle.field.terrainDuration = (d > 5) ? 12 : 8 if d > 0 && battle.field.terrain == terrain
    end

    # Clears the weather (not primal weather): Cloud Nine, Air Lock
    def self.clear_weather(battle)
      w = battle.field.weather
      return false if w.nil? || w == :None || PRIMAL.include?(w)
      battle.field.weather = :None
      battle.field.weatherDuration = 0
      battle.eachBattler { |b| b.pbCheckFormOnWeatherChange rescue nil }
      return true
    end

    # Defender side of a two-way contact ability (PIF's contact checks kept)
    def self.on_hit_target(ability, user, target, move, status, c_chance, o_chance)
      return if user.fainted?
      contact = move.pbContactMove?(user)
      return if contact && !user.affectedByContactEffect?
      return if !contact && o_chance <= 0
      chance = contact ? c_chance : o_chance
      return if target.battle.pbRandom(100) >= chance
      apply_status(target, user, status, ability)
    end

    # Attacker side
    def self.on_hit_user(ability, user, target, move, status, c_chance, o_chance)
      return if target.fainted? || user.index == target.index
      battle = user.battle
      contact = move.pbContactMove?(user)
      return if !contact && o_chance <= 0
      return if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      chance = contact ? c_chance : o_chance
      return if battle.pbRandom(100) >= chance
      apply_status(user, target, status, ability)
    end

    def self.apply_status(bearer, other, status, ability)
      case status
      when :PARALYSIS then return if !other.pbCanParalyze?(bearer, false)
      when :BURN      then return if !other.pbCanBurn?(bearer, false)
      when :POISON    then return if !other.pbCanPoison?(bearer, false)
      when :ATTRACT
        if KIFER.ability_id(ability) == :CUTECHARM
          return if !attract_any_gender?(other, bearer)   # no gender rule
        else
          return if !other.pbCanAttract?(bearer, false)
        end
      when :FROSTBITE
        return if !KIFER.feature_on?(:frostbite)
        return if !other.respond_to?(:pbCanFrostbite?) || !other.pbCanFrostbite?(bearer, false)
      end
      splash(bearer, ability)
      case status
      when :PARALYSIS then other.pbParalyze(bearer)
      when :BURN      then other.pbBurn(bearer)
      when :POISON    then other.pbPoison(bearer)
      when :ATTRACT   then other.pbAttract(bearer)
      when :FROSTBITE then other.pbFrostbite(bearer)
      end
      hide(bearer)
    end

    # Cute Charm: PIF's pbCanAttract? without its gender rule
    def self.attract_any_gender?(other, bearer)
      return false if other.fainted? || bearer.fainted? || other.equal?(bearer)
      return false if other.effects[PBEffects::Attract] >= 0
      if !other.battle.moldBreaker
        return false if other.hasActiveAbility?([:AROMAVEIL, :OBLIVIOUS])
        other.eachAlly { |a| return false if a.hasActiveAbility?(:AROMAVEIL) }
      end
      return true
    end

    # Triage: drain moves (Absorb and co., Dream Eater, Draining Kiss)
    DRAIN_FUNCTIONS = ["0DD", "0DE", "14F"]

    # Aftermath: explosion moves (they always flinch)
    EXPLOSION_MOVES = [:EXPLOSION, :SELFDESTRUCT, :MISTYEXPLOSION, :OUTBURST]

    def self.explosion_move?(move)
      return true if move.instance_variable_get(:@kifer_sp2_outburst)
      return EXPLOSION_MOVES.include?(move.id)
    end

    # Aftermath: the Pokemon KO'd by an attack this turn, used once the attack is over
    def self.aftermath_list(battle)
      l = battle.instance_variable_get(:@kifer_v_aftermath)
      l = battle.instance_variable_set(:@kifer_v_aftermath, []) if !l
      return l
    end

    def self.aftermath_queue(battle, battler, ability)
      return if !defined?(KIFER::Specials2) || !defined?(KIFER::BatchF)
      list = aftermath_list(battle)
      return if list.any? { |e| e[0].equal?(battler) }
      kind = (highest_attack(battler) == :SPECIAL_ATTACK) ? :outburst : :explosion
      list << [battler, battler.pokemon, kind, ability, battle.turnCount]
    end

    def self.aftermath_run(battle)
      list = aftermath_list(battle)
      return if list.empty?
      todo = list.dup
      list.clear
      todo.each do |b, pkmn, kind, ability, turn|
        next if battle.decision > 0 || turn != battle.turnCount
        next if !b.equal?(battle.battlers[b.index]) || !b.pokemon.equal?(pkmn) || b.hp > 0
        next if !battle.battlers.any? { |o| o && !o.equal?(b) && !o.fainted? && o.near?(b) }
        was_fainted = b.instance_variable_get(:@fainted)
        b.hp = 1                                  # back for the move only
        b.instance_variable_set(:@fainted, false)
        old = KIFER::Specials2.outburst
        KIFER::Specials2.outburst = kind
        begin
          KIFER::BatchF.use_extra_move(b, KIFER::Specials2.blast_id(kind), -1, 100, ability)
        rescue StandardError => e
          KIFER.log("Aftermath: #{e.class}: #{e.message}")
        ensure
          KIFER::Specials2.outburst = old
          b.hp = 0
          b.instance_variable_set(:@fainted, was_fainted)
        end
        battle.pbJudge
      end
    end

    # Damp: contact makes the other Pokemon pure Water
    def self.damp(bearer, other, ability)
      return if other.fainted?
      return if other.pbHasType?(:WATER) && !other.pbHasOtherType?(:WATER)
      splash(bearer, ability)
      other.pbChangeTypes(:WATER)
      bearer.battle.pbDisplay(_INTL("{1} transformed into the {2} type!", other.pbThis,
                                    GameData::Type.get(:WATER).name))
      hide(bearer)
    end

    # Cures a status (Leaf Guard, Vital Spirit, Healer on itself)
    def self.cure(battler, ability, splash_too = true)
      return false if battler.status == :NONE
      splash(battler, ability) if splash_too
      battler.pbCureStatus(true)
      hide(battler) if splash_too
      return true
    end

    # The stat-raising absorb abilities (Lightning Rod...): higher attacking stat
    def self.absorb(user, target, move, type, absorb_type, battle)
      return pbBattleMoveImmunityStatAbility(user, target, move, type, absorb_type,
                                             highest_attack(target), 1, battle)
    end

    # Maximize a stat on a crit, else +1 (Anger Point, Stamina)
    def self.crit_or_one(target, stat, ability)
      battle = target.battle
      if target.damageState.critical
        return if !target.pbCanRaiseStatStage?(stat, target)
        splash(target, ability)
        target.stages[stat] = 6
        battle.pbCommonAnimation("StatUp", target)
        battle.pbDisplay(_INTL("{1} maxed its {2}!", target.pbThis, GameData::Stat.get(stat).name))
        hide(target)
      else
        target.pbRaiseStatStageByAbility(stat, 1, target, true, KIFER.ability_name(ability))
      end
    end

    # Smokescreen (White Smoke): turns left per side
    def self.smoke(battle)
      s = battle.instance_variable_get(:@kifer_v_smoke)
      s = battle.instance_variable_set(:@kifer_v_smoke, [0, 0]) if !s
      return s
    end

    # Forewarn: positions whose Future Sight is Forewarn's
    def self.forewarn(battle)
      h = battle.instance_variable_get(:@kifer_v_forewarn)
      h = battle.instance_variable_set(:@kifer_v_forewarn, {}) if !h
      return h
    end

    # Hazards on a side (Pickup clears them, Shield Dust ignores them)
    HAZARDS = [:StealthRock, :Spikes, :ToxicSpikes, :StickyWeb]

    def self.hazard_values(side)
      return HAZARDS.map do |h|
        next nil if !PBEffects.const_defined?(h)
        side.effects[PBEffects.const_get(h)]
      end
    end

    def self.hazards?(side)
      hazard_values(side).any? { |v| v == true || (v.is_a?(Numeric) && v > 0) }
    end

    def self.clear_hazards(side)
      HAZARDS.each do |h|
        next if !PBEffects.const_defined?(h)
        e = PBEffects.const_get(h)
        side.effects[e] = side.effects[e].is_a?(Numeric) ? 0 : false
      end
    end

    # Extra damage multipliers that must not stack per copy (STAB, burn)
    def self.extra_multipliers(move, user, target, type, mults)
      # Heatproof / Flare Boost: no burn Attack drop
      if user.status == :BURN && move.physicalMove? && move.damageReducedByBurn? &&
         !user.hasActiveAbility?(:GUTS) && user.hasActiveAbility?([:HEATPROOF, :FLAREBOOST])
        mults[:final_damage_multiplier] *= 2
      end
      # -ate abilities and Steelworker: STAB for their type (none with Relic
      # Stone on the field or against Wonder Skin, as the ER ones)
      if KIFER::BatchF.ability_stab?(user, type) &&
         ATE_TYPES.any? { |ab, t| t == type && user.hasActiveAbility?(ab) } &&
         !KIFER::Specials2.relic_on?(user) && !KIFER::Specials2.blocks?(user, target)
        mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
      end
    end

    # Color Change: the type that takes the least from the move (first one
    # found in type order, starting from its own first type, as ER)
    def self.color_change(move, user, target)
      return if !move.damagingMove? || user.index == target.index
      return if target.instance_variable_get(:@kifer_v_color_turn) == target.battle.turnCount
      type = move.calcType
      return if !type || GameData::Type.get(type).pseudo_type
      best = target.type1
      best_mod = move.pbCalcTypeModSingle(type, best, user, target)
      GameData::Type.each do |t|
        next if t.pseudo_type
        m = move.pbCalcTypeModSingle(type, t.id, user, target)
        if m < best_mod
          best_mod = m
          best = t.id
        end
        break if best_mod == 0
      end
      return if target.pbHasType?(best)
      target.instance_variable_set(:@kifer_v_color_turn, target.battle.turnCount)
      battle = target.battle
      splash(target, :COLORCHANGE)
      target.pbChangeTypes(best)
      battle.pbDisplay(_INTL("{1}'s {2} made it the {3} type!", target.pbThis,
                             KIFER.ability_name(:COLORCHANGE), GameData::Type.get(best).name))
      hide(target)
    end
  end
end

unless defined?(KIFER::ERVersions::DONE)
  KIFER::ERVersions::DONE = true

  #=============================================================================
  # Weather and terrain on entry: 8 turns (12 with the item)
  #=============================================================================
  { :DRIZZLE => :Rain, :DROUGHT => :Sun, :SANDSTREAM => :Sandstorm,
    :SNOWWARNING => :Hail }.each do |id, weather|
    KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, id) do |ability, battler, battle|
      KIFER::ERVersions.weather_ability(weather, battler, battle, ability)
    end
  end

  { :PSYCHICSURGE => :Psychic, :MISTYSURGE => :Misty, :GRASSYSURGE => :Grassy }.each do |id, terrain|
    KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, id) do |ability, battler, battle|
      KIFER::ERVersions.terrain_ability(terrain, battler, battle, ability)
    end
  end

  #=============================================================================
  # Speed
  #=============================================================================
  { :SWIFTSWIM => [:Rain, :HeavyRain], :CHLOROPHYLL => [:Sun, :HarshSun],
    :SANDRUSH => [:Sandstorm], :SLUSHRUSH => [:Hail] }.each do |id, weathers|
    KIFER::ERVersions.wrap(BattleHandlers::SpeedCalcAbility, id) do |ability, battler, mult|
      next mult * 1.5 if weathers.include?(battler.battle.pbWeather)
      next mult
    end
  end

  KIFER::ERVersions.wrap(BattleHandlers::SpeedCalcAbility, :LIGHTMETAL) do |ability, battler, mult|
    next mult * 1.3
  end

  # Aerilate: a Flying-type user is 10% faster when it uses a Flying move
  KIFER::ERVersions.wrap(BattleHandlers::SpeedCalcAbility, :AERILATE) do |ability, battler, mult|
    next mult if !battler.pbHasType?(:FLYING)
    ch = battler.battle.choices[battler.index] rescue nil
    m = (ch && ch[0] == :UseMove) ? ch[2] : nil
    next mult if !m
    t = m.type
    t = :FLYING if t == :NORMAL
    next (t == :FLYING) ? mult * 1.1 : mult
  end

  #=============================================================================
  # Accuracy
  #=============================================================================
  KIFER::ERVersions.wrap(BattleHandlers::AccuracyCalcUserAbility, :HUSTLE) do |ability, mods, user, target, move, type|
    mods[:accuracy_multiplier] *= 0.9 if !move.statusMove?
  end

  KIFER::ERVersions.wrap(BattleHandlers::AccuracyCalcUserAbility, [:KEENEYE, :ILLUMINATE]) do |ability, mods, user, target, move, type|
    mods[:accuracy_multiplier] *= 1.2
  end

  KIFER::ERVersions.wrap(BattleHandlers::AccuracyCalcUserAbility, :VICTORYSTAR) do |ability, mods, user, target, move, type|
    mods[:accuracy_multiplier] *= 1.2
  end

  KIFER::ERVersions.wrap(BattleHandlers::AccuracyCalcUserAllyAbility, :VICTORYSTAR) do |ability, mods, user, target, move, type|
    mods[:accuracy_multiplier] *= 1.2
  end

  KIFER::ERVersions.wrap(BattleHandlers::AccuracyCalcUserAbility, :INNERFOCUS) do |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0 if move.id == :FOCUSBLAST
  end

  #=============================================================================
  # Damage: the attacker's ability
  #=============================================================================
  { :OVERGROW => :GRASS, :BLAZE => :FIRE, :TORRENT => :WATER, :SWARM => :BUG }.each do |id, t|
    KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, id) do |ability, user, target, move, mults, baseDmg, type|
      next if type != t
      mults[:attack_multiplier] *= (user.hp <= user.totalhp / 3) ? 1.5 : 1.2
    end
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :HUSTLE) do |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.4
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, [:PLUS, :MINUS]) do |ability, user, target, move, mults, baseDmg, type|
    user.eachAlly do |b|
      next if !b.hasActiveAbility?([:PLUS, :MINUS])
      mults[:base_damage_multiplier] *= 2
      break
    end
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :IRONFIST) do |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if move.punchingMove?
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :STRONGJAW) do |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if move.bitingMove?
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :MEGALAUNCHER) do |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if move.pulseMove?
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, [:TOUGHCLAWS, :BIGPECKS]) do |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if move.pbContactMove?(user)
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :NEUROFORCE) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 1.35 if Effectiveness.super_effective?(target.damageState.typeMod)
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :DEFEATIST) do |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] /= 2 if user.hp <= user.totalhp / 3
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :LEVITATE) do |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.25 if type == :FLYING
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :RIVALRY) do |ability, user, target, move, mults, baseDmg, type|
    if user.gender != 2 && target.gender != 2 && user.gender == target.gender
      mults[:base_damage_multiplier] *= 1.25
    end
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :SOLARPOWER) do |ability, user, target, move, mults, baseDmg, type|
    next if ![:Sun, :HarshSun].include?(user.battle.pbWeather)
    mults[:attack_multiplier] *= 1.5 if KIFER::ERVersions.uses_highest?(user, move)
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :SANDFORCE) do |ability, user, target, move, mults, baseDmg, type|
    next if user.battle.pbWeather != :Sandstorm
    mults[:attack_multiplier] *= 1.5 if KIFER::ERVersions.uses_highest?(user, move)
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :STAKEOUT) do |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 2 if target.turnCount == 0
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :LONGREACH) do |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.2 if move.physicalMove?
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :LIQUIDVOICE) do |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.2 if move.soundMove?
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :ILLUSION) do |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if user.effects[PBEffects::Illusion]
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, :NORMALIZE) do |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.1 if type == :NORMAL
  end

  # -ate abilities: no power boost (their STAB is in the multipliers hook)
  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcUserAbility, [:AERILATE, :PIXILATE, :REFRIGERATE, :GALVANIZE, :STEELWORKER])

  #=============================================================================
  # Damage: the target's ability (Mold Breaker skips these, as PIF)
  #=============================================================================
  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAbility, [:BATTLEARMOR, :SHELLARMOR]) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.8
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAbility, :IMMUNITY) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.5 if type == :POISON
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAbility, :MAGMAARMOR) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.7 if type == :WATER || type == :ICE
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAbility, :WATERCOMPACTION) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.5 if type == :WATER
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAbility, :OVERCOAT) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.8 if move.specialMove?
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAbility, [:FILTER, :SOLIDROCK]) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.65 if Effectiveness.super_effective?(target.damageState.typeMod)
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAbilityNonIgnorable, :PRISMARMOR) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.65 if Effectiveness.super_effective?(target.damageState.typeMod)
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAbility, :RIVALRY) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.75 if KIFER::ERVersions.genders_opposite?(user, target)
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAbility, :STALL) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.7 if !target.movedThisRound?
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAbility, :STEELWORKER) do |ability, user, target, move, mults, baseDmg, type|
    if target.pbHasType?(:STEEL) && (type == :GHOST || type == :DARK)
      mults[:final_damage_multiplier] *= 0.5
    end
  end

  KIFER::ERVersions.wrap(BattleHandlers::DamageCalcTargetAllyAbility, :FRIENDGUARD) do |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.75
  end

  # Stall no longer moves last
  KIFER::ERVersions.wrap(BattleHandlers::PriorityBracketChangeAbility, :STALL)

  #=============================================================================
  # Move types
  #=============================================================================
  KIFER::ERVersions.wrap(BattleHandlers::MoveBaseTypeModifierAbility, :LIQUIDVOICE) do |ability, user, move, type|
    next :WATER if type == :NORMAL && move.soundMove? && GameData::Type.exists?(:WATER)
  end

  KIFER::ERVersions.wrap(BattleHandlers::MoveBaseTypeModifierAbility, :STEELWORKER) do |ability, user, move, type|
    next :STEEL if type == :NORMAL && GameData::Type.exists?(:STEEL)
  end

  #=============================================================================
  # Critical hits
  #=============================================================================
  KIFER::ERVersions.wrap(BattleHandlers::CriticalCalcUserAbility, :MERCILESS) do |ability, user, target, c|
    st = target.status
    next 99 if [:POISON, :PARALYSIS, :BLEEDING].include?(st)
    next 99 if (target.stages[:SPEED] || 0) < 0
    next 99 if target.hasActiveItem?(:IRONBALL)
    next c
  end

  KIFER::ERVersions.wrap(BattleHandlers::CriticalCalcUserAbility, :HYPERCUTTER) do |ability, user, target, c|
    m = user.battle.choices[user.index][2] rescue nil
    contact = m ? m.pbContactMove?(user) : false
    next contact ? c + 1 : c
  end

  #=============================================================================
  # Stat drops
  #=============================================================================
  KIFER::ERVersions.wrap(BattleHandlers::StatLossImmunityAbility, :HYPERCUTTER) do |ability, battler, stat, battle, showMessages|
    next false if stat != :ATTACK && stat != :SPECIAL_ATTACK
    if showMessages
      KIFER::ERVersions.splash(battler, ability)
      battle.pbDisplay(_INTL("{1}'s {2} cannot be lowered!", battler.pbThis, GameData::Stat.get(stat).name))
      KIFER::ERVersions.hide(battler)
    end
    next true
  end

  # Big Pecks and White Smoke no longer block stat drops
  KIFER::ERVersions.wrap(BattleHandlers::StatLossImmunityAbility, [:BIGPECKS, :WHITESMOKE])

  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnStatLoss, :RUNAWAY) do |ability, battler, stat, user|
    next if !user || !user.opposes?(battler)
    battler.pbRaiseStatStageByAbility(:SPEED, 2, battler, true, KIFER.ability_name(ability))
  end

  #=============================================================================
  # Absorbing moves
  #=============================================================================
  { :LIGHTNINGROD => :ELECTRIC, :STORMDRAIN => :WATER, :SAPSIPPER => :GRASS,
    :JUSTIFIED => :DARK }.each do |id, t|
    KIFER::ERVersions.wrap(BattleHandlers::MoveImmunityTargetAbility, id) do |ability, user, target, move, type, battle|
      next KIFER::ERVersions.absorb(user, target, move, type, t, battle)
    end
  end

  # Justified: the stat raise is now on absorbing (above)
  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, :JUSTIFIED)

  # Anticipation: dodges the first super effective hit of the battle
  KIFER::ERVersions.wrap(BattleHandlers::MoveImmunityTargetAbility, :ANTICIPATION) do |ability, user, target, move, type, battle|
    next false if !move.damagingMove? || !target.opposes?(user)
    next false if !Effectiveness.super_effective?(target.damageState.typeMod)
    next false if KIFER::ERVersions.note(battle, :anticipation, target)
    KIFER::ERVersions.set_note(battle, :anticipation, target)
    KIFER::ERVersions.splash(target, ability)
    battle.pbDisplay(_INTL("{1} avoided the attack!", target.pbThis))
    KIFER::ERVersions.hide(target)
    next true
  end

  #=============================================================================
  # On being hit / on hitting
  #=============================================================================
  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, :STATIC) do |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_target(ability, user, target, move, :PARALYSIS, 30, 10)
  end
  KIFER::ERVersions.wrap(BattleHandlers::UserAbilityOnHit, :STATIC) do |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_user(ability, user, target, move, :PARALYSIS, 30, 10)
  end

  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, :FLAMEBODY) do |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_target(ability, user, target, move, :BURN, 30, 20)
  end
  KIFER::ERVersions.wrap(BattleHandlers::UserAbilityOnHit, :FLAMEBODY) do |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_user(ability, user, target, move, :BURN, 30, 20)
  end

  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, [:POISONPOINT, :POISONTOUCH]) do |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_target(ability, user, target, move, :POISON, 30, 0)
  end
  KIFER::ERVersions.wrap(BattleHandlers::UserAbilityOnHit, [:POISONPOINT, :POISONTOUCH]) do |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_user(ability, user, target, move, :POISON, 30, 0)
  end

  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, :CUTECHARM) do |ability, user, target, move, battle|
    next if target.fainted?
    KIFER::ERVersions.on_hit_target(ability, user, target, move, :ATTRACT, 50, 0)
  end
  KIFER::ERVersions.wrap(BattleHandlers::UserAbilityOnHit, :CUTECHARM) do |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_user(ability, user, target, move, :ATTRACT, 50, 0)
  end

  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, :DAMP) do |ability, user, target, move, battle|
    next if !move.pbContactMove?(user) || !user.affectedByContactEffect?
    KIFER::ERVersions.damp(target, user, ability)
  end
  KIFER::ERVersions.wrap(BattleHandlers::UserAbilityOnHit, :DAMP) do |ability, user, target, move, battle|
    next if !move.pbContactMove?(user) || user.index == target.index
    KIFER::ERVersions.damp(user, target, ability)
  end

  # Illuminate: its hits remove the target's Ghost type
  KIFER::ERVersions.wrap(BattleHandlers::UserAbilityOnHit, :ILLUMINATE) do |ability, user, target, move, battle|
    next if target.fainted? || !target.pbHasType?(:GHOST)
    types = target.pbTypes(true) - [:GHOST]
    KIFER::ERVersions.splash(user, ability)
    if types.empty?
      target.pbChangeTypes(:NORMAL)
    else
      target.pbChangeTypes(types[0])
      target.instance_variable_set(:@type2, types[1]) if types[1]
    end
    battle.pbDisplay(_INTL("{1} lost its {2} type!", target.pbThis, GameData::Type.get(:GHOST).name))
    KIFER::ERVersions.hide(user)
  end

  # -ate abilities on a user of that type: 10% status with those moves
  { :PIXILATE => [:FAIRY, :ATTRACT], :GALVANIZE => [:ELECTRIC, :PARALYSIS],
    :REFRIGERATE => [:ICE, :FROSTBITE] }.each do |id, (t, status)|
    KIFER::ERVersions.wrap(BattleHandlers::UserAbilityOnHit, id) do |ability, user, target, move, battle|
      next if target.fainted? || user.index == target.index
      next if !user.pbHasType?(t) || move.calcType != t
      next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      next if battle.pbRandom(10) != 0
      KIFER::ERVersions.apply_status(user, target, status, ability)
    end
  end

  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, :ANGERPOINT) do |ability, user, target, move, battle|
    KIFER::ERVersions.crit_or_one(target, :ATTACK, ability)
  end

  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, :STAMINA) do |ability, user, target, move, battle|
    KIFER::ERVersions.crit_or_one(target, :DEFENSE, ability)
  end

  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, :WEAKARMOR) do |ability, user, target, move, battle|
    next if !move.physicalMove?
    next if !target.pbCanLowerStatStage?(:DEFENSE, target) && !target.pbCanRaiseStatStage?(:SPEED, target)
    name = KIFER.ability_name(ability)
    KIFER::ERVersions.splash(target, ability)
    target.pbLowerStatStageByAbility(:DEFENSE, 1, target, false, false, name)
    target.pbRaiseStatStageByAbility(:SPEED, 2, target, false, name)
    KIFER::ERVersions.hide(target)
  end

  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, :CURSEDBODY) do |ability, user, target, move, battle|
    next if user.fainted? || user.index == target.index
    next if user.effects[PBEffects::Disable] > 0
    regularMove = nil
    user.eachMove do |m|
      next if m.id != user.lastRegularMoveUsed
      regularMove = m
      break
    end
    next if !regularMove || (regularMove.pp == 0 && regularMove.total_pp > 0)
    next if battle.pbRandom(100) >= 30
    KIFER::ERVersions.splash(target, ability)
    if !move.pbMoveFailedAromaVeil?(target, user, true)
      user.effects[PBEffects::Disable]     = 5   # 4 more turns
      user.effects[PBEffects::DisableMove] = regularMove.id
      battle.pbDisplay(_INTL("{1}'s {2} was disabled!", user.pbThis, regularMove.name))
      KIFER::ERVersions.hide(target)
      user.pbItemStatusCureCheck
    end
    KIFER::ERVersions.hide(target)
  end

  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnFlinch, :RATTLED) do |ability, battler, battle|
    battler.pbRaiseStatStageByAbility(:SPEED, 1, battler, true, KIFER.ability_name(ability))
  end

  # Berserk: higher attacking stat, once per battle
  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityAfterMoveUse, :BERSERK) do |ability, target, user, move, switched, battle|
    next if !move.damagingMove? || !user.opposes?(target)
    next if target.damageState.initialHP < target.totalhp / 2 || target.hp >= target.totalhp / 2
    next if KIFER::ERVersions.note(battle, :berserk, target)
    stat = KIFER::ERVersions.highest_attack(target)
    next if !target.pbCanRaiseStatStage?(stat, target)
    KIFER::ERVersions.set_note(battle, :berserk, target)
    target.pbRaiseStatStageByAbility(stat, 1, target, true, KIFER.ability_name(ability))
  end

  # Color Change works before the hit now (pbSuccessCheckAgainstTarget below)
  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityAfterMoveUse, :COLORCHANGE)

  # Vital Spirit: its Fighting moves cure its status
  KIFER::ERVersions.wrap(BattleHandlers::UserAbilityEndOfMove, :VITALSPIRIT) do |ability, user, targets, move, battle|
    next if user.fainted? || user.status == :NONE || move.calcType != :FIGHTING
    KIFER::ERVersions.cure(user, ability)
  end

  #=============================================================================
  # End of round
  #=============================================================================
  KIFER::ERVersions.wrap(BattleHandlers::EORWeatherAbility, [:RAINDISH, :ICEBODY]) do |ability, weather, battler, battle|
    want = (ability == :RAINDISH) ? [:Rain, :HeavyRain] : [:Hail]
    next if !want.include?(weather)
    next if battler.turnCount == 0 || battler.hp >= battler.totalhp || !battler.canHeal?
    KIFER::ERVersions.splash(battler, ability)
    battler.pbRecoverHP(battler.totalhp / 8)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
    KIFER::ERVersions.hide(battler)
  end

  # Solar Power: no HP loss in sun
  KIFER::ERVersions.wrap(BattleHandlers::EORWeatherAbility, :SOLARPOWER)

  KIFER::ERVersions.wrap(BattleHandlers::EORHealingAbility, :LEAFGUARD) do |ability, battler, battle|
    next if battler.status == :NONE || ![:Sun, :HarshSun].include?(battle.pbWeather)
    KIFER::ERVersions.cure(battler, ability)
  end

  KIFER::ERVersions.wrap(BattleHandlers::StatusImmunityAbility, :LEAFGUARD)

  KIFER::ERVersions.wrap(BattleHandlers::EORHealingAbility, :HEALER) do |ability, battler, battle|
    next unless battle.pbRandom(100) < 30
    ally = nil
    battler.eachAlly { |b| ally = b if !ally && b.status != :NONE }
    if ally
      KIFER::ERVersions.splash(battler, ability)
      ally.pbCureStatus(true)
      KIFER::ERVersions.hide(battler)
    elsif battler.status != :NONE
      KIFER::ERVersions.cure(battler, ability)
    end
  end

  KIFER::ERVersions.wrap(BattleHandlers::EOREffectAbility, :BADDREAMS) do |ability, battler, battle|
    battle.eachOtherSideBattler(battler.index) do |b|
      next if !b.asleep? || b.hasActiveAbility?(:SWEETDREAMS)
      next if !b.takesIndirectDamage?
      KIFER::ERVersions.splash(battler, ability)
      oldHP = b.hp
      b.pbReduceHP(b.totalhp / 4)
      battle.pbDisplay(_INTL("{1} is tormented!", b.pbThis))
      KIFER::ERVersions.hide(battler)
      b.pbItemHPHealCheck
      b.pbAbilitiesOnDamageTaken(oldHP)
      b.pbFaint if b.fainted?
    end
  end

  KIFER::ERVersions.wrap(BattleHandlers::EOREffectAbility, :MOODY) do |ability, battler, battle|
    next if battler.turnCount == 0
    up   = KIFER::ERVersions::MAIN_STATS.select { |s| battler.pbCanRaiseStatStage?(s, battler) }
    down = KIFER::ERVersions::MAIN_STATS.select { |s| battler.pbCanLowerStatStage?(s, battler) }
    next if up.empty? && down.empty?
    name = KIFER.ability_name(ability)
    KIFER::ERVersions.splash(battler, ability)
    if !up.empty?
      s = up[battle.pbRandom(up.length)]
      battler.pbRaiseStatStageByAbility(s, 2, battler, false, name)
      down.delete(s)
    end
    if !down.empty?
      s = down[battle.pbRandom(down.length)]
      battler.pbLowerStatStageByAbility(s, 1, battler, false, false, name)
    end
    KIFER::ERVersions.hide(battler)
    battler.pbItemStatRestoreCheck if !down.empty?
  end

  # Pickup no longer picks up items (it clears hazards on entry, below)
  KIFER::ERVersions.wrap(BattleHandlers::EORGainItemAbility, :PICKUP)

  #=============================================================================
  # On entry
  #=============================================================================
  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, :PICKUP) do |ability, battler, battle|
    side = battler.pbOwnSide
    next if !KIFER::ERVersions.hazards?(side)
    KIFER::ERVersions.splash(battler, ability)
    KIFER::ERVersions.clear_hazards(side)
    battler.instance_variable_set(:@kifer_v_hazards_cleared, true)
    battle.pbDisplay(_INTL("{1} cleared away the hazards!", battler.pbThis))
    KIFER::ERVersions.hide(battler)
  end

  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, :WATERVEIL) do |ability, battler, battle|
    next if battler.effects[PBEffects::AquaRing]
    KIFER::ERVersions.splash(battler, ability)
    battler.effects[PBEffects::AquaRing] = true
    battle.pbDisplay(_INTL("{1} surrounded itself with a veil of water!", battler.pbThis))
    KIFER::ERVersions.hide(battler)
  end

  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, :PRESSURE) do |ability, battler, battle|
    KIFER::ERVersions.splash(battler, ability)
    battle.pbDisplay(_INTL("{1} is exerting its pressure!", battler.pbThis))
    battle.eachBattler do |b|
      changed = false
      b.stages.each_key do |s|
        v = b.stages[s]
        if b.index == battler.index ? v < 0 : v > 0
          b.stages[s] = 0
          changed = true
        end
      end
      next if !changed
      if b.index == battler.index
        battle.pbDisplay(_INTL("{1}'s lowered stats returned to normal!", b.pbThis))
      else
        battle.pbDisplay(_INTL("{1}'s raised stats returned to normal!", b.pbThis))
      end
    end
    KIFER::ERVersions.hide(battler)
  end

  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, [:CLOUDNINE, :AIRLOCK]) do |ability, battler, battle|
    KIFER::ERVersions.splash(battler, ability)
    battle.pbDisplay(_INTL("The weather cleared up!")) if KIFER::ERVersions.clear_weather(battle)
    battle.pbDisplay(_INTL("The effects of the weather disappeared."))
    if ability == :AIRLOCK && battler.pbOwnSide.effects[PBEffects::Tailwind] <= 0
      battler.pbOwnSide.effects[PBEffects::Tailwind] = 3
      battle.pbDisplay(_INTL("The Tailwind blew from behind {1}!", battler.pbTeam(true)))
    end
    KIFER::ERVersions.hide(battler)
  end

  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, :WHITESMOKE) do |ability, battler, battle|
    s = KIFER::ERVersions.smoke(battle)
    next if s[battler.idxOwnSide] > 0
    s[battler.idxOwnSide] = (battler.hasActiveItem?(:LIGHTCLAY)) ? 5 : 3
    KIFER::ERVersions.splash(battler, ability)
    battle.pbDisplay(_INTL("A thick smoke covers {1}!", battler.pbTeam(true)))
    KIFER::ERVersions.hide(battler)
  end

  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, :FRISK) do |ability, battler, battle|
    foes = []
    battle.eachOtherSideBattler(battler.index) { |b| foes.push(b) if b.item }
    next if foes.empty?
    KIFER::ERVersions.splash(battler, ability)
    foes.each do |b|
      battle.pbDisplay(_INTL("{1} frisked {2} and found its {3}!", battler.pbThis, b.pbThis(true), b.itemName))
      b.effects[PBEffects::Embargo] = 2 if b.effects[PBEffects::Embargo] <= 0
    end
    KIFER::ERVersions.hide(battler)
  end

  { :TURBOBLAZE => [:FIRE, "{1} is radiating a blazing aura!"],
    :TERAVOLT   => [:ELECTRIC, "{1} is radiating a bursting aura!"] }.each do |id, (t, msg)|
    KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, id) do |ability, battler, battle|
      KIFER::ERVersions.splash(battler, ability)
      battle.pbDisplay(_INTL(msg, battler.pbThis))
      if !battler.pbHasType?(t) && GameData::Type.exists?(t)
        battler.effects[PBEffects::Type3] = t
        battle.pbDisplay(_INTL("{1} became {2} type too!", battler.pbThis, GameData::Type.get(t).name))
      end
      KIFER::ERVersions.hide(battler)
    end
  end

  # Download: the foe opposite, stat stages count; a tie raises Attack
  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, :DOWNLOAD) do |ability, battler, battle|
    foe = battler.pbDirectOpposing(true)
    next if !foe || foe.fainted?
    df  = KIFER::ERVersions.staged(foe, :DEFENSE)
    sdf = KIFER::ERVersions.staged(foe, :SPECIAL_DEFENSE)
    stat = (df > sdf) ? :SPECIAL_ATTACK : :ATTACK
    battler.pbRaiseStatStageByAbility(stat, 1, battler, true, KIFER.ability_name(ability))
  end

  # Forewarn: an 80 power Future Sight on the foe opposite
  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, :FOREWARN) do |ability, battler, battle|
    target = nil
    battle.eachOtherSideBattler(battler.index) do |b|
      next if target || battle.positions[b.index].effects[PBEffects::FutureSightCounter] > 0
      target = b
    end
    next if !target
    eff = battle.positions[target.index].effects
    eff[PBEffects::FutureSightCounter]        = 3
    eff[PBEffects::FutureSightMove]           = :FUTURESIGHT
    eff[PBEffects::FutureSightUserIndex]      = battler.index
    eff[PBEffects::FutureSightUserPartyIndex] = battler.pokemonIndex
    KIFER::ERVersions.forewarn(battle)[target.index] = true
    KIFER::ERVersions.splash(battler, ability)
    battle.pbDisplay(_INTL("{1} foresaw an attack!", battler.pbThis))
    KIFER::ERVersions.hide(battler)
  end

  # Flare Boost: burns itself when it enters fog
  KIFER::ERVersions.wrap(BattleHandlers::AbilityOnSwitchIn, :FLAREBOOST) do |ability, battler, battle|
    next if battle.pbWeather != :Fog || !battler.pbCanBurn?(battler, false)
    KIFER::ERVersions.splash(battler, ability)
    battler.pbBurn(battler)
    KIFER::ERVersions.hide(battler)
  end

  #=============================================================================
  # Game methods (inline checks)
  #=============================================================================
  class PokeBattle_Move
    # STAB for -ate abilities and Steelworker; no burn Attack drop
    alias kifer_v_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_v_pbCalcDamageMultipliers)
    def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
      kifer_v_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
      return if !KIFER::ERVersions.on?
      begin
        KIFER::ERVersions.extra_multipliers(self, user, target, type, multipliers)
      rescue StandardError => e
        KIFER.log("ER versions multipliers: #{e.class}: #{e.message}")
      end
    end

    # Corrosion: Poison moves are super effective on Steel
    alias kifer_v_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_v_pbCalcTypeModSingle)
    def pbCalcTypeModSingle(moveType, defType, user, target)
      ret = kifer_v_pbCalcTypeModSingle(moveType, defType, user, target)
      if moveType == :POISON && defType == :STEEL && user && KIFER::ERVersions.on? &&
         user.hasActiveAbility?(:CORROSION)
        ret = Effectiveness::SUPER_EFFECTIVE_ONE
      end
      return ret
    end

    # Normalize: Normal moves ignore resistances (not immunities)
    alias kifer_v_pbCalcTypeMod pbCalcTypeMod unless method_defined?(:kifer_v_pbCalcTypeMod)
    def pbCalcTypeMod(moveType, user, target)
      ret = kifer_v_pbCalcTypeMod(moveType, user, target)
      if moveType == :NORMAL && ret > 0 && ret < Effectiveness::NORMAL_EFFECTIVE && user &&
         KIFER::ERVersions.on? && user.hasActiveAbility?(:NORMALIZE)
        ret = Effectiveness::NORMAL_EFFECTIVE
      end
      return ret
    end

    # Smoke (White Smoke): the side's evasion x1.25
    alias kifer_v_pbCalcAccuracyModifiers pbCalcAccuracyModifiers unless method_defined?(:kifer_v_pbCalcAccuracyModifiers)
    def pbCalcAccuracyModifiers(user, target, modifiers)
      kifer_v_pbCalcAccuracyModifiers(user, target, modifiers)
      s = @battle.instance_variable_get(:@kifer_v_smoke)
      if s && s[target.idxOwnSide] > 0 && target.opposes?(user) && KIFER::ERVersions.on?
        modifiers[:evasion_multiplier] *= 1.25
      end
    end
  end

  # Limber: half recoil and crash damage
  class PokeBattle_RecoilMove
    alias kifer_v_pbEffectAfterAllHits pbEffectAfterAllHits unless method_defined?(:kifer_v_pbEffectAfterAllHits)
    def pbEffectAfterAllHits(user, target)
      half = KIFER::ERVersions.on? && user.hasActiveAbility?(:LIMBER)
      user.instance_variable_set(:@kifer_v_half_hp_loss, true) if half
      begin
        kifer_v_pbEffectAfterAllHits(user, target)
      ensure
        user.instance_variable_set(:@kifer_v_half_hp_loss, nil) if half
      end
    end
  end

  if defined?(PokeBattle_Move_10B) && PokeBattle_Move_10B.method_defined?(:pbCrashDamage)
    class PokeBattle_Move_10B
      alias kifer_v_pbCrashDamage pbCrashDamage unless method_defined?(:kifer_v_pbCrashDamage)
      def pbCrashDamage(user)
        half = KIFER::ERVersions.on? && user.hasActiveAbility?(:LIMBER)
        user.instance_variable_set(:@kifer_v_half_hp_loss, true) if half
        begin
          kifer_v_pbCrashDamage(user)
        ensure
          user.instance_variable_set(:@kifer_v_half_hp_loss, nil) if half
        end
      end
    end
  end

  # Forewarn's Future Sight: 80 power, can't miss
  if defined?(PokeBattle_Move_111)
    class PokeBattle_Move_111
      alias kifer_v_pbBaseDamage pbBaseDamage unless method_defined?(:kifer_v_pbBaseDamage)
      def pbBaseDamage(baseDmg, user, target)
        if @battle.futureSight && KIFER::ERVersions.forewarn(@battle)[target.index]
          return 80
        end
        return kifer_v_pbBaseDamage(baseDmg, user, target)
      end

      alias kifer_v_pbAccuracyCheck pbAccuracyCheck unless method_defined?(:kifer_v_pbAccuracyCheck)
      def pbAccuracyCheck(user, target)
        return true if @battle.futureSight && KIFER::ERVersions.forewarn(@battle)[target.index]
        return kifer_v_pbAccuracyCheck(user, target)
      end

      alias kifer_v_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_v_pbEffectAgainstTarget)
      def pbEffectAgainstTarget(user, target)
        KIFER::ERVersions.forewarn(@battle).delete(target.index) if !@battle.futureSight
        return kifer_v_pbEffectAgainstTarget(user, target)
      end
    end
  end

  # Taunt: Oblivious, Own Tempo, Inner Focus, Scrappy, Vital Spirit
  if defined?(PokeBattle_Move_0BA)
    class PokeBattle_Move_0BA
      alias kifer_v_pbFailsAgainstTarget? pbFailsAgainstTarget? unless method_defined?(:kifer_v_pbFailsAgainstTarget?)
      def pbFailsAgainstTarget?(user, target)
        if KIFER::ERVersions.on? && !@battle.moldBreaker && target.effects[PBEffects::Taunt] <= 0
          KIFER::ERVersions::TAUNT_IMMUNE.each do |id|
            next if !target.hasActiveAbility?(id)
            KIFER::ERVersions.splash(target, id)
            @battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
            KIFER::ERVersions.hide(target)
            return true
          end
        end
        return kifer_v_pbFailsAgainstTarget?(user, target)
      end
    end
  end

  class PokeBattle_Battler
    # Limber: half recoil / crash
    alias kifer_v_pbReduceHP pbReduceHP unless method_defined?(:kifer_v_pbReduceHP)
    def pbReduceHP(amt, *args)
      amt = [(amt / 2.0).round, 1].max if @kifer_v_half_hp_loss && amt > 0
      return kifer_v_pbReduceHP(amt, *args)
    end

    # Limber, Clear Body, Full Metal Body: its own moves can't lower its stats
    alias kifer_v_pbCanLowerStatStage? pbCanLowerStatStage? unless method_defined?(:kifer_v_pbCanLowerStatStage?)
    def pbCanLowerStatStage?(stat, user = nil, move = nil, showFailMsg = false, ignoreContrary = false)
      if move && user && user.index == @index && !fainted? && KIFER::ERVersions.on? &&   # its moves, not Moody / Weak Armor
         !hasActiveAbility?(:CONTRARY)
        KIFER::ERVersions::SELF_DROP_BLOCK.each do |id|
          next if !hasActiveAbility?(id)
          if showFailMsg
            KIFER::ERVersions.splash(self, id)
            @battle.pbDisplay(_INTL("{1}'s stats cannot be lowered!", pbThis))
            KIFER::ERVersions.hide(self)
          end
          return false
        end
      end
      return kifer_v_pbCanLowerStatStage?(stat, user, move, showFailMsg, ignoreContrary)
    end

    # Oblivious, Own Tempo, Inner Focus, Scrappy: no Intimidate
    alias kifer_v_pbLowerAttackStatStageIntimidate pbLowerAttackStatStageIntimidate unless method_defined?(:kifer_v_pbLowerAttackStatStageIntimidate)
    def pbLowerAttackStatStageIntimidate(user)
      id = kifer_v_intimidate_immune
      if id
        KIFER::ERVersions.splash(self, id)
        @battle.pbDisplay(_INTL("{1}'s {2} was not lowered!", pbThis, GameData::Stat.get(:ATTACK).name))
        KIFER::ERVersions.hide(self)
        return false
      end
      return kifer_v_pbLowerAttackStatStageIntimidate(user)
    end

    # ...and no Scare (Scare lowers Sp. Atk through this method, 008)
    alias kifer_v_pbLowerStatStageByAbility pbLowerStatStageByAbility unless method_defined?(:kifer_v_pbLowerStatStageByAbility)
    def pbLowerStatStageByAbility(stat, increment, user, splashAnim = true, checkContact = false, ability_name = nil)
      if stat == :SPECIAL_ATTACK && user && user.index != @index && ability_name &&
         ability_name == KIFER.ability_name(:SCARE)
        id = kifer_v_intimidate_immune
        if id
          KIFER::ERVersions.splash(self, id)
          @battle.pbDisplay(_INTL("{1}'s {2} was not lowered!", pbThis, GameData::Stat.get(stat).name))
          KIFER::ERVersions.hide(self)
          return false
        end
      end
      return kifer_v_pbLowerStatStageByAbility(stat, increment, user, splashAnim, checkContact, ability_name)
    end

    def kifer_v_intimidate_immune
      return nil if fainted? || !KIFER::ERVersions.on? || @battle.moldBreaker
      KIFER::ERVersions::INTIMIDATE_IMMUNE.each { |id| return id if hasActiveAbility?(id) }
      return nil
    end

    # Heatproof, Flare Boost: no burn damage. Toxic Boost: no poison damage.
    alias kifer_v_pbContinueStatus pbContinueStatus unless method_defined?(:kifer_v_pbContinueStatus)
    def pbContinueStatus(*args, &block)
      if block && KIFER::ERVersions.on?
        return if @status == :BURN && hasActiveAbility?([:HEATPROOF, :FLAREBOOST])
        return if @status == :POISON && hasActiveAbility?(:TOXICBOOST)
      end
      return kifer_v_pbContinueStatus(*args, &block)
    end

    # Slush Rush: no hail damage
    alias kifer_v_takesHailDamage? takesHailDamage? unless method_defined?(:kifer_v_takesHailDamage?)
    def takesHailDamage?
      return false if KIFER::ERVersions.on? && hasActiveAbility?(:SLUSHRUSH)
      return kifer_v_takesHailDamage?
    end

    # Shield Dust: powder moves don't affect it
    alias kifer_v_affectedByPowder? affectedByPowder? unless method_defined?(:kifer_v_affectedByPowder?)
    def affectedByPowder?(showMsg = false)
      if !fainted? && KIFER::ERVersions.on? && hasActiveAbility?(:SHIELDDUST) && !@battle.moldBreaker
        if showMsg
          KIFER::ERVersions.splash(self, :SHIELDDUST)
          @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis))
          KIFER::ERVersions.hide(self)
        end
        return false
      end
      return kifer_v_affectedByPowder?(showMsg)
    end

    # Gluttony: heals 1/3 of its max HP after eating its own berry
    alias kifer_v_pbHeldItemTriggered pbHeldItemTriggered unless method_defined?(:kifer_v_pbHeldItemTriggered)
    def pbHeldItemTriggered(item_to_use, own_item = true, fling = false)
      ret = kifer_v_pbHeldItemTriggered(item_to_use, own_item, fling)
      if own_item && !fling && !fainted? && KIFER::ERVersions.on? &&
         GameData::Item.get(item_to_use).is_berry? && hasActiveAbility?(:GLUTTONY) && canHeal?
        KIFER::ERVersions.splash(self, :GLUTTONY)
        pbRecoverHP(@totalhp / 3)
        @battle.pbDisplay(_INTL("{1}'s HP was restored.", pbThis))
        KIFER::ERVersions.hide(self)
      end
      return ret
    end

    # Truant: loafs only after a turn it chose an attacking move
    alias kifer_v_pbTryUseMove pbTryUseMove unless method_defined?(:kifer_v_pbTryUseMove)
    def pbTryUseMove(choice, move, *args)
      return kifer_v_pbTryUseMove(choice, move, *args) if !KIFER::ERVersions.on? || !hasActiveAbility?(:TRUANT)
      loaf = @effects[PBEffects::Truant] ? true : false
      ret = kifer_v_pbTryUseMove(choice, move, *args)
      if loaf && !@effects[PBEffects::Truant]
        @effects[PBEffects::Truant] = false    # loafed: free next turn
      else
        @effects[PBEffects::Truant] = (move && !move.statusMove?) ? true : false
      end
      return ret
    end

    # Color Change (before the hit), Shield Dust vs powder, Prankster vs Dark types
    alias kifer_v_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget unless method_defined?(:kifer_v_pbSuccessCheckAgainstTarget)
    def pbSuccessCheckAgainstTarget(move, user, target)
      if KIFER::ERVersions.on?
        begin
          if target.hasActiveAbility?(:COLORCHANGE) && !@battle.moldBreaker
            KIFER::ERVersions.color_change(move, user, target)
          end
        rescue StandardError => e
          KIFER.log("Color Change: #{e.class}: #{e.message}")
        end
        # Shield Dust: powder moves (PIF checks powder inline, not with affectedByPowder?)
        if move.powderMove? && target.hasActiveAbility?(:SHIELDDUST) && !target.affectedByPowder?(true)
          return false
        end
        if user.effects[PBEffects::Prankster] && move.statusMove? && target.opposes?(user) &&
           target.pbHasType?(:DARK) && Settings::MECHANICS_GENERATION < 7
          target.damageState.typeMod = move.pbCalcTypeMod(move.calcType, user, target)
          @battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
          return false
        end
      end
      return kifer_v_pbSuccessCheckAgainstTarget(move, user, target)
    end
  end

  class PokeBattle_Battle
    # Shield Dust: entry hazards don't affect it
    alias kifer_v_pbOnActiveOne pbOnActiveOne unless method_defined?(:kifer_v_pbOnActiveOne)
    def pbOnActiveOne(battler)
      if !battler.fainted? && KIFER::ERVersions.on? && battler.hasActiveAbility?(:SHIELDDUST)
        side = battler.pbOwnSide
        if KIFER::ERVersions.hazards?(side)
          saved = KIFER::ERVersions.hazard_values(side)
          KIFER::ERVersions.clear_hazards(side)
          battler.instance_variable_set(:@kifer_v_hazards_cleared, nil)
          begin
            return kifer_v_pbOnActiveOne(battler)
          ensure
            if !battler.instance_variable_get(:@kifer_v_hazards_cleared)   # Pickup cleared them
              KIFER::ERVersions::HAZARDS.each_with_index do |h, i|
                next if !PBEffects.const_defined?(h) || saved[i].nil?
                side.effects[PBEffects.const_get(h)] = saved[i]
              end
            end
          end
        end
      end
      return kifer_v_pbOnActiveOne(battler)
    end

    # Flare Boost: burns itself when fog starts
    alias kifer_v_pbStartWeather pbStartWeather unless method_defined?(:kifer_v_pbStartWeather)
    def pbStartWeather(user, newWeather, *args)
      was = @field.weather
      ret = kifer_v_pbStartWeather(user, newWeather, *args)
      if newWeather == :Fog && was != :Fog && @field.weather == :Fog && KIFER::ERVersions.on?
        eachBattler do |b|
          next if !b.hasActiveAbility?(:FLAREBOOST) || !b.pbCanBurn?(b, false)
          KIFER::ERVersions.splash(b, :FLAREBOOST)
          b.pbBurn(b)
          KIFER::ERVersions.hide(b)
        end
      end
      return ret
    end

    # White Smoke's smoke wears off; Forewarn's marks are dropped when used
    alias kifer_v_pbEndOfRoundPhase pbEndOfRoundPhase unless method_defined?(:kifer_v_pbEndOfRoundPhase)
    def pbEndOfRoundPhase
      ret = kifer_v_pbEndOfRoundPhase
      begin
        s = @kifer_v_smoke
        if s
          [0, 1].each do |i|
            next if s[i] <= 0
            s[i] -= 1
            next if s[i] > 0
            pbDisplay(_INTL("The smoke around {1} faded.", @battlers[i] ? @battlers[i].pbTeam(true) : "the team"))
          end
        end
        f = @kifer_v_forewarn
        if f
          f.keys.each do |idx|
            pos = @positions[idx]
            f.delete(idx) if !pos || pos.effects[PBEffects::FutureSightCounter] <= 0
          end
        end
      rescue StandardError => e
        KIFER.log("ER versions end of round: #{e.class}: #{e.message}")
      end
      return ret
    end
  end

  #=============================================================================
  # Elite Redux 2.65.4.1b text changes
  #=============================================================================
  # Triage: +3 priority for moves that restore HP, drain moves too
  KIFER::ERVersions.wrap(BattleHandlers::PriorityChangeAbility, :TRIAGE) do |ability, battler, move, pri|
    if move.healingMove? || KIFER::ERVersions::DRAIN_FUNCTIONS.include?(KIFER.pif_function(move))
      next pri + 3
    end
    next pri
  end

  # Wonder Skin: no 50% accuracy for status moves; Fort Knox's blocking below
  KIFER::ERVersions.wrap(BattleHandlers::AccuracyCalcTargetAbility, :WONDERSKIN)

  if defined?(KIFER::BatchH)
    class << KIFER::BatchH
      alias kifer_v_fort_knox? fort_knox? unless method_defined?(:kifer_v_fort_knox?)
      def fort_knox?(user, target)
        return true if kifer_v_fort_knox?(user, target)
        return false if !user || !target || user.equal?(target) || !KIFER::ERVersions.on?
        return false unless target.respond_to?(:opposes?) && target.opposes?(user)
        return false if target.battle.moldBreaker
        return KIFER::BatchH.has?(target, :WONDERSKIN)
      end
    end
  end

  # Oblivious: gaining it cures infatuation, Taunt, Disable, Encore, Torment
  KIFER::ERVersions.wrap(BattleHandlers::StatusCureAbility, :OBLIVIOUS) do |ability, battler|
    e = battler.effects
    attract = e[PBEffects::Attract] >= 0
    taunt   = e[PBEffects::Taunt] > 0
    disable = e[PBEffects::Disable] > 0
    encore  = e[PBEffects::Encore] > 0
    torment = e[PBEffects::Torment]
    next if !attract && !taunt && !disable && !encore && !torment
    battle = battler.battle
    KIFER::ERVersions.splash(battler, ability)
    if attract
      battler.pbCureAttract
      battle.pbDisplay(_INTL("{1} got over its infatuation.", battler.pbThis))
    end
    if taunt
      e[PBEffects::Taunt] = 0
      battle.pbDisplay(_INTL("{1}'s Taunt wore off!", battler.pbThis))
    end
    if disable
      e[PBEffects::Disable]     = 0
      e[PBEffects::DisableMove] = nil
      battle.pbDisplay(_INTL("{1} is no longer disabled!", battler.pbThis))
    end
    if encore
      e[PBEffects::Encore]     = 0
      e[PBEffects::EncoreMove] = nil
      battle.pbDisplay(_INTL("{1}'s encore ended!", battler.pbThis))
    end
    if torment
      e[PBEffects::Torment] = false
      battle.pbDisplay(_INTL("{1} is no longer tormented!", battler.pbThis))
    end
    KIFER::ERVersions.hide(battler)
  end

  # Oblivious: Disable, Encore and Torment fail on it (Taunt: TAUNT_IMMUNE)
  { "0B7" => "Torment", "0B9" => "Disable", "0BC" => "Encore" }.each_key do |code|
    cls = "PokeBattle_Move_#{code}"
    next if !Object.const_defined?(cls)
    Object.const_get(cls).class_eval do
      alias_method :kifer_v_obl_pbFailsAgainstTarget?, :pbFailsAgainstTarget? unless method_defined?(:kifer_v_obl_pbFailsAgainstTarget?)
      define_method(:pbFailsAgainstTarget?) do |user, target|
        if KIFER::ERVersions.on? && !@battle.moldBreaker && target.hasActiveAbility?(:OBLIVIOUS)
          KIFER::ERVersions.splash(target, :OBLIVIOUS)
          @battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
          KIFER::ERVersions.hide(target)
          next true
        end
        next kifer_v_obl_pbFailsAgainstTarget?(user, target)
      end
    end
  end

  # Aftermath: KO'd by an attack -> Explosion / Outburst once the attack is
  # over (no more 1/4 HP damage on contact)
  KIFER::ERVersions.wrap(BattleHandlers::TargetAbilityOnHit, :AFTERMATH) do |ability, user, target, move, battle|
    next if !target.fainted? || !user || user.index == target.index || !move.damagingMove?
    KIFER::ERVersions.aftermath_queue(battle, target, ability)
  end

  class PokeBattle_Move
    # Aftermath: its explosion moves always flinch
    alias kifer_v_pbFlinchChance pbFlinchChance unless method_defined?(:kifer_v_pbFlinchChance)
    def pbFlinchChance(user, target)
      ret = kifer_v_pbFlinchChance(user, target)
      if ret < 100 && KIFER::ERVersions.on? && KIFER::ERVersions.explosion_move?(self) &&
         user.hasActiveAbility?(:AFTERMATH) &&
         !(target.hasActiveAbility?(:SHIELDDUST) && !@battle.moldBreaker)
        ret = 100
      end
      return ret
    end
  end

  class PokeBattle_Battler
    # Aftermath: the explosion comes after the attack that KO'd it
    alias kifer_v_pbUseMove pbUseMove unless method_defined?(:kifer_v_pbUseMove)
    def pbUseMove(choice, specialUsage = false)
      depth = @battle.instance_variable_get(:@kifer_v_usedepth) || 0
      @battle.instance_variable_set(:@kifer_v_usedepth, depth + 1)
      begin
        kifer_v_pbUseMove(choice, specialUsage)
      ensure
        @battle.instance_variable_set(:@kifer_v_usedepth, depth)
      end
      KIFER::ERVersions.aftermath_run(@battle) if depth == 0
    end
  end

  #=============================================================================
  # Descriptions: ER's text while the setting is Elite Redux
  #=============================================================================
  module GameData
    class Ability
      alias kifer_v_description description unless method_defined?(:kifer_v_description)
      def description
        if !@kifer_er && KIFER::ERVersions::CHANGED.include?(@id) && KIFER::ERVersions.on?
          t = KIFER::ABILITY_TEXT[@id]
          return t[:short] if t && t[:short] && !t[:short].empty?
        end
        return kifer_v_description
      end
    end
  end
end
