#===============================================================================
# KIF: Elite Redux – Elite Redux statuses: frostbite and bleeding, and the abilities
# that need them. Mechanics follow Elite Redux 2.65 (its C source first, then
# its in-game texts and wiki where the public source has nothing).
#
# Frostbite (ER's STATUS1_FROSTBITE, from Legends: Arceus)
#   * A major status like burn. Loses 1/8 of its max HP at the end of each
#     round (Freezing Point's text: "Frostbitten Pokemon lose 1/8th of their
#     max HP each turn"; ER's code says 1/16, the text wins). Magic Guard
#     stops the damage. A Frozen Pokemon that KIF's own Frostbite treats as
#     frostbitten loses the same 1/8 (036).
#   * Its special moves deal half damage (Guts ignores this). Facade's power
#     doubles while frostbitten.
#   * Can't be inflicted on: Ice types, Magma Armor, Comatose, a Pokemon that
#     already has a status, Misty Terrain, Safeguard (as PIF's other statuses).
#     Sun doesn't stop it (it does stop freezing).
#   * Cured by: moves that thaw the user (Flame Wheel, Scald...) used by it or
#     hitting it, Aspear Berry, Lum Berry, Ice Heal, Full Heal, Refresh, Heal
#     Bell, Aromatherapy, Magma Armor, Natural Cure, Shed Skin, Hydration,
#     Healer, a Pokemon Center. Psycho Shift passes it on.
#   * While the setting is On, Elite Redux's frostbite replaces freezing:
#     anything that would freeze a Pokemon frostbites it instead. Frostbite
#     moves (Ice Punch, Ice Beam, Powder Snow, Blizzard, Freezing Glare) are 3x
#     as likely to frostbite in hail, and Frost Breath gets ER's 30% chance to
#     frostbite (it has no added effect in PIF).
#
# Bleeding (not in ER's public source; from its in-game texts and wiki)
#   * A major status. Loses 1/16 of its max HP at the end of each round
#     (Magic Guard stops it).
#   * It can't heal: no HP from moves, items, abilities, drain, Leftovers...
#     Using a healing move on itself cures the bleeding instead, and the move
#     doesn't heal that turn.
#   * Its stat stages count as 0 (Attack, Defense, Sp. Atk, Sp. Def and Speed
#     when it attacks, is hit or moves; accuracy and evasion too).
#   * Rock and Ghost types can't bleed. Otherwise blocked like other statuses.
#   * Cured by: healing moves (as above), Lum Berry, Full Heal, Heal Bell,
#     Aromatherapy, Natural Cure, Shed Skin, Hydration, Healer, a Pokemon
#     Center. Psycho Shift passes it on.
#
# Both show their own icons (drawn by 012_Graphics) in the battle box (PIF,
# KIF and EBDX), the party screen and the Summary. A saved Pokemon keeps the
# status in its own variable and PIF's status stays :NONE, so a save still
# loads without the mod (the Pokemon is then simply healthy).
#
# Abilities
#   Freezing Point – a hit between it and a foe (its attack or the foe's):
#                    20% chance to frostbite the foe on contact, 30% without
#   Cryomancy      – its moves' frostbite chance x5 (Ice Punch, Ice Beam,
#                    Powder Snow, Blizzard, Freezing Glare, Freeze-Dry, Frost
#                    Breath). Not Freezing Point, not Ice Fang (its one chance
#                    is used for the flinch too) or Tri Attack.
#   Frostbind      – a Pokemon it frostbites also gets its last used move
#                    disabled (as the move Disable); nothing if it hasn't moved
#   Deep Cuts      – its slicing moves (Keen Edge's list) have a 50% chance to
#                    make the target bleed, rolled on each hit
#   Razor Sharp    – its critical hits make the target bleed
#   Mineralize     – its Normal moves become Rock. Rock-type user: its Rock
#                    moves have a 10% chance to make the target bleed; other
#                    users: Rock moves get the 1.5x same-type boost.
#   With "New battle effects" Off these abilities don't cause frostbite or bleeding
#   (Mineralize still changes types), and freezing works as in PIF.
#
# Drench (end of this file)
#   * A drenched Pokemon moves last in its priority bracket for 3 rounds (the
#     round it gets drenched counts). Two drenched ones go by Speed; Trick Room
#     doesn't change it; other brackets aren't affected. It beats Quick Claw,
#     Custap Berry and Quick Draw (they don't trigger while drenched).
#   * Kept on the battler, cleared on switch-out. Already drenched: nothing
#     happens (no refresh, no message).
#   * Caused by Hydrate (021). Amphibious is immune; Shield Dust blocks it.
#     With "New battle effects" Off nothing drenches.
#===============================================================================
KIFER.feature(:frostbite, "Frostbite",
  "Elite Redux's frostbite replaces freezing: HP loss each turn and weaker special moves.")
KIFER.feature(:bleeding, "Bleeding",
  "Elite Redux's bleeding: HP loss each turn, no healing and no stat stages.")

KIFER.er_code(:FREEZINGPOINT, :CRYOMANCY, :FROSTBIND, :DEEPCUTS, :RAZORSHARP, :MINERALIZE)

