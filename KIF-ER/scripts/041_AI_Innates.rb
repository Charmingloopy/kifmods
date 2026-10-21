#===============================================================================
# KIF: Elite Redux – the trainers' battle AI sees innates and the Elite Redux abilities
#   Both of KIF's AIs (DemICE's, or PIF's own when Options > Battles > Battle
#   AI is PIF) mostly ask hasActiveAbility? and the ability handlers, which
#   already see innates (003/004). This file covers what they still missed.
#   Nothing changes while Innates is Off.
#
#   Immunities (pbCheckMoveImmunity, and a move's score is 0):
#     - the ER absorb / immunity abilities, main or innate: Poison Absorb,
#       Aerodynamics, Earth Eater, Ice Dew, Heat Sink, Well Baked Body,
#       Mountaineer, Wind Rider (wind moves), Weather Control (foes' weather
#       moves). Mold Breaker gets past them, as in battle.
#     - Sand Guard (sandstorm) and Sun Basking (sun) block foes' priority moves
#     - PIF's AI only checked immunity for attacks: now status moves too
#       (no Toxic into Poison Absorb)
#     - Bone Zone: bone moves hit Flying types, Levitate and the like
#     - doubles: a Fire move aimed at one Pokemon while another one has Heat
#       Sink (it draws the move in)
#     - Megas abilities: Evaporate (Water), Gifted Mind (Dark, Ghost, Bug),
#       Good as Gold (status moves), Radiance (every Dark move fails), Armor
#       Tail and Lucha Libre (foes' priority moves), Desert Spirit (its Ground
#       moves hit floaters in sand)
#   Type matchups (the AI's own pbCalcTypeModSingle): Overcharge, Molten
#     Down, Ground Shock, Overwhelm, Draconize, Phantom Pain, Bone Zone,
#     Desert Spirit, Trash Heap / Tummyache (Corrosion), Foggy Eye
#   Damage estimate (pbRoughDamage). Handlers already run for innates; the ER
#     abilities that live in the game's own methods are added here:
#     - attacking / defending stat: Power Core, Speed Force, Momentum, Mind
#       Crunch, Ancient Idol, Magical Fists, Equinox, Juggernaut, Power Fists,
#       Exploit Weakness, Grip Pincer, Elude, Blur... (asks the move itself)
#     - extra hits: Hyper Aggressive, Raging Boxer, Multi-Headed, Dual Wield
#     - Generator's charge, Catastrophe, Fighting Spirit going through screens
#     - Relic Stone on the field: no same-type boost from the user's types
#     - KIF's AI skipped the innates' damage handlers when the main ability
#       was one it works out itself (Sniper, Tinted Lens, -ate, Filter...)
#   Priority (DemICE's priorityAI): the priority abilities' handlers (main
#     and innates, copies count): Opportunist, Perfectionist, Sighting System,
#     Flaming Soul, Frozen Soul, Blitz Boxer, Coil Up, Cutthroat, On the
#     Prowl, Curlipede... DemICE's own Gale Wings / Prankster / Triage stay.
#   Weather and terrain moves (DemICE): innates count where DemICE looked at
#     a party Pokemon's main ability: its own Pokemon in the back that like
#     the new weather or terrain, and the foe's Pokemon that like the weather
#     it would replace.
#   Switch-ins (DemICE's pbChooseBestNewEnemy): the weather / terrain synergy
#     (a Drought Pokemon with a Chlorophyll one in the back...) counts innates
#     on both, through KIF's AI hooks (kif_ai_party_ability? and friends, KIF
#     0.21.67+; the end of this file). Hazard scores the same way.
#   Elite Redux versions (050, while on): Justified, Shield Dust, Taunt /
#     Oblivious and Prankster immunities, Corrosion and Normalize matchups,
#     Triage on drain moves, -ate STAB, Heatproof / Flare Boost burns, Filter
#     x0.65, and the ER numbers in DemICE's switch-in choice.
#   Handlers that read the hit (typeMod, critical) see the move being judged.
#===============================================================================
module KIFER
  module AIInnates
    # ability => type its handler blocks (for moves from another Pokemon)
    TYPE_IMMUNE = {
      :POISONABSORB  => :POISON,
      :AERODYNAMICS  => :FLYING,
      :EARTHEATER    => :GROUND,
      :ICEDEW        => :ICE,
      :HEATSINK      => :FIRE,
      :WELLBAKEDBODY => :FIRE,
      :MOUNTAINEER   => :ROCK,
      :EVAPORATE     => :WATER
    }
    # Dazzling's priority block under other names (Megas abilities)
    PRIORITY_BLOCK = [:ARMORTAIL, :LUCHALIBRE]
    # priority abilities DemICE's priorityAI already counts
    DEMICE_PRIO = [:GALEWINGS, :PRANKSTER, :TRIAGE]
    # DemICE's bonus for Pokemon in the back with an ability for that weather
    # or terrain: function code => [[abilities, score], ...]
    BENCH = {
      "0FF" => [[[:CHLOROPHYLL], 40], [[:FLOWERGIFT, :SOLARPOWER, :PROTOSYNTHESIS], 20]],
      "100" => [[[:SWIFTSWIM], 40], [[:RAINDISH, :DRYSKIN, :HYDRATION], 20]],
      "101" => [[[:SANDRUSH], 40], [[:SANDVEIL, :SANDFORCE], 20]],
      "102" => [[[:SLUSHRUSH], 40], [[:SNOWCLOAK, :ICEBODY], 20]],
      "154" => [[[:SURGESURFER], 40], [[:QUARKDRIVE], 20]],
      "155" => [[[:GRASSPELT], 20]]
    }
    # DemICE's score for the foe's Pokemon that like the weather in play:
    # function code => [[[[ability, weather], ...], score], ...]
    FOE_WEATHER = {
      "0FF" => [[[[:SWIFTSWIM, :Rain]], 40], [[[:SLUSHRUSH, :Hail], [:SANDRUSH, :Sandstorm]], 20]],
      "100" => [[[[:CHLOROPHYLL, :Sun]], 40], [[[:SLUSHRUSH, :Hail], [:SANDRUSH, :Sandstorm]], 20]],
      "101" => [[[[:CHLOROPHYLL, :Sun], [:SWIFTSWIM, :Rain]], 40], [[[:SLUSHRUSH, :Hail]], 20]],
      "102" => [[[[:CHLOROPHYLL, :Sun], [:SWIFTSWIM, :Rain]], 40], [[[:SANDRUSH, :Sandstorm]], 20]]
    }

    module_function

    def on?
      return KIFER.enabled? || er? || KIFER.feature_on?   # innates, ER versions, new effects
    end

    # Elite Redux versions of PIF's abilities (050) are in play
    def er?
      return defined?(KIFER::ERVersions) && KIFER::ERVersions.on?
    end

    # DemICE's switch-in choice (KIF's hooks, end of file): the ER numbers while 050 is on
    def weather_speed
      return er? ? 1.5 : 2
    end

    def solar_power?(b, move)
      return er? ? KIFER::ERVersions.uses_highest?(b, move) : move.specialMove?
    end

    def sand_force(b, move)
      return (KIFER::ERVersions.uses_highest?(b, move) ? 1.5 : 1) if er?
      return [:GROUND, :ROCK, :STEEL].include?(move.type) ? 1.3 : 1
    end

    # hasActiveAbility? without leaving the innate's name for a splash
    def has?(b, id, mold_broken = false)
      return false if !b || !b.respond_to?(:hasActiveAbility?)
      old = b.respond_to?(:kifer_inline) ? b.kifer_inline : nil
      ret = b.hasActiveAbility?(id, false, mold_broken)
      b.instance_variable_set(:@kifer_inline, old) if b.respond_to?(:kifer_inline)
      return ret
    end

    # Main ability or innate, for a battler or a party Pokemon (DemICE's
    # "x.ability == :ID")
    def abil?(x, id)
      return false if !x
      return has?(x, id) if x.is_a?(PokeBattle_Battler)
      return true if x.respond_to?(:ability_id) && x.ability_id == id
      return x.is_a?(Pokemon) && KIFER.battle_innates(x).include?(id)
    rescue StandardError
      return false
    end

    # Main ability and active innates, copies included (the order 004 runs them)
    def abilities(b)
      return [] if !b || !b.abilityActive?
      list = []
      list << b.ability_id if b.ability_id
      list.concat(b.active_innates) if b.respond_to?(:active_innates)
      return list
    end

    def const(mod, name)
      return nil unless defined?(KIFER) && KIFER.const_defined?(mod)
      m = KIFER.const_get(mod)
      return m.const_defined?(name) ? m.const_get(name) : nil
    end

    def staged(value, stage)
      s = [[stage.to_i, 0].max, 12].min
      return value.to_f * STAGE_MUL[s] / STAGE_DIV[s]
    end

    # The move the AI is looking at (for Bone Zone in the type chart)
    def with_move(move)
      old = Thread.current[:kifer_aii_move]
      Thread.current[:kifer_aii_move] = move
      begin
        return yield
      ensure
        Thread.current[:kifer_aii_move] = old
      end
    end

    def current_move
      return Thread.current[:kifer_aii_move]
    end

    def bone_zone?(user, move)
      return false unless user && move && defined?(KIFER::BatchA)
      return KIFER::BatchA.bone_zone?(user, move)
    rescue StandardError
      return false
    end

    # Runs the block with the move hitting airborne targets, as 020 does in
    # battle for Bone Zone
    def with_bone_zone(user, move)
      flag = if bone_zone?(user, move) then :@kifer_a_bonezone
             elsif desert_spirit?(user, move) then :@kifer_j_desert
             end
      return yield if !flag
      old = move.instance_variable_get(flag)
      move.instance_variable_set(flag, true)
      begin
        return yield
      ensure
        move.instance_variable_set(flag, old)
      end
    end

    # Desert Spirit (029): its Ground moves hit Flying types and floaters in sand
    def desert_spirit?(user, move)
      return false unless user && move && defined?(KIFER::BatchJ)
      return KIFER::BatchJ.desert_spirit?(user, move)
    rescue StandardError
      return false
    end

    def mold_breaker?(ai, user, target, move)
      return true if user.hasMoldBreaker?
      return true if ai.respond_to?(:moldbroken) && ai.moldbroken(user, target, move.function)
      return false
    end

    def priority(ai, user, move)
      return ai.priorityAI(user, move) if ai.respond_to?(:priorityAI)
      return move.priority
    rescue StandardError
      return move.priority
    end

    #---------------------------------------------------------------------------
    # Immunities
    #---------------------------------------------------------------------------
    def er_immune?(ai, move, user, target)
      return false if !move || !user || !target || user.index == target.index
      t = move.pbTarget(user)
      return false if t && t.num_targets == 0
      type = ai.pbRoughType(move, user, 100)
      mb = mold_breaker?(ai, user, target, move)
      TYPE_IMMUNE.each do |id, ty|
        return true if type == ty && has?(target, id, mb)
      end
      return true if type == :FIRE && heat_sink_draws?(move, user, target)
      gifted = const(:BatchJ, :GIFTED_TYPES)
      return true if gifted && gifted.include?(type) && has?(target, :GIFTEDMIND, mb)
      return true if move.statusMove? && t && t.id != :AllBattlers && has?(target, :GOODASGOLD, mb)
      # Radiance: every Dark move fails while one is on the field
      return true if type == :DARK && user.battle.battlers.any? { |b| b && !b.fainted? && has?(b, :RADIANCE) }
      wind = const(:BatchG, :WIND_MOVES)
      return true if wind && wind.include?(move.id) && has?(target, :WINDRIDER, mb)
      weather = const(:BatchH, :WEATHER_MOVES)
      return true if weather && weather.include?(move.id) && user.index != target.index &&
                     has?(target, :WEATHERCONTROL, mb)
      # Sand Guard / Sun Basking: foes' priority moves
      if user.opposes?(target)
        w = user.battle.pbWeather
        sand = (w == :Sandstorm)
        sun  = [:Sun, :HarshSun].include?(w)
        if priority(ai, user, move) > 0
          user.battle.eachSameSideBattler(target.index) do |b|
            return true if sand && has?(b, :SANDGUARD, mb)
            return true if sun && has?(b, :SUNBASKING, mb)
            return true if has?(b, PRIORITY_BLOCK, mb)
          end
        end
      end
      return er_versions_immune?(move, user, target, type, mb) if er?
      return false
    rescue StandardError => e
      KIFER.log("AI innates immunity: #{e.class}: #{e.message}")
      return false
    end

    # Another Pokemon's Heat Sink draws in a Fire move aimed at one Pokemon
    # (025), so the target isn't hit
    def heat_sink_draws?(move, user, target)
      t = move.pbTarget(user)
      return false if !t.can_target_one_foe? || move.cannotRedirect? || has?(user, :PROPELLERTAIL)
      return false if has?(target, :HEATSINK)
      near = !t.can_choose_distant_target?
      user.battle.eachBattler do |b|
        next if b.index == user.index || b.index == target.index || (near && !b.near?(user))
        return true if has?(b, :HEATSINK)
      end
      return false
    end

    # What 050's Elite Redux versions block (Justified, Shield Dust, Taunt and
    # Oblivious, Prankster vs Dark types)
    OBLIVIOUS_BLOCKS = ["0B7", "0B9", "0BC"]

    def er_versions_immune?(move, user, target, type, mb)
      return true if type == :DARK && has?(target, :JUSTIFIED, mb)
      return true if move.powderMove? && !mb && has?(target, :SHIELDDUST)
      if !mb
        return true if move.function == "0BA" && target.effects[PBEffects::Taunt] <= 0 &&
                       KIFER::ERVersions::TAUNT_IMMUNE.any? { |id| has?(target, id) }
        return true if OBLIVIOUS_BLOCKS.include?(move.function) && has?(target, :OBLIVIOUS)
      end
      return true if Settings::MECHANICS_GENERATION < 7 && move.statusMove? && user.opposes?(target) &&
                     target.pbHasType?(:DARK) && has?(user, :PRANKSTER)
      return false
    end

    #---------------------------------------------------------------------------
    # Type matchups (the AI's pbCalcTypeModSingle), as 020-025 change them
    #---------------------------------------------------------------------------
    def ineffective_value?(ret, battle)
      return true if ret == Effectiveness::INEFFECTIVE
      return defined?(KIFER::Specials1) && KIFER::Specials1.respond_to?(:inverse_room?) &&
             KIFER::Specials1.inverse_room?(battle) &&
             ret == KIFER::Specials1.invert(Effectiveness::INEFFECTIVE)
    end

    def type_mod(ret, mt, dt, user, target)
      return ret if !user.respond_to?(:hasActiveAbility?)
      if mt == :ELECTRIC && dt == :ELECTRIC && has?(user, :OVERCHARGE)
        return Effectiveness::SUPER_EFFECTIVE_ONE
      end
      if mt == :FIRE && dt == :ROCK && has?(user, :MOLTENDOWN)
        return Effectiveness::SUPER_EFFECTIVE_ONE
      end
      # Corrosion (050); Trash Heap and Tummyache whether 050 is on or not (039)
      trash = const(:BatchL, :COUNTS_AS)
      if mt == :POISON && dt == :STEEL &&
         ((er? && has?(user, :CORROSION)) || (trash && has?(user, trash[:CORROSION])))
        return Effectiveness::SUPER_EFFECTIVE_ONE
      end
      return ret if !Effectiveness.ineffective_type?(mt, dt)
      return Effectiveness::NORMAL_EFFECTIVE_ONE if bone_zone?(user, current_move)
      if mt == :GROUND && dt == :FLYING && defined?(KIFER::BatchJ) &&
         KIFER::BatchJ.sand?(user.battle) && has?(user, :DESERTSPIRIT)
        return Effectiveness::NORMAL_EFFECTIVE_ONE
      end
      return ret if !ineffective_value?(ret, user.battle)
      if mt == :ELECTRIC && dt == :GROUND && has?(user, :GROUNDSHOCK)
        return Effectiveness::NOT_VERY_EFFECTIVE_ONE
      end
      if mt == :DRAGON && dt == :FAIRY &&
         (has?(user, :OVERWHELM) || (user.pbHasType?(:DRAGON) && has?(user, :DRACONIZE)))
        return Effectiveness::NORMAL_EFFECTIVE_ONE
      end
      if mt == :GHOST && dt == :NORMAL && has?(user, :PHANTOMPAIN)
        return Effectiveness::NORMAL_EFFECTIVE_ONE
      end
      return ret
    rescue StandardError => e
      KIFER.log("AI innates type matchup: #{e.class}: #{e.message}")
      return ret
    end

    #---------------------------------------------------------------------------
    # Damage estimate
    #---------------------------------------------------------------------------
    # Attacking / defending stat as the move works it out (ER hooks) against
    # the plain one the AI uses
    def stat_ratio(move, user, target, type)
      r = 1.0
      old = move.instance_variable_get(:@calcType)
      move.instance_variable_set(:@calcType, type)
      begin
        spec = move.specialMove?(type)
        if move.method(:pbGetAttackStats).owner == PokeBattle_Move
          s, st = move.pbGetAttackStats(user, target)
          bs, bst = spec ? [user.spatk, user.stages[:SPECIAL_ATTACK] + 6] : [user.attack, user.stages[:ATTACK] + 6]
          if [s, st] != [bs, bst] && bs > 0
            r *= staged(s, st) / staged(bs, bst)
          end
        end
        owner = move.method(:pbGetDefenseStats).owner
        psy = defined?(PokeBattle_Move_122) && owner == PokeBattle_Move_122
        if owner == PokeBattle_Move || psy
          s, st = move.pbGetDefenseStats(user, target)
          bs, bst = (spec && !psy) ? [target.spdef, target.stages[:SPECIAL_DEFENSE] + 6] :
                                     [target.defense, target.stages[:DEFENSE] + 6]
          if [s, st] != [bs, bst] && s > 0
            r *= staged(bs, bst) / staged(s, st)
          end
        end
      ensure
        move.instance_variable_set(:@calcType, old)
      end
      return r
    end

    # Extra hits from abilities (the AI already counts Parental Bond)
    def hits_mult(ai, move, user, target)
      return 1.0 if move.multiHitMove? || move.chargingTurnMove?
      return 1.0 if ai.pbTargetsMultiple?(move, user)
      return 1.0 if has?(user, :PARENTALBOND)
      fort = defined?(KIFER::BatchH) && KIFER::BatchH.fort_knox?(user, target)
      return 1.25 if has?(user, :HYPERAGGRESSIVE) && !fort
      return 1.4 if move.punchingMove? && has?(user, :RAGINGBOXER)
      if has?(user, :MULTIHEADED) && defined?(KIFER::BatchE)
        heads = KIFER::BatchE.heads(user)
        return 1.25 if heads == 2    # 100% + 25%
        return 1.35 if heads == 3    # 100% + 20% + 15%
      end
      if defined?(KIFER::BatchF) && KIFER::BatchF.dual_wield_move?(move) && has?(user, :DUALWIELD)
        return 1.4
      end
      return 1.0
    end

    # The ER parts of pbCalcDamageMultipliers that aren't handlers
    def extra_mult(ai, move, user, target, type)
      m = 1.0
      battle = user.battle
      if type == :ELECTRIC && user.instance_variable_get(:@kifer_a_charged) &&
         user.effects[PBEffects::Charge] == 0
        m *= 2
      end
      if type && has?(user, :CATASTROPHE)
        w = battle.pbWeather
        if (type == :WATER && [:Sun, :HarshSun].include?(w)) ||
           (type == :FIRE && [:Rain, :HeavyRain].include?(w))
          m *= 3
        end
      end
      # Relic Stone (035): no same-type boost from its types; ability boosts
      # are already cut in the handlers the AI runs
      if type && user.pbHasType?(type) && defined?(KIFER::Specials2) &&
         KIFER::Specials2.respond_to?(:relic_on?) && KIFER::Specials2.relic_on?(user)
        m /= user.hasActiveAbility?(:ADAPTABILITY) ? 2 : 1.5
      end
      if type == :FIGHTING && user.pbHasType?(:FIGHTING) && has?(user, :FIGHTINGSPIRIT) &&
         !move.ignoresReflect? && !user.hasActiveAbility?(:INFILTRATOR)
        side = target.pbOwnSide.effects
        if side[PBEffects::AuroraVeil] > 0 ||
           (side[PBEffects::Reflect] > 0 && move.physicalMove?(type)) ||
           (side[PBEffects::LightScreen] > 0 && move.specialMove?(type))
          m *= (battle.pbSideBattlerCount(target) > 1) ? 1.5 : 2
        end
      end
      return m
    end

    # KIF's AI helpers work out a few main abilities themselves (Tinted Lens,
    # the -ate ones, Filter, Solid Rock) or skip them (Analytic, Sniper) and
    # then never run the handlers, so the innates' ones didn't run either
    KIF_USER_OWN   = [:ANALYTIC, :SNIPER, :TINTEDLENS, :AERILATE, :PIXILATE, :REFRIGERATE, :GALVANIZE]
    KIF_TARGET_OWN = [:FILTER, :SOLIDROCK]

    def run_innates(trigger, b, args)
      return if !on? || !b.abilityActive? || !b.respond_to?(:active_innates)
      raw = BattleHandlers.respond_to?(:"kifer_#{trigger}") ? :"kifer_#{trigger}" : trigger
      b.active_innates.each { |id| KIFER.with_context(b, id) { BattleHandlers.send(raw, id, *args) } }
      b.kifer_clear_inline if b.respond_to?(:kifer_clear_inline)
    end

    def target_mult(trigger, ai, move, user, target, type)
      mults = { :base_damage_multiplier => 1.0, :attack_multiplier => 1.0,
                :defense_multiplier => 1.0, :final_damage_multiplier => 1.0 }
      args = [user, target, move, mults, ai.pbMoveBaseDamage(move, user, target, 100), type]
      raw = BattleHandlers.respond_to?(:"kifer_#{trigger}") ? :"kifer_#{trigger}" : trigger
      BattleHandlers.send(raw, target.ability, *args)
      run_innates(trigger, target, args)
      d = mults[:defense_multiplier].to_f
      return 1.0 if d <= 0
      return mults[:base_damage_multiplier] * mults[:attack_multiplier] *
             mults[:final_damage_multiplier] / d
    end

    # The AIs give a main Filter / Solid Rock / Prism Armor PIF's x0.75 inline
    # and skip that Pokemon's other handlers (DemICE inline, PIF in KIF's
    # helper); DemICE also gives an innate Filter x0.75 on top of its handler.
    # The handlers run here instead (so ER's x0.65 from 050 counts too).
    # What the AI's estimate applied for Filter / Solid Rock: KIF's one
    # method for both AIs (0.21.58+), whatever other mods changed it to
    def ai_weakness(ai, move, user, target, type, se)
      m = :kif_ai_weakness_ability_multiplier
      return se ? 0.75 : 1.0 if !ai.respond_to?(m, true)   # KIF before 0.21.58
      w = ai.send(m, user, target, move, type, target.damageState.typeMod, false)
      return (w.is_a?(Numeric) && w > 0) ? w : 1.0
    end

    def filter_fix(ai, move, user, target, type)
      return 1.0 if !target.abilityActive?
      se = Effectiveness.super_effective?(target.damageState.typeMod)
      r = 1.0
      # DemICE also counts Sunsteel Strike / Moongeist Beam (163) as ignoring abilities
      mold = user.hasMoldBreaker? ||
             (KIFER::AI.demice_on? && ai.respond_to?(:moldbroken, true) && ai.send(:moldbroken, user, target, move.function))
      return 1.0 if mold && target.ability_id != :PRISMARMOR
      if KIF_TARGET_OWN.include?(target.ability_id)
        if !mold
          r *= target_mult(:triggerDamageCalcTargetAbility, ai, move, user, target, type)
          r /= ai_weakness(ai, move, user, target, type, se)
        end
      elsif se && !mold && KIFER::AI.demice_on? &&
            KIF_TARGET_OWN.any? { |id| has?(target, id) }
        r /= ai_weakness(ai, move, user, target, type, se)
      end
      if target.ability_id == :PRISMARMOR
        r *= target_mult(:triggerDamageCalcTargetAbilityNonIgnorable, ai, move, user, target, type)
        r /= 0.75 if se
      end
      return r
    end

    # 050's multipliers outside the handlers (-ate / Steelworker STAB, no burn
    # drop with Heatproof / Flare Boost); KIF's AI helper gives a main -ate
    # ability PIF's x1.2 power, which ER doesn't have
    ATE = [:AERILATE, :PIXILATE, :REFRIGERATE, :GALVANIZE]

    def er_versions_mult(move, user, target, type)
      mults = { :base_damage_multiplier => 1.0, :attack_multiplier => 1.0,
                :defense_multiplier => 1.0, :final_damage_multiplier => 1.0 }
      KIFER::ERVersions.extra_multipliers(move, user, target, type, mults)
      r = mults[:final_damage_multiplier]
      r /= 1.2 if ATE.include?(user.ability_id) && user.abilityActive? && move.type == :NORMAL && type && type != :NORMAL
      return r
    end

    # Handlers that read the hit (Filter, Neuroforce, Tinted Lens, Sniper...)
    # see this move's matchup and no critical hit, not the last real hit's
    def with_hit(ai, move, user, target, skill)
      ds = target.damageState
      old_tm = ds.typeMod; old_crit = ds.critical
      ds.typeMod = ai.pbCalcTypeMod(ai.pbRoughType(move, user, skill || 100), user, target)
      ds.critical = false
      begin
        return yield
      ensure
        ds.typeMod = old_tm; ds.critical = old_crit
      end
    end

    def adjust_damage(ai, dmg, move, user, target, skill)
      return dmg if !dmg.is_a?(Numeric) || dmg <= 0 || !user || !target || !move.damagingMove?
      return dmg if move.is_a?(PokeBattle_FixedDamageMove)
      type = ai.pbRoughType(move, user, skill || 100)
      m = 1.0
      calc = proc do
        m *= stat_ratio(move, user, target, type)
        m *= hits_mult(ai, move, user, target)
        m *= extra_mult(ai, move, user, target, type)
        m *= filter_fix(ai, move, user, target, type)
        m *= er_versions_mult(move, user, target, type) if er?
      end
      if defined?(KIFER::AI) && KIFER::AI.respond_to?(:stageless)
        KIFER::AI.stageless([user, target]) { calc.call }
      else
        calc.call
      end
      return dmg if (m - 1.0).abs < 0.0001
      return [(dmg * m).floor, 1].max
    rescue StandardError => e
      KIFER.log("AI innates damage: #{e.class}: #{e.message}")
      return dmg
    end

    #---------------------------------------------------------------------------
    # Priority (DemICE's priorityAI)
    #---------------------------------------------------------------------------
    def priority_change(user, move, pri)
      return pri if !move.respond_to?(:pbTarget)
      raw = BattleHandlers.respond_to?(:kifer_triggerPriorityChangeAbility) ?
            :kifer_triggerPriorityChangeAbility : :triggerPriorityChangeAbility
      abilities(user).each do |id|
        # DemICE counts Triage for healing moves only; ER's (050) adds drain moves
        next if DEMICE_PRIO.include?(id) && (id != :TRIAGE || move.healingMove? || !er?)
        r = BattleHandlers.send(raw, id, user, move, pri)
        pri = r if r.is_a?(Numeric)
      end
      user.kifer_clear_inline if user.respond_to?(:kifer_clear_inline)
      return pri
    rescue StandardError => e
      KIFER.log("AI innates priority: #{e.class}: #{e.message}")
      return pri
    end

    #---------------------------------------------------------------------------
    # Weather / terrain moves (DemICE): innates of the Pokemon in the back
    #---------------------------------------------------------------------------
    # DemICE's score for one party Pokemon with these abilities
    def group_score(ids, groups)
      return groups.sum { |list, score| list.any? { |a| ids.include?(a) } ? score : 0 }
    end

    def foe_score(ids, groups, weather)
      return groups.sum { |pairs, score| pairs.any? { |a, w| w == weather && ids.include?(a) } ? score : 0 }
    end

    # What the innates add to DemICE's score (it only saw main abilities)
    # DemICE adds 40 to Sunny Day / Rain Dance / Sandstorm / Hail when the
    # user's weather Speed (x2) lets it outspeed; ER's is x1.5
    SPEED_WEATHER = { "0FF" => :CHLOROPHYLL, "100" => :SWIFTSWIM, "101" => :SANDRUSH, "102" => :SLUSHRUSH }

    def weather_speed_fix(ai, battle, move, user, target)
      id = SPEED_WEATHER[move.function]
      return 0 if !id || !target || weather_speed >= 2 || !user.hasActiveAbility?(id)
      a = ai.pbRoughStat(user, :SPEED, 100)
      o = ai.pbRoughStat(target, :SPEED, 100)
      tr = battle.field.effects[PBEffects::TrickRoom] > 1
      was = ((a < o) ^ tr) && ((a * 2 > o) ^ tr)
      now = ((a < o) ^ tr) && ((a * weather_speed > o) ^ tr)
      return (was && !now) ? -40 : 0
    end

    def weather_bonus(battle, move, user, target)
      bench = BENCH[move.function]
      foe = FOE_WEATHER[move.function]
      return 0 if !bench && !foe
      v = 0
      if bench
        inBattle = battle.allSameSideBattlers(user.index).map { |b| b.pokemonIndex }
        battle.pbParty(user.index).each_with_index do |pkmn, i|
          next if !pkmn || !pkmn.able? || inBattle.include?(i)
          main = [pkmn.ability_id]
          v += group_score(main + KIFER.battle_innates(pkmn), bench) - group_score(main, bench)
        end
      end
      if foe && target
        w = battle.pbWeather
        battle.pbParty(target.index).each do |pkmn|
          next if !pkmn || !pkmn.able?
          main = [pkmn.ability_id]
          v += foe_score(main + KIFER.battle_innates(pkmn), foe, w) - foe_score(main, foe, w)
        end
      end
      return v
    rescue StandardError => e
      KIFER.log("AI innates weather move: #{e.class}: #{e.message}")
      return 0
    end
  end
