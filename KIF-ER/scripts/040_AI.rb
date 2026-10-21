#===============================================================================
# KIF: Elite Redux – the trainers' battle AI knows the Elite Redux mechanics of 030-036
#   KIF's trainers use DemICE's AI, or PIF's own when Options > Battles >
#   Battle AI is PIF. KIF sends each AI method to whichever AI is in charge, so
#   the hooks below sit on those shared methods and both AIs get them. Nothing
#   changes unless the mechanic is in play (a status on a Pokemon, Inverse Room
#   up, fog, Toxic Terrain...) or, for things the abilities cause, unless the
#   "New battle effects" setting is On.
#
#   Damage estimate (pbRoughDamage, used for every move and switch choice):
#     - frostbitten attacker: its special moves do half (not with Guts or
#       Determination)
#     - afraid target: x1.5
#     - bleeding attacker or target: its stat stages count as 0 (also in
#       pbRoughStat)
#     - ER infatuation: x0.5 against the Pokemon it is in love with
#     - fog: Ghost and Psychic targets x0.8, Ominous Wind x2
#     - Toxic Terrain: a grounded attacker's Poison moves x1.3
#   Type matchups: reversed while Inverse Room is up, as 034 does it (move
#     choice, immunities, and switch-ins: pbCalcTypeModSingle,
#     pbCalcTypeModPokemon and PIF's own switch-in choice)
#   Move scores:
#     - moves that frostbite (Ice Beam and the like; Frost Breath while the
#       setting is On) are valued like burn: more against a special attacker,
#       less against Guts / Quick Feet / Marvel Scale, Lum or Aspear Berry,
#       Hydration in rain. Nothing on Ice types or a Pokemon with a status.
#     - fear, bleeding and frostbite from the attacker's abilities (Grass
#       Flute, Fearmonger, Spectralize, Deep Cuts, Mineralize, Freezing Point)
#       add to the move by their chance, only if the target can get it and
#       survives the hit. Fear is worth half as much again when the target
#       would want to switch out (fear traps it): it has a Pokemon to switch
#       to, nothing else traps it, and the attacker out-damages it (share of
#       HP). Neither AI values trapping moves (Mean Look...) by matchup, so
#       this is the mod's own rule.
#     - a bleeding Pokemon's healing moves only cure its bleeding: they are
#       scored as a cure, not a heal. Its stat-raising moves are worth little
#       while it bleeds (stages count as 0), as are stat-lowering moves on a
#       bleeding target.
#     - a bleeding Pokemon's drain moves (Giga Drain, Drain Punch, Draining
#       Kiss, Dream Eater...) lose the bonus both AIs give them for healing
#       (DemICE's bonus for a knockout with a drain move too); penalties
#       (Liquid Ooze, a target that isn't asleep) stay. Its Strength Sap is
#       worth no more than Growl (an Attack drop, no heal).
#     - in fog, stat-raising moves of a Pokemon that isn't Ghost or Psychic
#       are worth half (fog takes 1 off each raised stat every turn end)
#     - Refresh cures frostbite (not bleeding); Psycho Shift is bad if the
#       target can't get the user's new status
#     - Swagger / Flatter while enrage is On: bad on a target that is already
#       enraged (it fails, or only raises the foe's stat)
#     - thawing moves: a little better for a frostbitten user (cures it), a
#       little worse on a frostbitten target (cures the target)
#     - an enraged attacker avoids an attack whose recoil would knock it out
#       without knocking out the target
#   End-of-turn HP (DemICE's EndofTurnHPChanges): frostbite and bleeding 1/16,
#     Toxic Terrain 1/16, no healing while bleeding
#   Items: no HP-only item (Potion...) on a bleeding Pokemon. DemICE's AI
#     cures frostbite (Ice Heal, Aspear Berry, then Full Heal-type items and
#     Full Restore) and bleeding (Full Heal-type items, Full Restore) the way
#     it cures a burn: same score, and not when the status helps it (Guts with
#     a physical move, Quick Feet, Marvel Scale), when frostbite costs it
#     nothing (no special move) or it can cure itself (a thawing move for
#     frostbite, a healing move for bleeding), or with Natural Cure for
#     bleeding. PIF's own AI only ever uses HP items, so nothing changes there.
#   Switching: an afraid Pokemon doesn't try to switch (fear traps it). The AI
#     switches out an enraged Pokemon whose best attack would cost it half its
#     HP or more without a knockout, and a bleeding Pokemon with Natural Cure
#     (bleeding stays when switching otherwise, so that wouldn't help). It
#     still only switches when the AI finds a better Pokemon to send in. In
#     doubles that switch (DemICE) never picks the Pokemon the ally already
#     chose to send in.
#   Turn order: a drenched Pokemon (031) moves after the others at equal
#     priority (both drenched: Speed and Trick Room as usual). Both AIs guess
#     the order from pbRoughStat Speeds, so a drenched Pokemon's Speed is put
#     below the others' there (Gyro Ball's and Electro Ball's power keep the
#     real one). Hydrate's drench chance isn't scored.
#   Choosing a switch-in: each Pokemon is judged in the field it would make
#     on entry: Inversion -> Inverse Room, Low Visibility -> fog, Toxic Surge
#     -> Toxic Terrain (only while the setting is On and the field isn't
#     already like that). A Pokemon that would lose HP to Toxic Terrain
#     (grounded, not Poison or Steel, no Magic Guard...) counts it: DemICE
#     judges it with 1/16 less HP, PIF's choice counts its score x15/16.
#     PIF's choice (type matchups only) also counts fog (x0.8 into Ghost and
#     Psychic foes, Ominous Wind x2) and Toxic Terrain (Poison moves x1.3).
#   KIF's own frostbite (Battles > Frostbite, which 036 turns on while ER's
#     frostbite is on): a Frozen Pokemon acts and is hurt like a frostbitten
#     one, so both AIs see a Frozen Pokemon as frostbitten while they decide
#     (not as unable to move: no "thaw it at all costs" or "free turns").
#===============================================================================
module KIFER
  module AI
    STATUS_VALUE = 30      # what a burn or poison is worth to the AI
    CURE_VALUE   = 30      # curing its own bleeding (like Refresh on poison)
    FEAR_TRAP_BONUS = 0.5  # fear on a target that wants to switch: x1.5
    HP_ITEMS = [:POTION, :SUPERPOTION, :HYPERPOTION, :MAXPOTION, :BERRYJUICE,
                :SWEETHEART, :FRESHWATER, :SODAPOP, :LEMONADE, :MOOMOOMILK,
                :ORANBERRY, :SITRUSBERRY, :ENERGYPOWDER, :ENERGYROOT]
    # DemICE's status curers, in the order it prefers them
    FROSTBITE_ITEMS = [:ICEHEAL, :ASPEARBERRY]
    ALL_STATUS_ITEMS = [:FULLHEAL, :LAVACOOKIE, :OLDGATEAU, :CASTELIACONE, :LUMIOSEGALETTE,
                        :SHALOURSABLE, :BIGMALASADA, :LUMBERRY, :HEALPOWDER, :FULLRESTORE]
    FROSTBITE_FUNCS = ["00C", "00D", "00E"]
    DRAIN_FUNCS = ["0DD", "0DE", "14F"]   # Giga Drain..., Dream Eater, Draining Kiss...
    STRENGTH_SAP = "160"
    # Status moves that raise the user's stats / lower the target's
    SETUP_FUNCS = (0x1C..0x3A).map { |n| format("%03X", n) } - ["023", "037"] + ["112", "137"]
    LOWER_FUNCS = (0x42..0x4F).map { |n| format("%03X", n) } - ["049"] + ["13A"]   # not Defog (hazard clearing)
    NO_RECOIL = [:MAGICGUARD, :ROCKHEAD, :STEELBARREL, :BRUTEFORCE]
    FOG_PRIMAL = [:HarshSun, :HeavyRain, :StrongWinds]
    # abilities whose hits add fear, bleeding or frostbite (added_status_value)
    STATUS_ON_HIT = [:GRASSFLUTE, :FEARMONGER, :SPECTRALIZE, :DEEPCUTS, :MINERALIZE, :FREEZINGPOINT]

    @sim = nil            # field a switch-in being judged would make
    @switch_depth = 0
    @fview = false        # Frozen shown as frostbitten (KIF's frostbite)
    @raw_speed = false    # a move's power from Speed (Gyro Ball...): no Drench band
    DRENCH_BAND = 1_000_000

    module_function

    #---------------------------------------------------------------------------
    # Which mechanics exist / are in play
    #---------------------------------------------------------------------------
    # DemICE's AI is the one in charge (its function scores are relative)
    def demice_on?
      return false unless defined?(KIF::PowerfulAI) && KIF::PowerfulAI.respond_to?(:on?)
      return false unless PokeBattle_AI.method_defined?(:kif_demice_pbGetMoveScoreFunctionCode)
      return KIF::PowerfulAI.on?
    end

    # The field a switch-in being judged would make (nil: none)
    def sim_for(battle)
      s = @sim
      return (s && battle && s[:battle].equal?(battle)) ? s : nil
    end

    def inverse?(battle)
      return false unless battle && defined?(KIFER::Specials1) &&
                          KIFER::Specials1.respond_to?(:inverse_room?)
      return true if KIFER::Specials1.inverse_room?(battle)
      s = sim_for(battle)
      return s ? s[:inverse] == true : false
    end

    def afraid?(b)
      return defined?(KIFER::Fear) && b.respond_to?(:kifer_fear) && KIFER::Fear.afraid?(b)
    end

    def enraged?(b)
      return defined?(KIFER::TerrainEnrage) && KIFER::TerrainEnrage.enraged?(b)
    end

    def bleeding?(b)
      return b && b.respond_to?(:status) && b.status == :BLEEDING
    end

    def frostbitten?(b)
      return b && b.respond_to?(:status) && b.status == :FROSTBITE
    end

    # ER's frostbite itself (not a Frozen Pokemon shown as frostbitten)
    def er_frostbite?(b)
      return frostbitten?(b) && b.respond_to?(:pokemon) && b.pokemon &&
             b.pokemon.status == :FROSTBITE
    end

    def drenched?(b)
      return defined?(KIFER::Drench) && b.respond_to?(:kifer_drench) && KIFER::Drench.drenched?(b)
    end

    # Speed for both AIs' turn-order guesses (every "who moves first" check
    # compares pbRoughStat Speeds): a drenched Pokemon moves after the
    # undrenched ones at equal priority, so its Speed goes below all of theirs
    # (above, for DemICE under Trick Room, which it flips); the drenched keep
    # their order among themselves
    def order_speed(b, speed)
      return speed if @raw_speed || !speed.is_a?(Numeric) || !drenched?(b)
      return speed + DRENCH_BAND if demice_on? && b.battle.field.effects[PBEffects::TrickRoom] > 0
      return speed / DRENCH_BAND.to_f
    end

    def raw_speed
      old = @raw_speed
      @raw_speed = true
      begin
        return yield
      ensure
        @raw_speed = old
      end
    end

    def er_love?(user, target)
      return defined?(KIFER::Specials2) && KIFER::Specials2.respond_to?(:er_love_with?) &&
             KIFER::Specials2.er_love_with?(user, target)
    end

    def fog?(battle)
      return false unless defined?(KIFER::Fog)
      return true if KIFER::Fog.active?(battle)
      s = sim_for(battle)
      return s ? s[:fog] == true : false
    end

    def toxic_terrain?(battle)
      return false unless defined?(KIFER::TerrainEnrage)
      return true if KIFER::TerrainEnrage.toxic_terrain?(battle)
      s = sim_for(battle)
      return s ? s[:toxic] == true : false
    end

    # 033's, for the real or would-be terrain
    def toxic_affected?(b)
      return !!b && KIFER::TerrainEnrage.toxic_affected?(b, toxic_terrain?(b.battle))
    end

    def toxic_chip?(b)
      return !!b && KIFER::TerrainEnrage.toxic_chip?(b, toxic_terrain?(b.battle))
    end

    def feature?(id)
      return KIFER.respond_to?(:feature_on?) && KIFER.feature_on?(id)
    end

    # KIF's own frostbite (Frozen acts as frostbitten); 036 forces it on while
    # ER's frostbite is on
    def kif_frostbite?
      return false unless defined?(KIF::Mechanics) && KIF::Mechanics.respond_to?(:frostbite?)
      on = KIF::Mechanics.respond_to?(:frostbite_in_battle?) ? KIF::Mechanics.frostbite_in_battle? : KIF::Mechanics.frostbite?
      return on ? true : false
    end

    def stageless(battlers)
      return yield unless defined?(KIFER::Statuses) && KIFER::Statuses.respond_to?(:without_stages)
      return yield unless battlers.any? { |b| bleeding?(b) && b.respond_to?(:stages) }
      return KIFER::Statuses.without_stages(battlers.compact) { yield }
    end

    def recoil_hurts?(b)
      return false if b.hasActiveAbility?(NO_RECOIL)
      return b.takesIndirectDamage?
    end

    # Its healing move would only cure its bleeding (031's hook on that move)
    def bleed_cure_move?(move, user)
      return false unless bleeding?(user) && move.healingMove?
      t = move.pbTarget(user)
      return false unless t && [:User, :UserAndAllies].include?(t.id)
      owner = move.method(:pbMoveFailed?).owner
      return owner.method_defined?(:"kifer_st_mf_#{owner.name}")
    end

    def setup_move?(move)
      return move.statusMove? && SETUP_FUNCS.include?(move.function)
    end

    def lower_move?(move)
      return move.statusMove? && LOWER_FUNCS.include?(move.function)
    end

    # Its strongest attack on foe is special
    def special_attacker?(ai, b, foe)
      if foe && ai.respond_to?(:bestMoveVsTarget)
        best = ai.bestMoveVsTarget(b, foe, 100)
        return best[3] == "special" if best && best[1]
      end
      phys = 0; spec = 0
      b.eachMove do |m|
        next if !m.damagingMove?
        if m.specialMove?
          spec = m.baseDamage if m.baseDamage > spec
        else
          phys = m.baseDamage if m.baseDamage > phys
        end
      end
      return spec > phys
    end

    def rough_damage(ai, move, user, target)
      return 0 if !move.damagingMove?
      base = ai.pbMoveBaseDamage(move, user, target, 100)
      dmg = ai.pbRoughDamage(move, user, target, 100, base)
      dmg = 0 if ai.pbCheckMoveImmunity(1, move, user, target, 100)
      return dmg
    end

    def best_damage(ai, user, target)
      best = 0
      user.eachMove { |m| d = rough_damage(ai, m, user, target); best = d if d > best }
      return best
    end

    #---------------------------------------------------------------------------
    # KIF's frostbite: Frozen Pokemon are shown to the AI as frostbitten
    # while it decides (their status is put back afterwards). The outermost
    # AI scope: Neutralizing Gas is worked out once in it too.
    #---------------------------------------------------------------------------
    def frozen_view(battle)
      return yield if @fview || !battle || !battle.respond_to?(:battlers)
      list = kif_frostbite? ? battle.battlers.select { |b| b && b.status == :FROZEN } : []
      @fview = true
      list.each { |b| b.instance_variable_set(:@status, :FROSTBITE) }
      begin
        return KIFER::Specials1.gas_fixed(battle) { yield }
      ensure
        list.each do |b|
          b.instance_variable_set(:@status, :FROZEN) if b.instance_variable_get(:@status) == :FROSTBITE
        end
        @fview = false
      end
    end

    #---------------------------------------------------------------------------
    # Switch-ins: the field each one would make on entry
    #---------------------------------------------------------------------------
    def switch_scope
      saved = @sim
      @switch_depth += 1
      begin
        return yield
      ensure
        @switch_depth -= 1
        @sim = saved
      end
    end

    def would_invert?(battle, has)
      return false unless defined?(KIFER::Specials1) && KIFER::Specials1.respond_to?(:inverse_room?)
      return feature?(:inverse_room) && has.call(:INVERSION) && !KIFER::Specials1.inverse_room?(battle)
    end

    def would_fog?(battle, has)
      return false unless defined?(KIFER::Fog)
      w = battle.field.weather
      return feature?(:fog) && has.call(:LOWVISIBILITY) && w != :Fog && !FOG_PRIMAL.include?(w)
    end

    def would_toxic?(battle, has)
      return false unless defined?(KIFER::TerrainEnrage)
      return feature?(:toxic_terrain) && has.call(:TOXICSURGE) && battle.field.terrain != :Toxic
    end

    # DemICE made a stand-in battler for a Pokemon it may send in
    def switch_candidate(battle, fake)
      return if !fake
      if kif_frostbite? && fake.status == :FROZEN
        fake.instance_variable_set(:@status, :FROSTBITE)   # a stand-in, never put back
      end
      return if @switch_depth <= 0
      # DemICE also scores the Pokemon already in battle ("stay"): no entry costs
      return if battle.battlers.any? { |b| b && !b.equal?(fake) && b.pokemon.equal?(fake.pokemon) }
      has = proc { |id| fake.hasActiveAbility?(id) }
      s = { :battle => battle, :inverse => would_invert?(battle, has),
            :fog => would_fog?(battle, has), :toxic => would_toxic?(battle, has) }
      @sim = (s[:inverse] || s[:fog] || s[:toxic]) ? s : nil
      # Toxic Terrain chip: judged with 1/16 less HP (the stand-in only)
      if toxic_chip?(fake) && fake.hp > 1
        fake.instance_variable_set(:@hp, [fake.hp - fake.totalhp / 16, 1].max)
      end
      # Creeping Thorns: the same, with what the thorns would take on entry
      if defined?(KIFER::MoveFxField) && fake.hp > 1 && fake.takesIndirectDamage?
        loss = KIFER::MoveFxField.thorns_loss(fake.pbOwnSide, fake.pbTypes(true), fake.totalhp)
        fake.instance_variable_set(:@hp, [fake.hp - loss, 1].max) if loss > 0
      end
    rescue StandardError => e
      @sim = nil
      KIFER.log("AI switch-in field: #{e.class}: #{e.message}")
    end

    def pkmn_field(battle, pkmn)
      has = proc { |id| KIFER::AIInnates.abil?(pkmn, id) }
      return { :inverse => inverse?(battle) || would_invert?(battle, has),
               :fog => fog?(battle) || would_fog?(battle, has),
               :toxic => toxic_terrain?(battle) || would_toxic?(battle, has) }
    end

    def pkmn_toxic_affected?(pkmn)
      return true if KIFER::AIInnates.abil?(pkmn, :TOXICSURGE)
      return false if pkmn.hasType?(:FLYING) || KIFER::AIInnates.abil?(pkmn, :LEVITATE)
      return pkmn.item_id != :AIRBALLOON
    end

    def pkmn_toxic_chip?(pkmn)
      return false if !pkmn_toxic_affected?(pkmn)
      return false if pkmn.hasType?(:POISON) || pkmn.hasType?(:STEEL)
      return false if KIFER::AIInnates.abil?(pkmn, :MAGICGUARD)
      return !KIFER::TerrainEnrage::NO_TOXIC_CHIP.any? { |a| KIFER::AIInnates.abil?(pkmn, a) }
    end

    # Something PIF's choice doesn't know about is in play
    def pif_switch_changed?(battle, party, enemies, idxBattler = nil)
      return false if !enemies || enemies.empty?
      return true if inverse?(battle) || fog?(battle) || toxic_terrain?(battle)
      return true if idxBattler && thorns_side(battle, idxBattler)
      return enemies.any? do |i|
        f = pkmn_field(battle, party[i])
        f[:inverse] || f[:fog] || f[:toxic]
      end
    end

    # PIF's switch-in score (type matchups of its moves) in the field it makes
    def pif_switch_sum(battle, idxBattler, pkmn)
      f = pkmn_field(battle, pkmn)
      sum = 0
      pkmn.moves.each do |m|
        next if m.base_damage == 0
        battle.battlers[idxBattler].eachOpposing do |b|
          bt = b.pbTypes(true)
          e = f[:inverse] ? inverse_calc(m.type, bt[0], bt[1], bt[2]) :
                            Effectiveness.calculate(m.type, bt[0], bt[1], bt[2])
          if f[:fog]
            e *= 0.8 if KIFER::Fog.spectral?(b)
            e *= 2 if m.id == :OMINOUSWIND
          end
          e *= 1.3 if f[:toxic] && m.type == :POISON && pkmn_toxic_affected?(pkmn)
          sum += e
        end
      end
      sum *= 15 / 16.0 if f[:toxic] && pkmn_toxic_chip?(pkmn)
      side = thorns_side(battle, idxBattler)
      if side && !KIFER::AIInnates.abil?(pkmn, :MAGICGUARD) && pkmn.hp > 0
        loss = KIFER::MoveFxField.thorns_loss(side, pkmn.types, pkmn.totalhp)
        sum = loss >= pkmn.hp ? 0 : sum * (pkmn.hp - loss) / pkmn.hp.to_f
      end
      return sum
    end

    # The AI's own side, when Creeping Thorns are on it
    def thorns_side(battle, idxBattler)
      return nil if !defined?(KIFER::MoveFxField) || !battle.battlers[idxBattler]
      return nil if KIFER::MoveFxField.magic_room?(battle)   # no indirect damage
      side = battle.battlers[idxBattler].pbOwnSide
      return KIFER::MoveFxField.thorns?(side) ? side : nil
    end

    # PIF's own switch-in choice, with the field each would make
    def pif_best_new_enemy(battle, idxBattler, party, enemies)
      return -1 if !enemies || enemies.length == 0
      best = -1; bestSum = 0
      enemies.each do |i|
        sum = pif_switch_sum(battle, idxBattler, party[i])
        if best == -1 || sum > bestSum
          best = i
          bestSum = sum
        end
      end
      return best
    end

    #---------------------------------------------------------------------------
    # Inverse Room type matchups
    #---------------------------------------------------------------------------
    def inverse_one(atk, defType)
      return KIFER::Specials1.invert(Effectiveness.calculate_one(atk, defType))
    end

    # Effectiveness.calculate with the reversed chart
    def inverse_calc(atk, t1, t2 = nil, t3 = nil)
      mods = [Effectiveness::NORMAL_EFFECTIVE_ONE] * 3
      mods[0] = inverse_one(atk, t1)
      mods[1] = inverse_one(atk, t2) if t2 && t2 != t1
      mods[2] = inverse_one(atk, t3) if t3 && t3 != t1 && t3 != t2
      return mods[0] * mods[1] * mods[2]
    end

    # PIF's pbCalcTypeModPokemon with the reversed chart
    def inverse_type_mod_pokemon(this, target)
      mod1 = inverse_calc(this.type1, target.type1, target.type2)
      mod2 = Effectiveness::NORMAL_EFFECTIVE
      if this.type1 != this.type2
        mod2 = inverse_calc(this.type2, target.type1, target.type2)
        mod2 = mod2.to_f / Effectiveness::NORMAL_EFFECTIVE
      end
      return mod1 * mod2
    end

    #---------------------------------------------------------------------------
    # Damage estimate
    #---------------------------------------------------------------------------
    def damage_mult(ai, move, user, target, skill)
      m = 1.0
      type = nil
      if frostbitten?(user) && !user.hasActiveAbility?([:GUTS, :DETERMINATION])
        type = ai.pbRoughType(move, user, skill || 100)
        m *= 0.5 if move.specialMove?(type)
      end
      m *= 1.5 if afraid?(target)
      m *= 0.5 if er_love?(user, target)
      if fog?(user.battle)
        m *= 2 if move.id == :OMINOUSWIND
        m *= 0.8 if KIFER::Fog.spectral?(target)
      end
      if toxic_affected?(user)
        type ||= ai.pbRoughType(move, user, skill || 100)
        m *= 1.3 if type == :POISON
      end
      return m
    end

    def adjust_damage(ai, dmg, move, user, target, skill)
      return dmg if !dmg.is_a?(Numeric) || dmg <= 0 || !user || !target
      return dmg if move.is_a?(PokeBattle_FixedDamageMove)
      m = damage_mult(ai, move, user, target, skill)
      return dmg if m == 1.0
      return [(dmg * m).floor, 1].max
    rescue StandardError => e
      KIFER.log("AI damage: #{e.class}: #{e.message}")
      return dmg
    end

    #---------------------------------------------------------------------------
    # Move-effect scores (pbGetMoveScoreFunctionCode). abs is the score as
    # PIF's AI keeps it; DemICE's answer is relative to the starting score.
    #---------------------------------------------------------------------------
    def frostbite_extra(ai, move, user, target)
      return 0 if !target.pbCanFrostbite?(user, false, move)
      d = 0
      if move.id == :FROSTBREATH   # PIF gives it nothing for a status
        d += 30
        d -= 20 if target.hasActiveAbility?(:MARVELSCALE)
      end
      d += 80 if target.hasActiveAbility?(:WONDERGUARD)
      d += 30 if special_attacker?(ai, target, user)
      d -= 50 if target.hasActiveItem?([:LUMBERRY, :ASPEARBERRY])
      d -= 140 if target.hasActiveAbility?([:GUTS, :QUICKFEET, :MARVELSCALE])
      d -= 200 if target.hasActiveAbility?(:HYDRATION) && [:Rain, :HeavyRain].include?(user.battle.pbWeather)
      return d
    end

    def cure_value(user)
      v = CURE_VALUE
      GameData::Stat.each_battle { |s| v += 10 * user.stages[s.id] if user.stages[s.id] > 0 }
      return [v, 90].min
    end

    # Strength Sap of a bleeding user: what Growl (an Attack drop) is worth
    def sap_as_attack_drop(ai, score, move, user, target, skill)
      return nil if move.function != STRENGTH_SAP || !bleeding?(user) || !target
      growl = PokeBattle_Move.from_pokemon_move(user.battle, Pokemon::Move.new(:GROWL))
      return ai.kifer_ai_pbGetMoveScoreFunctionCode(score, growl, user, target, skill)
    rescue StandardError => e
      KIFER.log("AI Strength Sap: #{e.class}: #{e.message}")
      return nil
    end

    def adjust_function(ai, ret, score, move, user, target)
      return ret if !ret.is_a?(Numeric)
      rel = demice_on?
      abs = rel ? score + ret : ret
      f = KIFER.pif_function(move)
      if bleed_cure_move?(move, user)
        abs = score + cure_value(user)
      elsif DRAIN_FUNCS.include?(f) && bleeding?(user)       # drains don't heal
        abs = score + [abs - score, 0].min
      elsif f == "018" && er_frostbite?(user)                 # Refresh
        abs = score + 40
        abs += 20 if special_attacker?(ai, user, user.pbDirectOpposing(true))
      elsif f == "01B" && defined?(KIFER::Statuses) &&      # Psycho Shift
            KIFER::Statuses.ours?(user.status) && target && !user.equal?(target)
        abs = score - 90 if !target.pbCanInflictStatus?(user.status, user, false, move)
      elsif ["040", "041"].include?(f) && feature?(:enrage) && target   # Flatter, Swagger
        if enraged?(target) || (target.effects[PBEffects::Substitute] > 0 && !move.ignoresSubstitute?(user))
          abs = score - 90
        else
          abs = score
          if f == "040"
            abs += 30 if target.stages[:SPECIAL_ATTACK] < 0
          else
            abs += 30 if target.stages[:ATTACK] < 0
            abs += 40 if user.hasActiveAbility?(:PRANKSTER)
            abs += 30 if user.pbHasMove?(:FOULPLAY)
          end
          abs += 20 if recoil_hurts?(target)
        end
      elsif (FROSTBITE_FUNCS.include?(f) || move.id == :FROSTBREATH) && feature?(:frostbite) &&
            target && !user.equal?(target)
        abs += frostbite_extra(ai, move, user, target)
      else
        return ret
      end
      return rel ? abs - score : abs
    rescue StandardError => e
      KIFER.log("AI move effect score: #{e.class}: #{e.message}")
      return ret
    end

    # DemICE's damage score: a knockout with a drain move gets a bonus for
    # the HP it would heal; none while the user bleeds
    def adjust_damage_score(ai, ret, move, user, target)
      return ret if !ret.is_a?(Numeric) || ret <= 0 || !demice_on? || !bleeding?(user) || !target
      f = KIFER.pif_function(move)
      return ret unless ["0DD", "14F"].include?(f) || (f == "0DE" && target.asleep?)
      return ret if target.hasActiveAbility?(:LIQUIDOOZE)
      dmg = ai.pbRoughDamage(move, user, target, 100)
      return ret if dmg * 100.0 / target.hp <= 100
      return ret - (user.totalhp - user.hp) * 100.0 / user.totalhp * 0.5
    rescue StandardError => e
      KIFER.log("AI drain damage score: #{e.class}: #{e.message}")
      return ret
    end

    #---------------------------------------------------------------------------
    # Final move score (pbGetMoveScore)
    #---------------------------------------------------------------------------
    # The target would want to switch out, and fear would stop it
    def foe_wants_out?(ai, user, target)
      battle = target.battle
      return false if !battle.pbCanChooseNonActive?(target.index)
      return false if target.effects[PBEffects::Trapping] > 0 || target.effects[PBEffects::MeanLook] >= 0
      return false if target.effects[PBEffects::Ingrain]
      return false if KIFER::Fear.escapes?(target, battle)
      return false if target.hp <= 0 || user.hp <= 0
      mine   = best_damage(ai, user, target) / target.hp.to_f
      theirs = best_damage(ai, target, user) / user.hp.to_f
      return mine > theirs
    end

    # Fear / bleeding / frostbite its abilities may add to this attack
    def added_status_value(ai, move, user, target)
      return 0 if !feature?(:fear) || user.equal?(target) || !user.opposes?(target)   # one setting for all
      return 0 if !user.hasActiveAbility?(STATUS_ON_HIT)
      return 0 if target.hasActiveAbility?(:SHIELDDUST) && !user.battle.moldBreaker
      type = move.pbCalcType(user)
      contact = move.pbContactMove?(user)
      v = 0
      if defined?(KIFER::Fear) && KIFER::Fear.can_fear?(target)
        ch = 0
        ch = 100 if user.hasActiveAbility?(:GRASSFLUTE) && move.soundMove?
        ch = [ch, 10].max if user.hasActiveAbility?(:FEARMONGER) && contact
        ch = [ch, 10].max if user.hasActiveAbility?(:SPECTRALIZE) && type == :GHOST && user.pbHasType?(:GHOST)
        if ch > 0
          fv = STATUS_VALUE * ch / 100.0
          fv *= 1 + FEAR_TRAP_BONUS if foe_wants_out?(ai, user, target)
          v += fv
        end
      end
      if target.status == :NONE && target.respond_to?(:pbCanBleed?) && target.pbCanBleed?(user, false, move)
        ch = 0
        ch = 50 if user.hasActiveAbility?(:DEEPCUTS) && defined?(KIFER::SLICING_MOVES) &&
                   KIFER::SLICING_MOVES.include?(move.id)
        ch = [ch, 10].max if user.hasActiveAbility?(:MINERALIZE) && type == :ROCK && user.pbHasType?(:ROCK)
        v += STATUS_VALUE * ch / 100.0
      end
      if target.status == :NONE && target.respond_to?(:pbCanFrostbite?) &&
         user.hasActiveAbility?(:FREEZINGPOINT) && target.pbCanFrostbite?(user, false)
        v += STATUS_VALUE * (contact ? 20 : 30) / 100.0
      end
      return v
    end

    def adjust_score(ai, score, move, user, target)
      return score if !score.is_a?(Numeric) || score <= 0 || !target
      s = score.to_f
      if move.statusMove?
        s *= 0.25 if bleeding?(user) && setup_move?(move)
        s *= 0.25 if bleeding?(target) && lower_move?(move) && user.opposes?(target)
        # fog takes 1 off each raised stat at the end of every turn
        s *= 0.5 if setup_move?(move) && fog?(user.battle) && !KIFER::Fog.spectral?(user)
      else
        dmg = nil
        add = added_status_value(ai, move, user, target)
        if add > 0
          dmg = rough_damage(ai, move, user, target)
          s += add if dmg > 0 && dmg < target.hp
        end
        if move.thawsUser?
          s *= 1.1 if frostbitten?(user)
          s *= 0.9 if frostbitten?(target) && user.opposes?(target)
        end
        if enraged?(user) && recoil_hurts?(user) && user.opposes?(target)
          dmg ||= rough_damage(ai, move, user, target)
          recoil = [dmg, target.hp].min / 3
          s *= 0.5 if dmg > 0 && dmg < target.hp && recoil >= user.hp
        end
      end
      return score if s == score
      return score.is_a?(Integer) ? s.round : s
    rescue StandardError => e
      KIFER.log("AI move score: #{e.class}: #{e.message}")
      return score
    end

    #---------------------------------------------------------------------------
    # End-of-turn HP (DemICE): fraction of max HP gained (heal) / lost (chips)
    #---------------------------------------------------------------------------
    # ER versions (050): Rain Dish / Ice Body heal 1/8, not 1/16
    def er_heal_extra(user)
      return 0.0 if !defined?(KIFER::ERVersions) || !KIFER::ERVersions.on?
      return 0.0 if user.effects[PBEffects::HealBlock] > 0
      w = user.battle.pbWeather
      return 0.0625 if (user.hasActiveAbility?(:RAINDISH) && [:Rain, :HeavyRain].include?(w)) ||
                       (user.hasActiveAbility?(:ICEBODY) && w == :Hail)
      return 0.0
    end

    # ER versions (050): no burn damage with Heatproof / Flare Boost, no poison
    # damage with Toxic Boost: DemICE counted it
    def er_chip_back(user, rest)
      return 0.0 if rest || !defined?(KIFER::ERVersions) || !KIFER::ERVersions.on?
      return 0.0 if user.hasActiveAbility?(:MAGICGUARD)
      return 0.0625 if user.status == :BURN && user.hasActiveAbility?([:HEATPROOF, :FLAREBOOST])
      if user.status == :POISON && user.hasActiveAbility?(:TOXICBOOST) && !user.hasActiveAbility?(:POISONHEAL)
        t = user.effects[PBEffects::Toxic]
        return t != 0 ? 0.0625 * t : 0.125
      end
      return 0.0
    end

    def extra_chip(user, rest)
      c = 0.0
      if (bleeding?(user) || frostbitten?(user)) && !rest && user.takesIndirectDamage?
        c += 0.0625
      end
      c += 0.0625 if toxic_chip?(user)
      return c
    end

    #---------------------------------------------------------------------------
    # Items (DemICE): cure frostbite / bleeding as it cures a burn
    #---------------------------------------------------------------------------
    def item_score_of(ret)
      return 0 if !ret.is_a?(Array) || !ret[0].is_a?(Array)
      return ret[0][1].is_a?(Numeric) ? ret[0][1] : 0
    end

    # The status doesn't need curing (it helps, costs nothing, or the
    # Pokemon can cure it itself)
    def keep_status?(b, st)
      phys = false; spec = false; thaw = false; heal = false
      b.eachMove do |m|
        phys = true if m.physicalMove?(m.type)
        spec = true if m.specialMove?(m.type)
        thaw = true if m.thawsUser?
        heal = true if m.healingMove? && (t = m.pbTarget(b)) && [:User, :UserAndAllies].include?(t.id)
      end
      return true if b.hasActiveAbility?(:GUTS) && phys
      return true if b.hasActiveAbility?([:QUICKFEET, :MARVELSCALE])
      if st == :FROSTBITE
        return true if !spec || thaw
      else
        return true if heal || b.hasActiveAbility?(:NATURALCURE)
      end
      return false
    end

    # DemICE's score for curing a burn (its Full Heal / Burn Heal branch)
    def cure_item_score(ai, user)
      target = user.pbDirectOpposing(true)
      return 0 if !target || target.fainted?
      battle = user.battle
      skill = 100
      score = 100
      best = ai.bestMoveVsTarget(target, user, skill)
      maxdam = best[0]; maxmove = best[1]; maxprio = best[2]
      priomove = nil; priodam = 0
      user.eachMove do |j|
        next if ai.priorityAI(user, j) < 1
        if ai.moveLocked(user) && user.lastMoveUsed && user.pbHasMove?(user.lastMoveUsed)
          next if j.id != user.lastMoveUsed
        end
        d = ai.pbRoughDamage(j, user, target, skill, j.baseDamage)
        d = 0 if ai.pbCheckMoveImmunity(1, j, target, user, 100)
        if d > priodam
          priodam = d
          priomove = j
        end
      end
      half = user.totalhp / 2
      third = user.totalhp / 3
      aspeed = ai.pbRoughStat(user, :SPEED, skill)
      ospeed = ai.pbRoughStat(target, :SPEED, skill)
      asleep = target.status == :SLEEP && target.statusCount > 1
      if ai.targetSurvivesMove(maxmove, target, user, maxprio) || asleep
        score += 50
        score += 60 if asleep
        score += 60 if user.hasActiveAbility?(:SPEEDBOOST)
        aspeed *= 1.5 if user.hasActiveAbility?(:SPEEDBOOST)
        ospeed *= 1.5 if target.hasActiveAbility?(:SPEEDBOOST)
        tr = battle.field.effects[PBEffects::TrickRoom] > 1
        if ((aspeed < ospeed) ^ tr) && maxdam > half
          if priomove && ai.targetSurvivesMove(priomove, user, target) &&
             !ai.targetSurvivesMove(priomove, user, target, 0, 2)
            score += 90
          else
            score -= 90
          end
        else
          score += 80
        end
        score += 20 if half > maxdam
        score += 40 if third > maxdam
      end
      return score
    end

    def status_item(ai, battle, idxBattler, ret)
      return ret if !demice_on? || !battle.internalBattle
      b = battle.battlers[idxBattler]
      return ret if !b || b.fainted?
      st = b.status
      return ret unless [:FROSTBITE, :BLEEDING].include?(st)
      return ret if keep_status?(b, st)
      items = battle.pbGetOwnerItems(idxBattler)
      return ret if !items || items.empty?
      pkmn = b.pokemon
      list = (st == :FROSTBITE) ? FROSTBITE_ITEMS + ALL_STATUS_ITEMS : ALL_STATUS_ITEMS
      pick = list.find do |i|
        items.include?(i) &&
          battle.pbCanUseItemOnPokemon?(i, pkmn, b, battle.scene, false) &&
          ItemHandlers.triggerCanUseInBattle(i, pkmn, b, nil, false, ai, battle.scene, false)
      end
      return ret if !pick
      score = cure_item_score(ai, b)
      return ret if score <= item_score_of(ret)
      return [[pick, score], idxBattler]
    rescue StandardError => e
      KIFER.log("AI status item: #{e.class}: #{e.message}")
      return ret
    end

    #---------------------------------------------------------------------------
    # Switching
    #---------------------------------------------------------------------------
    def stuck?(battler, battle)
      return afraid?(battler) && !KIFER::Fear.escapes?(battler, battle)
    end

    def want_out?(ai, battle, battler)
      return false if !battler || battler.fainted? || battle.wildBattle?
      if enraged?(battler) && recoil_hurts?(battler)
        foe = battler.pbDirectOpposing(true)
        if foe && !foe.fainted?
          best = best_damage(ai, battler, foe)
          return true if best > 0 && best < foe.hp && (best / 3) * 2 >= battler.hp
        end
      end
      if bleeding?(battler) && battler.hasActiveAbility?(:NATURALCURE) && battler.hp > battler.totalhp / 4
        return true
      end
      return false
    rescue StandardError => e
      KIFER.log("AI switch check: #{e.class}: #{e.message}")
      return false
    end
  end