module KIFER
  module Statuses
    IDS = [:FROSTBITE, :BLEEDING]
    NUMBERS = { :FROSTBITE => 201, :BLEEDING => 202 }   # far past PIF's icon rows

    # Moves whose added effect is ER's "frostbite hit" (3x in hail)
    FROSTBITE_HIT_FUNCS = ["00C", "00D"]
    # Moves Cryomancy boosts (their added effect is only frostbite)
    CRYOMANCY_FUNCS = ["00C", "00D", "135"]

    def self.ours?(status)
      return IDS.include?(status)
    end

    #---------------------------------------------------------------------------
    # Graphics
    #---------------------------------------------------------------------------
    # Icon Bitmap (kind :battle, :summary or :ebdx), or nil for PIF's own statuses
    def self.bitmap(kind, status)
      return nil unless ours?(status)
      return KIFER::Gfx.status(kind, status)
    end

    def self.our_bitmap?(bmp)
      return KIFER::Gfx.ours?(bmp)
    end

    # Draws the icon into `dest` at x, y; false if there is none
    def self.draw_icon(dest, kind, status, x, y)
      bmp = bitmap(kind, status)
      return false unless bmp && dest && !dest.disposed?
      dest.blt(x, y, bmp, Rect.new(0, 0, bmp.width, bmp.height))
      return true
    end

    #---------------------------------------------------------------------------
    # Messages
    #---------------------------------------------------------------------------
    def self.msg_inflict(b, s)
      return (s == :FROSTBITE) ? _INTL("{1} was frostbitten!", b.pbThis) : _INTL("{1} started bleeding!", b.pbThis)
    end

    def self.msg_already(b, s)
      return (s == :FROSTBITE) ? _INTL("{1} is already frostbitten!", b.pbThis) : _INTL("{1} is already bleeding!", b.pbThis)
    end

    def self.msg_cured(name, s)
      return (s == :FROSTBITE) ? _INTL("{1}'s frostbite was healed.", name) : _INTL("{1}'s bleeding stopped.", name)
    end

    def self.msg_hurt(b, s)
      return (s == :FROSTBITE) ? _INTL("{1} was hurt by its frostbite!", b.pbThis) : _INTL("{1} was hurt by bleeding!", b.pbThis)
    end

    def self.msg_immune_ability(b, s, ally = nil)
      if PokeBattle_SceneConstants::USE_ABILITY_SPLASH
        return (s == :FROSTBITE) ? _INTL("{1} cannot be frostbitten!", b.pbThis) : _INTL("{1} cannot bleed!", b.pbThis)
      elsif ally
        return (s == :FROSTBITE) ?
          _INTL("{1} cannot be frostbitten because of {2}'s {3}!", b.pbThis, ally.pbThis(true), ally.abilityName) :
          _INTL("{1} cannot bleed because of {2}'s {3}!", b.pbThis, ally.pbThis(true), ally.abilityName)
      end
      return (s == :FROSTBITE) ? _INTL("{1}'s {2} prevents frostbite!", b.pbThis, b.abilityName) :
                                 _INTL("{1}'s {2} prevents bleeding!", b.pbThis, b.abilityName)
    end

    #---------------------------------------------------------------------------
    # Can it be inflicted? (PIF's pbCanInflictStatus? for the new statuses)
    #---------------------------------------------------------------------------
    def self.can_inflict?(b, status, user, show, move = nil, ignore_status = false)
      return false if b.fainted?
      battle = b.battle
      self_inflicted = (user && user.index == b.index)
      if b.status == status && !ignore_status
        battle.pbDisplay(msg_already(b, status)) if show
        return false
      end
      if b.status != :NONE && !ignore_status && !self_inflicted
        battle.pbDisplay(_INTL("It doesn't affect {1}...", b.pbThis(true))) if show
        return false
      end
      if b.effects[PBEffects::Substitute] > 0 && !(move && move.ignoresSubstitute?(user)) &&
         !self_inflicted
        battle.pbDisplay(_INTL("It doesn't affect {1}...", b.pbThis(true))) if show
        return false
      end
      if b.affectedByTerrain? && battle.field.terrain == :Misty
        battle.pbDisplay(_INTL("{1} surrounds itself with misty terrain!", b.pbThis(true))) if show
        return false
      end
      immune_type = (status == :FROSTBITE) ? b.pbHasType?(:ICE) : (b.pbHasType?(:ROCK) || b.pbHasType?(:GHOST))
      if immune_type
        battle.pbDisplay(_INTL("It doesn't affect {1}...", b.pbThis(true))) if show
        return false
      end
      immune = false; ally = nil
      if BattleHandlers.triggerStatusImmunityAbilityNonIgnorable(b.ability, b, status)
        immune = true
      elsif self_inflicted || !battle.moldBreaker
        if b.abilityActive? && BattleHandlers.triggerStatusImmunityAbility(b.ability, b, status)
          immune = true
        else
          b.eachAlly do |a|
            next if !a.abilityActive?
            next if !BattleHandlers.triggerStatusImmunityAllyAbility(a.ability, b, status)
            immune = true
            ally = a
            break
          end
        end
      end
      if immune
        if show
          battle.pbShowAbilitySplash(ally || b)
          battle.pbDisplay(msg_immune_ability(b, status, ally))
          battle.pbHideAbilitySplash(ally || b)
        end
        return false
      end
      # ER: Safeguard also stops frostbite from an ability (no move)
      if b.pbOwnSide.effects[PBEffects::Safeguard] > 0 && !self_inflicted &&
         ((move && !(user && user.hasActiveAbility?(:INFILTRATOR))) || (!move && status == :FROSTBITE))
        battle.pbDisplay(_INTL("{1}'s team is protected by Safeguard!", b.pbThis)) if show
        return false
      end
      return true
    end

    #---------------------------------------------------------------------------
    # Frostbind: the frostbitten Pokemon's last move gets disabled
    #---------------------------------------------------------------------------
    def self.frostbind(user, target)
      return if !user || user.index == target.index || target.fainted?
      return if !user.hasActiveAbility?(:FROSTBIND)
      return if target.effects[PBEffects::Disable] > 0 || !target.lastRegularMoveUsed
      ok = false
      target.eachMove do |m|
        next if m.id != target.lastRegularMoveUsed
        next if m.pp == 0 && m.total_pp > 0
        ok = true
        break
      end
      return if !ok
      battle = target.battle
      battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(:FROSTBIND))
      target.effects[PBEffects::Disable]     = 5   # as the move Disable (4 more turns)
      target.effects[PBEffects::DisableMove] = target.lastRegularMoveUsed
      battle.pbDisplay(_INTL("{1}'s {2} was disabled!", target.pbThis,
                             GameData::Move.get(target.lastRegularMoveUsed).name))
      battle.pbHideAbilitySplash(user)
      target.pbItemStatusCureCheck
    end

    #---------------------------------------------------------------------------
    # End of round damage (just after the status damage of PIF's round)
    #---------------------------------------------------------------------------
    def self.frostbite_damage(battler)
      return [battler.totalhp / 8, 1].max
    end

    def self.eor_damage(battle, priority)
      IDS.each do |s|
        priority.each do |b|
          next if b.fainted? || b.status != s || !b.takesIndirectDamage?
          oldHP = b.hp
          dmg = (s == :FROSTBITE) ? frostbite_damage(b) : [b.totalhp / 16, 1].max
          anim = GameData::Status.get(s).animation
          battle.pbCommonAnimation(anim, b) if anim
          b.pbReduceHP(dmg, false)
          battle.pbDisplay(msg_hurt(b, s))
          b.pbItemHPHealCheck
          b.pbAbilitiesOnDamageTaken(oldHP)
          b.pbFaint if b.fainted?
        end
      end
    end

    #---------------------------------------------------------------------------
    # Thawing moves cure frostbite (user before it moves, targets it hits)
    #---------------------------------------------------------------------------
    def self.self_thaw(user, move)
      return if !user || user.status != :FROSTBITE || !move.thawsUser?
      user.pbCureStatus(false)
      user.battle.pbDisplay(msg_cured(user.pbThis, :FROSTBITE))
    end

    def self.thaw_targets(user, targets, move)
      return if !move.damagingMove? || !move.thawsUser?
      targets.each do |b|
        next if b.index == user.index || b.fainted? || b.status != :FROSTBITE
        next if b.damageState.unaffected || b.damageState.substitute
        b.pbCureStatus
      end
    end

    #---------------------------------------------------------------------------
    # Bleeding: a healing move on itself cures it and doesn't heal
    #---------------------------------------------------------------------------
    def self.bleed_heal_cure(move, user)
      return false if !user || user.status != :BLEEDING || !move.healingMove?
      return false if ["0E3", "0E4"].include?(move.function)   # Healing Wish / Lunar Dance heal the next Pokemon
      return false if move.function == "114" && user.effects[PBEffects::Stockpile] == 0   # Swallow fails as usual
      t = move.pbTarget(user)
      return false unless t && [:User, :UserAndAllies].include?(t.id)
      user.pbCureStatus
      return true
    end

    def self.hook_heal_moves
      ObjectSpace.each_object(Class).select { |c| c < PokeBattle_Move }.each do |c|
        next if c.instance_method(:healingMove?).owner == PokeBattle_Move
        next unless c.instance_method(:pbMoveFailed?).owner == c
        orig = :"kifer_st_mf_#{c.name}"
        next if c.method_defined?(orig)
        c.send(:alias_method, orig, :pbMoveFailed?)
        c.send(:define_method, :pbMoveFailed?) do |user, targets|
          return true if KIFER::Statuses.bleed_heal_cure(self, user)
          next send(orig, user, targets)
        end
      end
    rescue StandardError => e
      KIFER.log("healing moves not hooked: #{e.class}: #{e.message}")
    end

    # Stat stages of bleeding battlers count as 0 while the block runs
    def self.without_stages(battlers)
      saved = []
      battlers.uniq.each do |b|
        next if !b || b.status != :BLEEDING || !b.stages
        saved << [b, b.stages.dup]
        b.stages.each_key { |k| b.stages[k] = 0 }
      end
      begin
        return yield
      ensure
        saved.each { |b, st| st.each { |k, v| b.stages[k] = v } }
      end
    end
  end