end

#===============================================================================
# The AI's methods (KIF sends each to DemICE's or PIF's version)
#===============================================================================
class PokeBattle_AI
  alias kifer_aii_pbCheckMoveImmunity pbCheckMoveImmunity unless method_defined?(:kifer_aii_pbCheckMoveImmunity)
  alias kifer_aii_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_aii_pbCalcTypeModSingle)
  alias kifer_aii_pbRoughDamage pbRoughDamage unless method_defined?(:kifer_aii_pbRoughDamage)
  alias kifer_aii_pbGetMoveScore pbGetMoveScore unless method_defined?(:kifer_aii_pbGetMoveScore)
  alias kifer_aii_pbGetMoveScoreFunctionCode pbGetMoveScoreFunctionCode unless method_defined?(:kifer_aii_pbGetMoveScoreFunctionCode)

  if method_defined?(:kif_ai_user_damage_ability)
    alias kifer_aii_kif_ai_user_damage_ability kif_ai_user_damage_ability unless method_defined?(:kifer_aii_kif_ai_user_damage_ability)
    def kif_ai_user_damage_ability(user, target, move, type, typeMod, mults, baseDmg)
      kifer_aii_kif_ai_user_damage_ability(user, target, move, type, typeMod, mults, baseDmg)
      return if !KIFER::AIInnates::KIF_USER_OWN.include?(user.ability_id)
      KIFER::AIInnates.run_innates(:triggerDamageCalcUserAbility, user, [user, target, move, mults, baseDmg, type])
    end
  end

  # KIF's per-decision memo (004_AI_Memo.rb) holds these answers too; the
  # switch-in field being judged (040) is part of the key
  def pbCheckMoveImmunity(score, move, user, target, skill)
    return kifer_aii_pbCheckMoveImmunity(score, move, user, target, skill) if !KIFER::AIInnates.on? || !move
    memo = @kif_memo
    key = [:i_imm, score <= 0, move.object_id, user.object_id, target.object_id, skill, KIFER::AI.sim_for(@battle)] if memo
    return memo[key] if memo && memo.has_key?(key)
    ret = KIFER::AIInnates.with_move(move) do
      KIFER::AIInnates.with_bone_zone(user, move) do
        kifer_aii_pbCheckMoveImmunity(score, move, user, target, skill)
      end
    end
    ret ||= skill >= PBTrainerAI.mediumSkill && KIFER::AIInnates.er_immune?(self, move, user, target)
    memo[key] = ret if memo
    return ret
  end

  # Normalize (050): Normal moves ignore resistances
  alias kifer_aii_pbCalcTypeMod pbCalcTypeMod unless method_defined?(:kifer_aii_pbCalcTypeMod)
  def pbCalcTypeMod(moveType, user, target)
    ret = kifer_aii_pbCalcTypeMod(moveType, user, target)
    if moveType == :NORMAL && ret > 0 && ret < Effectiveness::NORMAL_EFFECTIVE && user &&
       KIFER::AIInnates.er? && KIFER::AIInnates.has?(user, :NORMALIZE)
      ret = Effectiveness::NORMAL_EFFECTIVE
    end
    # Foggy Eye (029): resists Ghost moves in fog
    if moveType == :GHOST && ret > 0 && target && KIFER::AIInnates.on? && defined?(KIFER::Fog) &&
       KIFER::Fog.active?(@battle) && !(user && user.hasMoldBreaker?) &&
       KIFER::AIInnates.has?(target, :FOGGYEYE)
      ret /= 2
    end
    return ret
  end

  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_aii_pbCalcTypeModSingle(moveType, defType, user, target)
    return ret if !moveType || !defType || !user || !KIFER::AIInnates.on?
    return KIFER::AIInnates.type_mod(ret, moveType, defType, user, target)
  end

  def pbRoughDamage(move, user, target, *args)
    return kifer_aii_pbRoughDamage(move, user, target, *args) if !KIFER::AIInnates.on? || !move
    memo = @kif_memo
    key = [:i_dmg, move.object_id, user.object_id, target.object_id, args, KIFER::AI.sim_for(@battle)] if memo
    return memo[key] if memo && memo.has_key?(key)
    ret = KIFER::AIInnates.with_move(move) do
      KIFER::AIInnates.with_hit(self, move, user, target, args[0]) do
        r = kifer_aii_pbRoughDamage(move, user, target, *args)
        KIFER::AIInnates.adjust_damage(self, r, move, user, target, args[0])
      end
    end
    memo[key] = ret if memo
    return ret
  end

  def pbGetMoveScore(move, user, target, skill = 100)
    return kifer_aii_pbGetMoveScore(move, user, target, skill) if !KIFER::AIInnates.on? || !move
    ret = KIFER::AIInnates.with_move(move) { kifer_aii_pbGetMoveScore(move, user, target, skill) }
    if ret.is_a?(Numeric) && ret > 0 && target && skill >= PBTrainerAI.mediumSkill &&
       KIFER::AIInnates.er_immune?(self, move, user, target)
      return 0
    end
    return ret
  end

  def pbGetMoveScoreFunctionCode(score, move, user, target, skill = 100)
    ret = kifer_aii_pbGetMoveScoreFunctionCode(score, move, user, target, skill)
    return ret if !ret.is_a?(Numeric) || !KIFER::AIInnates.on? || !KIFER::AI.demice_on?
    return ret if score + ret <= 0
    return ret + KIFER::AIInnates.weather_bonus(@battle, move, user, target) +
           KIFER::AIInnates.weather_speed_fix(self, @battle, move, user, target)
  end

  if method_defined?(:priorityAI)
    alias kifer_aii_priorityAI priorityAI unless method_defined?(:kifer_aii_priorityAI)
    def priorityAI(user, move, switchin = false)
      ret = kifer_aii_priorityAI(user, move, switchin)
      return ret if !KIFER::AIInnates.on? || !ret.is_a?(Numeric)
      return KIFER::AIInnates.priority_change(user, move, ret)
    end
  end

  # DemICE's switch-in choice and hazard scores ask KIF's hooks (KIF 0.21.67+),
  # so no copy of DemICE's method is needed here: innates count in the
  # weather / terrain synergy and for the Pokemon in the back (a Magic Guard
  # innate takes no hazard damage), and while Elite Redux versions (050) are
  # on, the weather Speed abilities, Solar Power and Sand Force use ER's numbers
  if method_defined?(:kif_demice_pbChooseBestNewEnemy)
    alias kifer_aii_kif_demice_pbChooseBestNewEnemy kif_demice_pbChooseBestNewEnemy unless method_defined?(:kifer_aii_kif_demice_pbChooseBestNewEnemy)
    def kif_demice_pbChooseBestNewEnemy(*args)
      return kif_memo_scope { kifer_aii_kif_demice_pbChooseBestNewEnemy(*args) } if KIFER::AIInnates.on?
      return kifer_aii_kif_demice_pbChooseBestNewEnemy(*args)
    end
  end

  if method_defined?(:kif_ai_party_ability?)
    alias kifer_kif_ai_party_ability? kif_ai_party_ability? unless method_defined?(:kifer_kif_ai_party_ability?)
    def kif_ai_party_ability?(pkmn, id)
      return kifer_kif_ai_party_ability?(pkmn, id) if !KIFER::AIInnates.on?
      return KIFER::AIInnates.abil?(pkmn, id) if !pkmn.is_a?(Pokemon) || !@kif_memo
      # one list per Pokemon per decision (KIF's memo): a switch choice asks
      # ~20 abilities for each of the party, each would rebuild the innates
      list = (@kif_memo[[:kifer_abils, pkmn.object_id]] ||= ([pkmn.ability_id] + KIFER.battle_innates(pkmn) rescue []))
      return list.include?(id)
    end
  end

  if method_defined?(:kif_ai_weather_speed)
    alias kifer_kif_ai_weather_speed kif_ai_weather_speed unless method_defined?(:kifer_kif_ai_weather_speed)
    def kif_ai_weather_speed
      return KIFER::AIInnates.weather_speed if KIFER::AIInnates.on?
      return kifer_kif_ai_weather_speed
    end
  end

  if method_defined?(:kif_ai_solar_power?)
    alias kifer_kif_ai_solar_power? kif_ai_solar_power? unless method_defined?(:kifer_kif_ai_solar_power?)
    def kif_ai_solar_power?(battler, move)
      return KIFER::AIInnates.solar_power?(battler, move) if KIFER::AIInnates.on?
      return kifer_kif_ai_solar_power?(battler, move)
    end
  end

  if method_defined?(:kif_ai_sand_force)
    alias kifer_kif_ai_sand_force kif_ai_sand_force unless method_defined?(:kifer_kif_ai_sand_force)
    def kif_ai_sand_force(battler, move)
      return KIFER::AIInnates.sand_force(battler, move) if KIFER::AIInnates.on?
      return kifer_kif_ai_sand_force(battler, move)
    end
  end
end