end

#===============================================================================
# The AI's methods (KIF's switch sends each to DemICE's or PIF's version)
#===============================================================================
class PokeBattle_AI
  alias kifer_ai_pbRoughDamage pbRoughDamage unless method_defined?(:kifer_ai_pbRoughDamage)
  alias kifer_ai_pbRoughStat pbRoughStat unless method_defined?(:kifer_ai_pbRoughStat)
  alias kifer_ai_pbMoveBaseDamage pbMoveBaseDamage unless method_defined?(:kifer_ai_pbMoveBaseDamage)
  alias kifer_ai_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_ai_pbCalcTypeModSingle)
  alias kifer_ai_pbCalcTypeModPokemon pbCalcTypeModPokemon unless method_defined?(:kifer_ai_pbCalcTypeModPokemon)
  alias kifer_ai_pbGetMoveScoreFunctionCode pbGetMoveScoreFunctionCode unless method_defined?(:kifer_ai_pbGetMoveScoreFunctionCode)
  alias kifer_ai_pbGetMoveScore pbGetMoveScore unless method_defined?(:kifer_ai_pbGetMoveScore)
  alias kifer_ai_pbEnemyItemToUse pbEnemyItemToUse unless method_defined?(:kifer_ai_pbEnemyItemToUse)
  alias kifer_ai_pbEnemyShouldWithdrawEx? pbEnemyShouldWithdrawEx? unless method_defined?(:kifer_ai_pbEnemyShouldWithdrawEx?)
  alias kifer_ai_pbChooseBestNewEnemy pbChooseBestNewEnemy unless method_defined?(:kifer_ai_pbChooseBestNewEnemy)
  alias kifer_ai_pbDefaultChooseEnemyCommand pbDefaultChooseEnemyCommand unless method_defined?(:kifer_ai_pbDefaultChooseEnemyCommand)
  alias kifer_ai_pbChooseMoves pbChooseMoves unless method_defined?(:kifer_ai_pbChooseMoves)

  # Whole decisions: KIF's frostbite view for everything inside
  def pbDefaultChooseEnemyCommand(idxBattler)
    return KIFER::AI.frozen_view(@battle) { kifer_ai_pbDefaultChooseEnemyCommand(idxBattler) }
  end

  def pbChooseMoves(idxBattler)
    return KIFER::AI.frozen_view(@battle) { kifer_ai_pbChooseMoves(idxBattler) }
  end

  def pbRoughDamage(move, user, target, *args)
    KIFER::AI.frozen_view(@battle) do
      ret = KIFER::AI.stageless([user, target]) { kifer_ai_pbRoughDamage(move, user, target, *args) }
      next KIFER::AI.adjust_damage(self, ret, move, user, target, args[0])
    end
  end

  def pbRoughStat(battler, stat, skill)
    ret = KIFER::AI.stageless([battler]) { kifer_ai_pbRoughStat(battler, stat, skill) }
    return stat == :SPEED ? KIFER::AI.order_speed(battler, ret) : ret
  end

  def pbMoveBaseDamage(*args)
    return KIFER::AI.raw_speed { kifer_ai_pbMoveBaseDamage(*args) }
  end

  # Inverse Room: as 034 – a matchup something else already changed keeps it
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_ai_pbCalcTypeModSingle(moveType, defType, user, target)
    return ret if !moveType || !defType || !KIFER::AI.inverse?(@battle)
    return ret if ret != Effectiveness.calculate_one(moveType, defType)
    return KIFER::Specials1.invert(ret)
  end

  def pbCalcTypeModPokemon(battlerThis, target)
    return kifer_ai_pbCalcTypeModPokemon(battlerThis, target) if !KIFER::AI.inverse?(@battle)
    return KIFER::AI.inverse_type_mod_pokemon(battlerThis, target)
  end

  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
    KIFER::AI.frozen_view(@battle) do
      ret = kifer_ai_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
      sap = KIFER::AI.sap_as_attack_drop(self, score, move, user, target, skill)
      ret = sap if sap.is_a?(Numeric) && ret.is_a?(Numeric) && sap < ret
      next KIFER::AI.adjust_function(self, ret, score, move, user, target)
    end
  end

  def pbGetMoveScore(move, user, target, skill = 100)
    KIFER::AI.frozen_view(@battle) do
      ret = kifer_ai_pbGetMoveScore(move, user, target, skill)
      next KIFER::AI.adjust_score(self, ret, move, user, target)
    end
  end

  if method_defined?(:pbGetMoveScoreDamage)
    alias kifer_ai_pbGetMoveScoreDamage pbGetMoveScoreDamage unless method_defined?(:kifer_ai_pbGetMoveScoreDamage)
    def pbGetMoveScoreDamage(score, move, user, target, skill)
      ret = kifer_ai_pbGetMoveScoreDamage(score, move, user, target, skill)
      return KIFER::AI.adjust_damage_score(self, ret, move, user, target)
    end
  end

  # No HP-only item on a bleeding Pokemon (it can't heal); DemICE cures the
  # new statuses as it cures a burn
  def pbEnemyItemToUse(idxBattler)
    KIFER::AI.frozen_view(@battle) do
      ret = kifer_ai_pbEnemyItemToUse(idxBattler)
      if ret.is_a?(Array)
        item = ret[0].is_a?(Array) ? ret[0][0] : ret[0]
        item = item.id if item.respond_to?(:id)
        # DemICE answers [[nil, 0], i] when its only item can't be used (an HP
        # item on a bleeding Pokemon): that's no item
        ret = nil if item.nil?
        ret = nil if item && KIFER::AI.bleeding?(@battle.battlers[idxBattler]) && KIFER::AI::HP_ITEMS.include?(item)
      end
      next KIFER::AI.status_item(self, @battle, idxBattler, ret)
    end
  end

  def pbEnemyShouldWithdrawEx?(idxBattler, forceSwitch)
    KIFER::AI.frozen_view(@battle) do
      battler = @battle.battlers[idxBattler]
      next false if battler && KIFER::AI.stuck?(battler, @battle)   # fear traps it
      ret = kifer_ai_pbEnemyShouldWithdrawEx?(idxBattler, forceSwitch)
      next ret if ret || forceSwitch
      next ret if !KIFER::AI.want_out?(self, @battle, battler)
      # DemICE's forced choice already skips the Pokemon the ally chose
      next kifer_ai_pbEnemyShouldWithdrawEx?(idxBattler, true) if KIFER::AI.demice_on?
      # PIF's forced switch sends the first able Pokemon: pick the best one
      party = @battle.pbParty(idxBattler)
      enemies = (0...party.length).select { |i| @battle.pbCanSwitch?(idxBattler, i) }
      pick = pbChooseBestNewEnemy(idxBattler, party, enemies)
      next pick >= 0 && @battle.pbRegisterSwitch(idxBattler, pick)
    end
  end

  # Switch-ins judged in the field they would make on entry
  def pbChooseBestNewEnemy(idxBattler, party, enemies, *rest)
    KIFER::AI.frozen_view(@battle) do
      if !KIFER::AI.demice_on?
        if rest.empty? && KIFER::AI.pif_switch_changed?(@battle, party, enemies, idxBattler)
          next KIFER::AI.pif_best_new_enemy(@battle, idxBattler, party, enemies)
        end
        next kifer_ai_pbChooseBestNewEnemy(idxBattler, party, enemies, *rest)
      end
      next KIFER::AI.switch_scope { kifer_ai_pbChooseBestNewEnemy(idxBattler, party, enemies, *rest) }
    end
  end

  if method_defined?(:EndofTurnHPChanges)
    alias kifer_ai_EndofTurnHPChanges EndofTurnHPChanges unless method_defined?(:kifer_ai_EndofTurnHPChanges)
    def EndofTurnHPChanges(user, target, heal, chips, both, switching = false, rest = false)
      KIFER::AI.frozen_view(@battle) do
        ret = kifer_ai_EndofTurnHPChanges(user, target, heal, chips, both, switching, rest)
        next ret if !ret.is_a?(Numeric) || !user
        extra = KIFER::AI.extra_chip(user, rest) - KIFER::AI.er_chip_back(user, rest)
        er_heal = KIFER::AI.er_heal_extra(user)
        bleed = KIFER::AI.bleeding?(user)
        next ret if extra == 0 && er_heal == 0 && !bleed
        next (bleed ? [ret + er_heal, 1].min : ret + er_heal) if heal
        next ret + extra if chips
        h = kifer_ai_EndofTurnHPChanges(user, target, true, false, false, switching, rest) + er_heal
        lost_heal = bleed ? h - [h, 1].min : 0
        next ret + er_heal - lost_heal - extra
      end
    end
  end
end

# DemICE's stand-in battlers for the Pokemon it may send in
class PokeBattle_Battle
  if method_defined?(:pbMakeFakeBattler)
    alias kifer_ai_pbMakeFakeBattler pbMakeFakeBattler unless method_defined?(:kifer_ai_pbMakeFakeBattler)
    def pbMakeFakeBattler(pokemon, *args)
      b = kifer_ai_pbMakeFakeBattler(pokemon, *args)
      KIFER::AI.switch_candidate(self, b)
      return b
    end
  end
end