end

#===============================================================================
# Status data. PIF finds its fainted / Pokerus / toxic icon rows from the
# number of GameData::Status keys, so the new ones are left out of DATA.keys
# (Status.each still lists them).
#===============================================================================
KIFER::Statuses::IDS.each do |sid|
  next if GameData::Status.exists?(sid)
  GameData::Status.register({
    :id        => sid,
    :id_number => KIFER::Statuses::NUMBERS[sid],
    :name      => (sid == :FROSTBITE) ? _INTL("Frostbite") : _INTL("Bleeding"),
    :animation => (sid == :FROSTBITE) ? "Frozen" : nil
  })
end

class << GameData::Status::DATA
  alias_method :kifer_st_keys, :keys unless method_defined?(:kifer_st_keys)
  def keys
    ks = kifer_st_keys
    KIFER::Statuses::IDS.each do |sid|
      next unless has_key?(sid)
      ks.delete(sid)
      ks.delete(KIFER::Statuses::NUMBERS[sid])
    end
    return ks
  end
end

class << GameData::Status
  alias_method :kifer_st_each, :each unless method_defined?(:kifer_st_each)
  def each(&block)
    kifer_st_each(&block)
    KIFER::Statuses::IDS.each { |sid| block.call(self::DATA[sid]) if self::DATA[sid] }
  end
end

#===============================================================================
# Pokemon: the new statuses live in their own variable (PIF's @status stays
# :NONE), so saves load without the mod
#===============================================================================
class Pokemon
  alias kifer_st_status status unless method_defined?(:kifer_st_status)
  alias kifer_st_set_status status= unless method_defined?(:kifer_st_set_status)
  alias kifer_st_heal_status heal_status unless method_defined?(:kifer_st_heal_status)

  def status
    s = kifer_st_status
    if (s.nil? || s == :NONE) && @kifer_st_status
      # Unregistered (e.g. data missing): counts as healthy
      return @kifer_st_status if GameData::Status::DATA.has_key?(@kifer_st_status)
    end
    return s
  end

  def status=(value)
    st = GameData::Status.try_get(value)
    if st && KIFER::Statuses.ours?(st.id)
      return if !able?
      kifer_st_set_status(:NONE)
      @kifer_st_status = st.id
      return
    end
    kifer_st_set_status(value)
    @kifer_st_status = nil if able?
  end

  def heal_status
    kifer_st_heal_status
    @kifer_st_status = nil unless egg?
  end
end

#===============================================================================
# Battler
#===============================================================================
class PokeBattle_Battler
  alias kifer_st_pbCanInflictStatus? pbCanInflictStatus? unless method_defined?(:kifer_st_pbCanInflictStatus?)
  alias kifer_st_pbCanFreeze? pbCanFreeze? unless method_defined?(:kifer_st_pbCanFreeze?)
  alias kifer_st_pbFreeze pbFreeze unless method_defined?(:kifer_st_pbFreeze)
  alias kifer_st_pbCureStatus pbCureStatus unless method_defined?(:kifer_st_pbCureStatus)
  alias kifer_st_canHeal? canHeal? unless method_defined?(:kifer_st_canHeal?)
  alias kifer_st_pbRecoverHP pbRecoverHP unless method_defined?(:kifer_st_pbRecoverHP)
  alias kifer_st_pbSpeed pbSpeed unless method_defined?(:kifer_st_pbSpeed)
  alias kifer_st_pbEffectsAfterMove pbEffectsAfterMove unless method_defined?(:kifer_st_pbEffectsAfterMove)

  def frostbitten?; return pbHasStatus?(:FROSTBITE); end
  def bleeding?;    return pbHasStatus?(:BLEEDING);  end

  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
    if KIFER::Statuses.ours?(newStatus)
      return KIFER::Statuses.can_inflict?(self, newStatus, user, showMessages, move, ignoreStatus)
    end
    return kifer_st_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
  end

  def pbCanFrostbite?(user, showMessages, move = nil)
    return KIFER::Statuses.can_inflict?(self, :FROSTBITE, user, showMessages, move)
  end

  def pbFrostbite(user = nil, msg = nil)
    pbInflictStatus(:FROSTBITE, 0, (msg && !msg.empty?) ? msg : KIFER::Statuses.msg_inflict(self, :FROSTBITE), user)
    KIFER::Statuses.frostbind(user, self)
  end

  def pbCanBleed?(user, showMessages, move = nil)
    return KIFER::Statuses.can_inflict?(self, :BLEEDING, user, showMessages, move)
  end

  def pbBleed(user = nil, msg = nil)
    pbInflictStatus(:BLEEDING, 0, (msg && !msg.empty?) ? msg : KIFER::Statuses.msg_inflict(self, :BLEEDING), user)
  end

  # ER: frostbite replaces freezing (while the setting is On)
  def pbCanFreeze?(user, showMessages, move = nil)
    if KIFER.feature_on?(:frostbite)
      @kifer_st_freezer = user
      return pbCanFrostbite?(user, showMessages, move)
    end
    return kifer_st_pbCanFreeze?(user, showMessages, move)
  end

  def pbFreeze(msg = nil)
    if KIFER.feature_on?(:frostbite)
      user = @kifer_st_freezer
      @kifer_st_freezer = nil
      return pbFrostbite(user)
    end
    return kifer_st_pbFreeze(msg)
  end

  def pbCureStatus(showMessages = true)
    old = @status
    kifer_st_pbCureStatus(showMessages)
    if showMessages && KIFER::Statuses.ours?(old)
      @battle.pbDisplay(KIFER::Statuses.msg_cured(pbThis, old))
    end
  end

  # Bleeding: no healing
  def canHeal?
    return false if @status == :BLEEDING
    return kifer_st_canHeal?
  end

  def pbRecoverHP(amt, anim = true, anyAnim = true)
    return 0 if @status == :BLEEDING
    return kifer_st_pbRecoverHP(amt, anim, anyAnim)
  end

  # Bleeding: Speed stages count as 0
  def pbSpeed
    return kifer_st_pbSpeed if @status != :BLEEDING || !@stages
    old = @stages[:SPEED]
    @stages[:SPEED] = 0
    begin
      return kifer_st_pbSpeed
    ensure
      @stages[:SPEED] = old
    end
  end

  def pbEffectsAfterMove(user, targets, move, numHits)
    begin
      KIFER::Statuses.thaw_targets(user, targets, move)
    rescue StandardError => e
      KIFER.log("frostbite thaw failed: #{e.class}: #{e.message}")
    end
    kifer_st_pbEffectsAfterMove(user, targets, move, numHits)
  end
end

#===============================================================================
# Moves
#===============================================================================
class PokeBattle_Move
  alias kifer_st_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_st_pbCalcDamageMultipliers)
  alias kifer_st_pbCalcDamage pbCalcDamage unless method_defined?(:kifer_st_pbCalcDamage)
  alias kifer_st_pbCalcAccuracyModifiers pbCalcAccuracyModifiers unless method_defined?(:kifer_st_pbCalcAccuracyModifiers)
  alias kifer_st_pbAdditionalEffectChance pbAdditionalEffectChance unless method_defined?(:kifer_st_pbAdditionalEffectChance)
  alias kifer_st_pbDisplayUseMessage pbDisplayUseMessage unless method_defined?(:kifer_st_pbDisplayUseMessage)

  # Frostbite halves its special moves (Guts ignores it)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    kifer_st_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    if user.status == :FROSTBITE && specialMove? && !user.hasActiveAbility?(:GUTS) &&
       !user.hasActiveAbility?(:DETERMINATION)
      multipliers[:final_damage_multiplier] /= 2
    end
  end

  # Bleeding: the attacker's and target's stat stages count as 0
  def pbCalcDamage(user, target, numTargets = 1)
    ret = KIFER::Statuses.without_stages([user, target]) { kifer_st_pbCalcDamage(user, target, numTargets) }
    return ret
  end

  def pbCalcAccuracyModifiers(user, target, modifiers)
    kifer_st_pbCalcAccuracyModifiers(user, target, modifiers)
    modifiers[:accuracy_stage] = 0 if user.status == :BLEEDING
    modifiers[:evasion_stage]  = 0 if target.status == :BLEEDING
  end

  # Frostbite chances: x3 in hail (ER's frostbite moves), x5 with Cryomancy
  def pbAdditionalEffectChance(user, target, effectChance = 0)
    ret = kifer_st_pbAdditionalEffectChance(user, target, effectChance)
    return ret if ret <= 0 || !KIFER.feature_on?(:frostbite)
    if (KIFER::Statuses::FROSTBITE_HIT_FUNCS.include?(@function) || @id == :FROSTBREATH) &&
       @battle.pbWeather == :Hail
      ret *= 3
    end
    if (KIFER::Statuses::CRYOMANCY_FUNCS.include?(@function) || @id == :FROSTBREATH) &&
       user.hasActiveAbility?(:CRYOMANCY)
      ret *= 5
    end
    return ret
  end

  # A frostbitten Pokemon using a thawing move is cured first
  def pbDisplayUseMessage(user)
    kifer_st_pbDisplayUseMessage(user)
    KIFER::Statuses.self_thaw(user, self)
  end
end

KIFER::Statuses.hook_heal_moves

# Facade: x2 while frostbitten too
class PokeBattle_Move_07E
  alias kifer_st_pbBaseDamage pbBaseDamage unless method_defined?(:kifer_st_pbBaseDamage)
  def pbBaseDamage(baseDmg, user, target)
    ret = kifer_st_pbBaseDamage(baseDmg, user, target)
    ret *= 2 if user.status == :FROSTBITE
    return ret
  end
end

# Refresh: cures frostbite too (ER)
class PokeBattle_Move_018
  alias kifer_st_pbMoveFailed? pbMoveFailed? unless method_defined?(:kifer_st_pbMoveFailed?)
  alias kifer_st_pbEffectGeneral pbEffectGeneral unless method_defined?(:kifer_st_pbEffectGeneral)
  def pbMoveFailed?(user, targets)
    return false if user.status == :FROSTBITE
    return kifer_st_pbMoveFailed?(user, targets)
  end

  def pbEffectGeneral(user)
    if user.status == :FROSTBITE
      user.pbCureStatus(false)
      @battle.pbDisplay(_INTL("{1} healed its frostbite!", user.pbThis))
      return
    end
    kifer_st_pbEffectGeneral(user)
  end
end

# Heal Bell / Aromatherapy: message for the new statuses
class PokeBattle_Move_019
  alias kifer_st_pbAromatherapyHeal pbAromatherapyHeal unless method_defined?(:kifer_st_pbAromatherapyHeal)
  def pbAromatherapyHeal(pkmn, battler = nil)
    old = (battler) ? battler.status : pkmn.status
    name = (battler) ? battler.pbThis : pkmn.name
    kifer_st_pbAromatherapyHeal(pkmn, battler)
    @battle.pbDisplay(KIFER::Statuses.msg_cured(name, old)) if KIFER::Statuses.ours?(old)
  end
end

# Psycho Shift passes the new statuses on
class PokeBattle_Move_01B
  alias kifer_st_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_st_pbEffectAgainstTarget)
  def pbEffectAgainstTarget(user, target)
    old = user.status
    return kifer_st_pbEffectAgainstTarget(user, target) unless KIFER::Statuses.ours?(old)
    (old == :FROSTBITE) ? target.pbFrostbite(user) : target.pbBleed(user)
    user.pbCureStatus(false)
    @battle.pbDisplay(KIFER::Statuses.msg_cured(user.pbThis, old))
  end
end

#===============================================================================
# End of round damage: at the first countdown of the round (Taunt), right
# after PIF's status damage
#===============================================================================
class PokeBattle_Battle
  alias kifer_st_pbEORCountDownBattlerEffect pbEORCountDownBattlerEffect unless method_defined?(:kifer_st_pbEORCountDownBattlerEffect)
  def pbEORCountDownBattlerEffect(*args, &block)
    if @kifer_st_eor_turn != @turnCount
      @kifer_st_eor_turn = @turnCount
      begin
        KIFER::Statuses.eor_damage(self, args[0]) if args[0].is_a?(Array)
      rescue StandardError => e
        KIFER.log("status damage failed: #{e.class}: #{e.message}")
      end
    end
    return kifer_st_pbEORCountDownBattlerEffect(*args, &block)
  end
end

#===============================================================================
# Abilities, berries and items that cure or block
#===============================================================================
module KIFER
  module Statuses
    def self.wrap_handler(hash, id, &block)
      old = hash[id]
      hash.add(id, proc { |*args| block.call(old, *args) })
    end
  end
end

unless defined?(KIFER::Statuses::HANDLERS_DONE)
  KIFER::Statuses::HANDLERS_DONE = true

  # Bleeding: an HP item on the battler can't heal it, so it isn't used up
  [:POTION, :SUPERPOTION, :HYPERPOTION, :MAXPOTION, :BERRYJUICE, :SWEETHEART, :FRESHWATER,
   :SODAPOP, :LEMONADE, :MOOMOOMILK, :ORANBERRY, :SITRUSBERRY, :ENERGYPOWDER, :ENERGYROOT].each do |item|
    next if !ItemHandlers::CanUseInBattle[item]
    KIFER::Statuses.wrap_handler(ItemHandlers::CanUseInBattle, item) do |old, it, pokemon, battler, move, first, battle, scene, show|
      if battler && battler.status == :BLEEDING
        scene.pbDisplay(_INTL("It won't have any effect.")) if show && scene
        next false
      end
      next old.call(it, pokemon, battler, move, first, battle, scene, show)
    end
  end

  # Magma Armor: no frostbite, and cures it
  KIFER::Statuses.wrap_handler(BattleHandlers::StatusImmunityAbility, :MAGMAARMOR) do |old, ability, battler, status|
    next true if status == :FROSTBITE
    next old ? old.call(ability, battler, status) : false
  end

  KIFER::Statuses.wrap_handler(BattleHandlers::StatusCureAbility, :MAGMAARMOR) do |old, ability, battler|
    if battler.status == :FROSTBITE
      battler.battle.pbShowAbilitySplash(battler)
      battler.pbCureStatus(true)
      battler.battle.pbHideAbilitySplash(battler)
      next
    end
    old.call(ability, battler) if old
  end

  # Aspear Berry: cures frostbite
  KIFER::Statuses.wrap_handler(BattleHandlers::StatusCureItem, :ASPEARBERRY) do |old, item, battler, battle, forced|
    if battler.status == :FROSTBITE
      next false if !forced && !battler.canConsumeBerry?
      itemName = GameData::Item.get(item).name
      battle.pbCommonAnimation("EatBerry", battler) if !forced
      battler.pbCureStatus(forced)
      battle.pbDisplay(_INTL("{1}'s {2} healed its frostbite!", battler.pbThis, itemName)) if !forced
      next true
    end
    next old ? old.call(item, battler, battle, forced) : false
  end

  # Lum Berry: message for the new statuses
  KIFER::Statuses.wrap_handler(BattleHandlers::StatusCureItem, :LUMBERRY) do |old, item, battler, battle, forced|
    st = battler.status
    ret = old ? old.call(item, battler, battle, forced) : false
    if ret && !forced && KIFER::Statuses.ours?(st)
      itemName = GameData::Item.get(item).name
      battle.pbDisplay((st == :FROSTBITE) ?
        _INTL("{1}'s {2} healed its frostbite!", battler.pbThis, itemName) :
        _INTL("{1}'s {2} stopped its bleeding!", battler.pbThis, itemName))
    end
    next ret
  end

  # Ice Heal (and Aspear Berry from the bag): cure frostbite
  [:ICEHEAL, :ASPEARBERRY].each do |iid|
    KIFER::Statuses.wrap_handler(ItemHandlers::UseOnPokemon, iid) do |old, item, pkmn, scene|
      if !pkmn.fainted? && pkmn.status == :FROSTBITE
        pkmn.heal_status
        scene.pbRefresh
        scene.pbDisplay(KIFER::Statuses.msg_cured(pkmn.name, :FROSTBITE))
        next true
      end
      next old ? old.call(item, pkmn, scene) : false
    end
    KIFER::Statuses.wrap_handler(ItemHandlers::BattleUseOnPokemon, iid) do |old, item, pokemon, battler, choices, scene|
      if pokemon.status == :FROSTBITE
        pokemon.heal_status
        battler.pbCureStatus(false) if battler
        name = (battler) ? battler.pbThis : pokemon.name
        scene.pbRefresh
        scene.pbDisplay(KIFER::Statuses.msg_cured(name, :FROSTBITE))
        next
      end
      old.call(item, pokemon, battler, choices, scene) if old
    end
  end
end

alias kifer_st_pbBattleItemCanCureStatus? pbBattleItemCanCureStatus? unless defined?(kifer_st_pbBattleItemCanCureStatus?)
def pbBattleItemCanCureStatus?(status, pkmn, scene, showMessages)
  return true if status == :FROZEN && pkmn.able? && pkmn.status == :FROSTBITE
  return kifer_st_pbBattleItemCanCureStatus?(status, pkmn, scene, showMessages)
end

#===============================================================================
# Ability handlers
#===============================================================================
module KIFER
  module Statuses
    def self.cause_bleed(user, target, move, ability, chance)
      return if !KIFER.feature_on?(:bleeding) || target.fainted?
      return if chance < 100 && user.battle.pbRandom(100) >= chance
      return if target.hasActiveAbility?(:SHIELDDUST) && !user.battle.moldBreaker
      return if !target.pbCanBleed?(user, false, move)
      battle = user.battle
      battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability))
      target.pbBleed(user)
      battle.pbHideAbilitySplash(user)
    end
  end
end

#-------------------------------------------------------------------------------
# Freezing Point – its hits, and hits on it: 20% frostbite on contact, else 30%
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:FREEZINGPOINT,
  proc { |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_user(ability, user, target, move, :FROSTBITE, 20, 30)
  }
)

BattleHandlers::TargetAbilityOnHit.add(:FREEZINGPOINT,
  proc { |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_target(ability, user, target, move, :FROSTBITE, 20, 30)
  }
)

#-------------------------------------------------------------------------------
# Deep Cuts – slicing moves: 50% bleed, each hit
# Razor Sharp – critical hits: bleed
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:DEEPCUTS,
  proc { |ability, user, target, move, battle|
    next unless KIFER::SLICING_MOVES.include?(move.id)
    KIFER::Statuses.cause_bleed(user, target, move, ability, 50)
  }
)

BattleHandlers::UserAbilityOnHit.add(:RAZORSHARP,
  proc { |ability, user, target, move, battle|
    next unless target.damageState.critical
    KIFER::Statuses.cause_bleed(user, target, move, ability, 100)
  }
)

#-------------------------------------------------------------------------------
# Mineralize – Normal moves become Rock. Rock-type user: Rock moves 10% bleed;
# other users: Rock STAB.
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.add(:MINERALIZE,
  proc { |ability, user, move, type|
    next type if type != :NORMAL || !GameData::Type.exists?(:ROCK)
    next :ROCK
  }
)

BattleHandlers::DamageCalcUserAbility.add(:MINERALIZE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if type != :ROCK || !KIFER::BatchF.ability_stab?(user, type)
    mults[:final_damage_multiplier] *= KIFER::BatchF.stab_mult(user)
  }
)

BattleHandlers::UserAbilityOnHit.add(:MINERALIZE,
  proc { |ability, user, target, move, battle|
    next if move.calcType != :ROCK || !user.pbHasType?(:ROCK)
    KIFER::Statuses.cause_bleed(user, target, move, ability, 10)
  }
)

#-------------------------------------------------------------------------------
# Frost Breath: ER's 30% frostbite (each hit; Sheer Force removes it)
#-------------------------------------------------------------------------------
class PokeBattle_Battler
  alias kifer_st_pbEffectsOnMakingHit pbEffectsOnMakingHit unless method_defined?(:kifer_st_pbEffectsOnMakingHit)
  def pbEffectsOnMakingHit(move, user, target)
    kifer_st_pbEffectsOnMakingHit(move, user, target)
    return unless move.id == :FROSTBREATH && KIFER.feature_on?(:frostbite)
    return if target.fainted? || target.damageState.substitute || target.damageState.calcDamage <= 0
    return if user.hasActiveAbility?(:SHEERFORCE)
    chance = move.pbAdditionalEffectChance(user, target, 30)
    return if chance <= 0 || @battle.pbRandom(100) >= chance
    target.pbFrostbite(user) if target.pbCanFrostbite?(user, false, move)
  end
end

#===============================================================================
# Icons: battle box (PIF / KIF / EBDX), party, Summary
#===============================================================================
class PokemonDataBox
  if method_defined?(:kif_refresh_status)
    # KIF draws the status icon with its own sprite
    alias kifer_st_kif_refresh_status kif_refresh_status unless method_defined?(:kifer_st_kif_refresh_status)
    def kif_refresh_status
      st = (@battler && @battler.respond_to?(:status)) ? @battler.status : :NONE
      bmp = KIFER::Statuses.bitmap(:battle, st)
      if @kif_statusIcon && bmp
        @kif_statusIcon.bitmap = bmp
        @kif_statusIcon.src_rect.set(0, 0, bmp.width, bmp.height)
        return
      end
      if @kif_statusIcon && @kif_statusBitmap && @kif_statusIcon.bitmap != @kif_statusBitmap.bitmap
        @kif_statusIcon.bitmap = @kif_statusBitmap.bitmap
      end
      kifer_st_kif_refresh_status
    end
  else
    alias kifer_st_refresh refresh unless method_defined?(:kifer_st_refresh)
    def refresh
      kifer_st_refresh
      return if !@battler || !@battler.respond_to?(:status)
      KIFER::Statuses.draw_icon(self.bitmap, :battle, @battler.status, @spriteBaseX + 24, 56)
    end
  end
end

if defined?(DataBoxEBDX)
  class DataBoxEBDX
    alias kifer_st_update update unless method_defined?(:kifer_st_update)
    def update
      kifer_st_update
      begin
        spr = @sprites && @sprites["status"]
        return if !spr || spr.disposed? || !@battler || !@battler.respond_to?(:status)
        bmp = KIFER::Statuses.bitmap(:ebdx, @battler.status)
        if bmp
          @kifer_st_orig = spr.bitmap unless KIFER::Statuses.our_bitmap?(spr.bitmap)
          spr.bitmap = bmp if spr.bitmap != bmp
          spr.src_rect.set(0, 0, bmp.width, bmp.height)
        elsif @kifer_st_orig && KIFER::Statuses.our_bitmap?(spr.bitmap) && !@kifer_st_orig.disposed?
          h = spr.src_rect.height
          spr.bitmap = @kifer_st_orig
          spr.src_rect.set(0, 0, 0, h)
        end
      rescue StandardError => e
        KIFER.log("EBDX status icon failed: #{e.class}: #{e.message}")
      end
    end
  end
end

class PokemonPartyPanel
  alias kifer_st_refresh refresh unless method_defined?(:kifer_st_refresh)
  def refresh
    redraw = @refreshBitmap
    kifer_st_refresh
    begin
      return if !redraw || disposed? || !@pokemon || @pokemon.egg? || @pokemon.fainted?
      return if !KIFER::Statuses.ours?(@pokemon.status)
      return if !@overlaysprite || @overlaysprite.disposed? || !@overlaysprite.bitmap
      pos = [78, 68]
      big = defined?(KIF::BigIcons) && KIF::BigIcons.respond_to?(:party_layout?) &&
            KIF::BigIcons.party_layout?(@pokemon, @text)
      pos = KIF::BigIcons::PARTY_STATUS_POS if big
      KIFER::Statuses.draw_icon(@overlaysprite.bitmap, :summary, @pokemon.status, pos[0], pos[1])
      if big && defined?(KIF.draw_evolock_icon) && @pokemon.respond_to?(:kif_evo_locked?) &&
         @pokemon.kif_evo_locked?
        KIF.draw_evolock_icon(@overlaysprite.bitmap, *KIF::BigIcons::PARTY_LOCK_POS)
      end
    rescue StandardError => e
      KIFER.log("party status icon failed: #{e.class}: #{e.message}")
    end
  end
end

class PokemonSummary_Scene
  alias kifer_st_drawPage drawPage unless method_defined?(:kifer_st_drawPage)
  def drawPage(page)
    kifer_st_drawPage(page)
    begin
      return if !@pokemon || @pokemon.egg? || @pokemon.fainted?
      return if respond_to?(:kifer_tab?, true) && kifer_tab? && @kifer_vpage == 4
      return if !KIFER::Statuses.ours?(@pokemon.status) || !@sprites || !@sprites["overlay"]
      KIFER::Statuses.draw_icon(@sprites["overlay"].bitmap, :summary, @pokemon.status, 124, 100)
    rescue StandardError => e
      KIFER.log("summary status icon failed: #{e.class}: #{e.message}")
    end
  end
end

#===============================================================================
# Drench: moves last in its priority bracket for 3 rounds
#===============================================================================
KIFER.feature(:drench, "Drench",
  "A drenched Pokemon moves last in its priority bracket for 3 turns.")

module KIFER
  module Drench
    TURNS = 3
    SUB_PRIORITY = -100   # under Lagging Tail and Stall (-1)

    def self.drenched?(b)
      return !!b && !b.fainted? && b.kifer_drench > 0
    end

    # A chance effect of its attack; true if the target got drenched
    def self.on_hit(user, target, ability, chance)
      return false if KIFER.ai_thinking? || !KIFER.feature_on?(:drench)
      return false if target.fainted? || user.equal?(target) || target.kifer_drench > 0
      battle = user.battle
      return false if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      return false if target.hasActiveAbility?(:AMPHIBIOUS) && !battle.moldBreaker
      return false if chance < 100 && battle.pbRandom(100) >= chance
      battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(ability)) if ability   # nil: a move's effect
      target.kifer_drench = TURNS
      battle.pbDisplay(_INTL("{1} got drenched!", target.pbThis))
      battle.pbHideAbilitySplash(user) if ability
      return true
    end
  end
end

class PokeBattle_Battler
  attr_writer :kifer_drench

  def kifer_drench
    return @kifer_drench || 0
  end

  alias kifer_drench_pbInitEffects pbInitEffects unless method_defined?(:kifer_drench_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_drench_pbInitEffects(batonPass)
    @kifer_drench = 0
  end
end

class PokeBattle_Battle
  alias kifer_drench_pbEndOfRoundPhase pbEndOfRoundPhase unless method_defined?(:kifer_drench_pbEndOfRoundPhase)
  def pbEndOfRoundPhase
    kifer_drench_pbEndOfRoundPhase
    return if @decision > 0
    eachBattler do |b|
      next if b.kifer_drench <= 0
      b.kifer_drench -= 1
      pbDisplay(_INTL("{1} dried off.", b.pbThis)) if b.kifer_drench == 0
    end
  end

  # Drenched move users get the lowest sub-priority, so they go after everyone
  # else in their bracket (PIF compares sub-priority before Speed and Trick Room)
  alias kifer_drench_pbCalculatePriority pbCalculatePriority unless method_defined?(:kifer_drench_pbCalculatePriority)
  def pbCalculatePriority(fullCalc = false, indexArray = nil)
    kifer_drench_pbCalculatePriority(fullCalc, indexArray)
    changed = false
    @priority.each do |a|
      b = a[0]
      next if a[2] == KIFER::Drench::SUB_PRIORITY || !KIFER::Drench.drenched?(b)
      next if @choices[b.index][0] != :UseMove
      a[2] = KIFER::Drench::SUB_PRIORITY
      b.effects[PBEffects::PriorityAbility] = false
      b.effects[PBEffects::PriorityItem]    = false
      changed = true
    end
    return if !changed
    # PIF re-sorts with its own rules when its cached Trick Room flag looks
    # stale, and sets the flag back itself
    @priorityTrickRoom = !@priorityTrickRoom
    kifer_drench_pbCalculatePriority(false, [])
  end
end
