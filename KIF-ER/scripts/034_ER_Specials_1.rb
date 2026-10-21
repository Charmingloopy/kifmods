#===============================================================================
# KIF: Elite Redux – Elite Redux abilities that each need something of their own
#   Mechanics follow Elite Redux 2.65 (its C source first, then its in-game
#   texts where the public source doesn't have the ability).
#
#   Poseidon's Dominion – on entry: uses Whirlpool (ER's 50 power) on a foe
#                         next to it. Whirlpool traps it 4-5 turns, 1/8 HP a
#                         turn, as PIF's Whirlpool does.
#   Revelation       – Unown (or a fusion with an Unown half): on entry and at
#                      the end of each turn, it takes its Revelation form while
#                      above 1/4 HP and goes back at 1/4 HP or less (like
#                      Schooling). PIF has no Revelation sprite or species, so
#                      the form is its stats only: the Unown half's base stats
#                      become ER's Unown Revelation (Atk 138, Def 133, Sp. Atk
#                      138, Sp. Def 133, Speed 30). Max HP, type, sprite and
#                      innates stay as they are. Any other Pokemon: nothing.
#   Neutralizing Gas – while it is on the field, every ability and innate of
#                      every Pokemon (its own too) is off, except ones that
#                      can't be stopped (Schooling, Disguise, Zen Mode...)
#                      and those of a Stalwart Pokemon (033).
#                      When it switches out, the gas ends and the others' entry
#                      abilities trigger again. It can't be copied (Trace,
#                      Role Play) or swapped.
#   Tag              – when a foe switches out (its own choice), it hits the
#                      foe with a 20 power Pursuit first (always 20: the text
#                      gives the power for the switch case). Not while asleep
#                      or frozen, and not if it already used Pursuit on it.
#   Temporal Rupture – its Roar of Time: 100 power, no recharge turn, and the
#                      target's ability becomes Slow Start (PIF's Slow Start:
#                      Attack and Speed halved for 5 turns). Not on abilities
#                      that can't be changed, Truant, or through a Substitute.
#                      (PIF's Roar of Time already has 0 priority and doesn't
#                      force a switch.)
#   Inversion        – on entry: Inverse Room for 3 turns (not if it's up).
#                      Under Inverse Room the type chart is reversed: super
#                      effective -> not very, not very and no effect -> super.
#                      Things that already change a matchup (Foresight, Ring
#                      Target, a grounded Flying type vs Ground, abilities)
#                      keep their result. Uses the "New battle effects" setting.
#   Discipline       – a rampage move (Outrage, Thrash, Petal Dance) doesn't
#                      lock it in or confuse it: it is locked into that move
#                      like a Choice item for 3 turn ends (ER's counter) and
#                      can switch out. Can't be confused; Intimidate and Scare
#                      don't affect it; gaining it cures its confusion.
#===============================================================================
KIFER.feature(:inverse_room, "Inverse Room",
  "Reverses the type chart for 3 turns: weaknesses become resistances.")

KIFER.er_code(:POSEIDONSDOMINION, :REVELATION, :NEUTRALIZINGGAS, :TAG,
                :TEMPORALRUPTURE, :INVERSION, :DISCIPLINE)

module KIFER
  module Specials1
    # ER's Unown Revelation (HP isn't used: max HP stays the same)
    REVELATION_BASE = { :ATTACK => 138, :DEFENSE => 133, :SPECIAL_ATTACK => 138,
                        :SPECIAL_DEFENSE => 133, :SPEED => 30 }
    INVERSE_TURNS   = 3
    DISCIPLINE_TURNS = 3
    TAG_POWER       = 20
    WHIRLPOOL_POWER = 50
    # ER's list of abilities Neutralizing Gas doesn't stop, on top of PIF's
    # unstoppable ones
    GAS_PROOF = [:ICEFACE, :GULPMISSILE, :ASONECHILLINGNEIGH, :ASONEGRIMNEIGH]

    def self.name(id)
      return KIFER.ability_name(id)
    end

    #---------------------------------------------------------------------------
    # Neutralizing Gas
    #---------------------------------------------------------------------------
    # The battler gives off gas (ability or innate, not Gastro Acid'd, on the
    # field). Reads raw ids, so it never asks abilityActive?.
    def self.gas_source?(b, ignore_hp = false)
      return false if !b || !b.pokemon
      return false if !ignore_hp && b.fainted?
      return false if b.effects[PBEffects::GastroAcid]
      return false if b.instance_variable_get(:@kifer_sp1_gas_left)
      return true if b.ability_id == :NEUTRALIZINGGAS
      ids = b.respond_to?(:innate_ids) ? b.innate_ids : nil
      return ids.is_a?(Array) && ids.include?(:NEUTRALIZINGGAS)
    end

    def self.gas_on?(battle)
      return false if !battle
      fixed = battle.instance_variable_get(:@kifer_sp1_gas)
      return fixed if !fixed.nil?
      return false if !KIFER.enabled?
      battle.battlers.each { |b| return true if gas_source?(b) }
      return false
    end

    # Worked out once while the block runs (a battle AI decision: nothing on
    # the field changes meanwhile; abilityActive? asks it very often)
    def self.gas_fixed(battle)
      return yield if !battle.instance_variable_get(:@kifer_sp1_gas).nil?
      battle.instance_variable_set(:@kifer_sp1_gas, gas_on?(battle))
      begin
        return yield
      ensure
        battle.instance_variable_set(:@kifer_sp1_gas, nil)
      end
    end

    def self.gas_proof?(battler, id)
      return true if GAS_PROOF.include?(id)
      return true if stalwart_raw?(battler)   # Stalwart: abilities can't be suppressed
      return battler.unstoppableAbility?(id)
    end

    # Stalwart (033) without asking abilityActive? or the gas-filtered innates
    def self.stalwart_raw?(battler)
      return true if battler.instance_variable_get(:@ability_id) == :STALWART
      return false if !battler.respond_to?(:kifer_sp1_active_innates)
      return battler.kifer_sp1_active_innates.include?(:STALWART)
    end

    def self.announce_gas(battler)
      return if battler.instance_variable_get(:@kifer_sp1_gas_said)
      return if !gas_source?(battler)
      battler.instance_variable_set(:@kifer_sp1_gas_said, true)
      battle = battler.battle
      battle.pbShowAbilitySplash(battler, false, true, name(:NEUTRALIZINGGAS))
      battle.pbDisplay(_INTL("Neutralizing gas filled the area!"))
      battle.pbHideAbilitySplash(battler)
    end

    # Abilities that don't trigger again when the gas goes
    GAS_NO_RETRIGGER = [:IMPOSTER, :AIRLOCK, :CLOUDNINE]

    # The entry abilities the gas really held back: [main ability?, innates].
    # Not a Stalwart Pokemon's, not ones the gas can't stop, not Imposter,
    # Air Lock or Cloud Nine.
    def self.gas_retrigger(b)
      return [false, []] if !b || b.fainted? || stalwart_raw?(b) || !b.abilityActive?
      ok = proc { |id| id && !gas_proof?(b, id) && !GAS_NO_RETRIGGER.include?(id) }
      return [ok.call(b.ability_id), b.active_innates.select { |id| ok.call(id) }]
    end

    # The gas is gone: entry abilities of the Pokemon still in battle trigger
    # again (ER: after the gas user switches out)
    def self.gas_ended(battle, leaver, retrigger)
      battle.pbDisplay(_INTL("The effects of the neutralizing gas wore off!"))
      return if !retrigger
      battle.pbPriority(true).each do |b|
        next if !b || b.fainted? || b.equal?(leaver)
        main, inns = gas_retrigger(b)
        if main
          KIFER.with_context(b, nil) { BattleHandlers.kifer_triggerAbilityOnSwitchIn(b.ability, b, battle) }
        end
        inns.each do |id|
          KIFER.with_context(b, id) { BattleHandlers.kifer_triggerAbilityOnSwitchIn(id, b, battle) }
        end
      end
    end

    #---------------------------------------------------------------------------
    # Revelation
    #---------------------------------------------------------------------------
    def self.revelation_species(sp)
      s = sp.dup
      s.instance_variable_set(:@base_stats, sp.base_stats.merge(REVELATION_BASE))
      return s
    end

    # The Pokemon's stats in Revelation form, or nil if it has no Unown half
    def self.revelation_stats(pkmn)
      sp = pkmn.species_data
      if sp.is_a?(GameData::FusedSpecies)
        head = sp.head_pokemon
        body = sp.body_pokemon
        return nil if head.species != :UNOWN && body.species != :UNOWN
        fake = sp.dup
        fake.instance_variable_set(:@head_pokemon, revelation_species(head)) if head.species == :UNOWN
        fake.instance_variable_set(:@body_pokemon, revelation_species(body)) if body.species == :UNOWN
        fake.instance_variable_set(:@base_stats, fake.calculate_base_stats)
      elsif sp.species == :UNOWN
        fake = revelation_species(sp)
      else
        return nil
      end
      # Worked out on a copy, so the Pokemon itself never changes
      tmp = pkmn.clone
      tmp.define_singleton_method(:species_data) { fake }
      tmp.calc_stats
      return { :ATTACK => tmp.attack, :DEFENSE => tmp.defense, :SPECIAL_ATTACK => tmp.spatk,
               :SPECIAL_DEFENSE => tmp.spdef, :SPEED => tmp.speed }
    rescue StandardError => e
      KIFER.log("Revelation stats failed: #{e.class}: #{e.message}")
      return nil
    end

    def self.revelation_check(battler, ability)
      return if battler.fainted? || battler.effects[PBEffects::Transform]
      want = battler.hp > battler.totalhp / 4
      return if want == battler.kifer_sp1_revelation?
      if want
        stats = revelation_stats(battler.pokemon)
        return if !stats
      end
      battle = battler.battle
      battle.pbShowAbilitySplash(battler, false, true, name(ability))
      if want
        battler.kifer_sp1_set_revelation(stats)
        battle.pbDisplay(_INTL("{1} changed into its Revelation form!", battler.pbThis))
      else
        battler.kifer_sp1_set_revelation(nil)
        battle.pbDisplay(_INTL("{1} changed back to its normal form!", battler.pbThis))
      end
      battle.pbHideAbilitySplash(battler)
    end

    #---------------------------------------------------------------------------
    # Inverse Room
    #---------------------------------------------------------------------------
    def self.inverse_room?(battle)
      return battle.instance_variable_get(:@kifer_sp1_inverse).to_i > 0
    end

    def self.invert(eff)
      case eff
      when Effectiveness::SUPER_EFFECTIVE_ONE
        return Effectiveness::NOT_VERY_EFFECTIVE_ONE
      when Effectiveness::NOT_VERY_EFFECTIVE_ONE, Effectiveness::INEFFECTIVE
        return Effectiveness::SUPER_EFFECTIVE_ONE
      end
      return eff
    end

    def self.inverse_tick(battle)
      n = battle.instance_variable_get(:@kifer_sp1_inverse).to_i
      return if n <= 0
      battle.instance_variable_set(:@kifer_sp1_inverse, n - 1)
      battle.pbDisplay(_INTL("Inverse Room wore off, and type matchups returned to normal!")) if n == 1
    end

    #---------------------------------------------------------------------------
    # Discipline
    #---------------------------------------------------------------------------
    def self.discipline_tick(battler)
      lock = battler.kifer_sp1_disc
      return if !lock
      # ER: the counter waits while a Choice item or a move-locking ability
      # holds the move anyway
      return if battler.hasActiveAbility?([:GORILLATACTICS, :SAGEPOWER])
      return if battler.hasActiveItem?([:CHOICEBAND, :CHOICESPECS, :CHOICESCARF])
      lock[1] -= 1
      return if lock[1] > 0
      battler.kifer_sp1_disc = nil
      battler.battle.pbDisplay(_INTL("{1} calmed down.", battler.pbThis))
    end
  end
end

#-------------------------------------------------------------------------------
# Poseidon's Dominion – on entry: Whirlpool (50 power) on a foe next to it
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:POSEIDONSDOMINION,
  proc { |ability, battler, battle|
    next if !defined?(KIFER::BatchF)
    foe = KIFER::BatchF.random_near_foe(battler)
    next if !foe || foe.fainted?
    KIFER::BatchF.use_extra_move(battler, :WHIRLPOOL, foe.index,
                                   KIFER::Specials1::WHIRLPOOL_POWER, ability)
  }
)

#-------------------------------------------------------------------------------
# Revelation – Revelation form above 1/4 HP (on entry and at each turn's end)
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:REVELATION,
  proc { |ability, battler, battle|
    KIFER::Specials1.revelation_check(battler, ability)
  }
)

BattleHandlers::EOREffectAbility.add(:REVELATION,
  proc { |ability, battler, battle|
    KIFER::Specials1.revelation_check(battler, ability)
  }
)

#-------------------------------------------------------------------------------
# Inversion – on entry: Inverse Room for 3 turns
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:INVERSION,
  proc { |ability, battler, battle|
    next if !KIFER.feature_on?(:inverse_room)
    next if KIFER::Specials1.inverse_room?(battle)
    battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    # Coming in during the end of round (after a KO): that round's countdown
    # still runs, so one more keeps the full 3 turns
    turns = KIFER::Specials1::INVERSE_TURNS
    turns += 1 if battle.endOfRound
    battle.instance_variable_set(:@kifer_sp1_inverse, turns)
    battle.pbDisplay(_INTL("Inverse Room reversed the type matchups!"))
    battle.pbHideAbilitySplash(battler)
  }
)

#-------------------------------------------------------------------------------
# Discipline – gaining it cures its confusion (Own Tempo's check)
#-------------------------------------------------------------------------------
BattleHandlers::StatusCureAbility.copy(:OWNTEMPO, :DISCIPLINE)

#===============================================================================
# Game method hooks
#===============================================================================
class PokeBattle_Battler
  attr_accessor :kifer_sp1_disc

  alias kifer_sp1_pbInitEffects pbInitEffects unless method_defined?(:kifer_sp1_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_sp1_pbInitEffects(batonPass)
    @kifer_sp1_rev       = nil
    @kifer_sp1_disc      = nil
    @kifer_sp1_gas_said  = false
    @kifer_sp1_gas_left  = false
    @kifer_sp1_tag       = false
  end

  #-----------------------------------------------------------------------------
  # Neutralizing Gas – abilities and innates are off while the gas is out
  #-----------------------------------------------------------------------------
  alias kifer_sp1_abilityActive? abilityActive? unless method_defined?(:kifer_sp1_abilityActive?)
  def abilityActive?(ignore_fainted = false)
    return false if !kifer_sp1_abilityActive?(ignore_fainted)
    return true if !KIFER::Specials1.gas_on?(@battle)
    return KIFER::Specials1.gas_proof?(self, @ability_id)
  end

  alias kifer_sp1_active_innates active_innates unless method_defined?(:kifer_sp1_active_innates)
  def active_innates
    ret = kifer_sp1_active_innates
    return ret if ret.empty? || !KIFER::Specials1.gas_on?(@battle)
    return ret.select { |id| KIFER::Specials1.gas_proof?(self, id) }
  end

  # Can't be copied or swapped (Trace, Role Play, Skill Swap, Entrainment...)
  alias kifer_sp1_ungainableAbility? ungainableAbility? unless method_defined?(:kifer_sp1_ungainableAbility?)
  def ungainableAbility?(abil = nil)
    a = abil || @ability_id
    a = a.id if a.respond_to?(:id)
    return true if a == :NEUTRALIZINGGAS
    return kifer_sp1_ungainableAbility?(abil)
  end

  alias kifer_sp1_pbEffectsOnSwitchIn pbEffectsOnSwitchIn unless method_defined?(:kifer_sp1_pbEffectsOnSwitchIn)
  def pbEffectsOnSwitchIn(switchIn = false)
    KIFER::Specials1.announce_gas(self) if switchIn   # ER: before hazards
    kifer_sp1_pbEffectsOnSwitchIn(switchIn)
  end

  alias kifer_sp1_pbAbilitiesOnSwitchOut pbAbilitiesOnSwitchOut unless method_defined?(:kifer_sp1_pbAbilitiesOnSwitchOut)
  def pbAbilitiesOnSwitchOut(*args)
    was = KIFER::Specials1.gas_source?(self)
    @kifer_sp1_gas_left = true if was
    ret = kifer_sp1_pbAbilitiesOnSwitchOut(*args)
    if was && @battle.decision == 0 && !KIFER::Specials1.gas_on?(@battle)
      KIFER::Specials1.gas_ended(@battle, self, true)
    end
    return ret
  end

  # Gastro Acid, Worry Seed, Entrainment...: the gas user's own gas stops
  alias kifer_sp1_pbOnAbilityChanged pbOnAbilityChanged unless method_defined?(:kifer_sp1_pbOnAbilityChanged)
  def pbOnAbilityChanged(oldAbil)
    old = oldAbil.respond_to?(:id) ? oldAbil.id : oldAbil
    inn = respond_to?(:innate_ids) && innate_ids.is_a?(Array) && innate_ids.include?(:NEUTRALIZINGGAS)
    was = !fainted? && !@kifer_sp1_gas_left && (old == :NEUTRALIZINGGAS || (inn && @effects[PBEffects::GastroAcid]))
    ret = kifer_sp1_pbOnAbilityChanged(oldAbil)
    if was && @battle.decision == 0 && !KIFER::Specials1.gas_on?(@battle)
      KIFER::Specials1.gas_ended(@battle, self, true)
    end
    return ret
  end

  alias kifer_sp1_pbFaint pbFaint unless method_defined?(:kifer_sp1_pbFaint)
  def pbFaint(showMessage = true)
    was = !@fainted && fainted? && KIFER::Specials1.gas_source?(self, true)
    ret = kifer_sp1_pbFaint(showMessage)
    if was && @fainted && @battle.decision == 0 && !KIFER::Specials1.gas_on?(@battle)
      KIFER::Specials1.gas_ended(@battle, self, false)
    end
    return ret
  end

  #-----------------------------------------------------------------------------
  # Revelation – form stats stay through stat refreshes
  #-----------------------------------------------------------------------------
  def kifer_sp1_revelation?
    return !@kifer_sp1_rev.nil?
  end

  def kifer_sp1_apply_revelation
    s = @kifer_sp1_rev
    return if !s || @effects[PBEffects::Transform]
    @attack  = s[:ATTACK]
    @defense = s[:DEFENSE]
    @spatk   = s[:SPECIAL_ATTACK]
    @spdef   = s[:SPECIAL_DEFENSE]
    @speed   = s[:SPEED]
  end

  def kifer_sp1_set_revelation(stats)
    @kifer_sp1_rev = stats
    if stats
      kifer_sp1_apply_revelation
    else
      pbUpdate(false)
    end
  end

  alias kifer_sp1_pbUpdate pbUpdate unless method_defined?(:kifer_sp1_pbUpdate)
  def pbUpdate(fullChange = false)
    kifer_sp1_pbUpdate(fullChange)
    kifer_sp1_apply_revelation if @kifer_sp1_rev
  end

  #-----------------------------------------------------------------------------
  # Discipline – can't be confused, Intimidate doesn't work on it, rampage
  # moves lock it like a Choice item instead
  #-----------------------------------------------------------------------------
  alias kifer_sp1_pbCanConfuse? pbCanConfuse? unless method_defined?(:kifer_sp1_pbCanConfuse?)
  def pbCanConfuse?(user = nil, showMessages = true, move = nil, selfInflicted = false)
    return false if !kifer_sp1_pbCanConfuse?(user, showMessages, move, selfInflicted)
    if (selfInflicted || !@battle.moldBreaker) && hasActiveAbility?(:DISCIPLINE)
      if showMessages
        @battle.pbShowAbilitySplash(self, false, true, KIFER.ability_name(:DISCIPLINE))
        @battle.pbDisplay(_INTL("{1} doesn't become confused!", pbThis))
        @battle.pbHideAbilitySplash(self)
      end
      return false
    end
    return true
  end

  alias kifer_sp1_pbLowerAttackStatStageIntimidate pbLowerAttackStatStageIntimidate unless method_defined?(:kifer_sp1_pbLowerAttackStatStageIntimidate)
  def pbLowerAttackStatStageIntimidate(user)
    if !fainted? && hasActiveAbility?(:DISCIPLINE)
      @battle.pbShowAbilitySplash(self, false, true, KIFER.ability_name(:DISCIPLINE))
      @battle.pbDisplay(_INTL("{1}'s stats were not lowered!", pbThis))
      @battle.pbHideAbilitySplash(self)
      return false
    end
    return kifer_sp1_pbLowerAttackStatStageIntimidate(user)
  end

  # Scare (batch 1) lowers Sp. Atk through this method with its own name
  alias kifer_sp1_pbLowerStatStageByAbility pbLowerStatStageByAbility unless method_defined?(:kifer_sp1_pbLowerStatStageByAbility)
  def pbLowerStatStageByAbility(stat, increment, user, splashAnim = true, checkContact = false, ability_name = nil)
    if stat == :SPECIAL_ATTACK && user && !user.equal?(self) && !fainted? && ability_name &&
       ability_name == KIFER.ability_name(:SCARE) && hasActiveAbility?(:DISCIPLINE)
      @battle.pbShowAbilitySplash(self, false, true, KIFER.ability_name(:DISCIPLINE))
      @battle.pbDisplay(_INTL("{1}'s stats were not lowered!", pbThis))
      @battle.pbHideAbilitySplash(self)
      return false
    end
    return kifer_sp1_pbLowerStatStageByAbility(stat, increment, user, splashAnim, checkContact, ability_name)
  end

  alias kifer_sp1_pbCanChooseMove? pbCanChooseMove? unless method_defined?(:kifer_sp1_pbCanChooseMove?)
  def pbCanChooseMove?(move, commandPhase, showMessages = true, specialUsage = false)
    lock = @kifer_sp1_disc
    if lock && move.id != lock[0] && pbHasMove?(lock[0]) && hasActiveAbility?(:DISCIPLINE)
      if showMessages
        msg = _INTL("{1} can only use {2}!", pbThis, GameData::Move.get(lock[0]).name)
        (commandPhase) ? @battle.pbDisplayPaused(msg) : @battle.pbDisplay(msg)
      end
      return false
    end
    return kifer_sp1_pbCanChooseMove?(move, commandPhase, showMessages, specialUsage)
  end
end

#-------------------------------------------------------------------------------
# Discipline – Outrage, Thrash, Petal Dance
#-------------------------------------------------------------------------------
class PokeBattle_Move_0D2
  alias kifer_sp1_pbEffectAfterAllHits pbEffectAfterAllHits unless method_defined?(:kifer_sp1_pbEffectAfterAllHits)
  def pbEffectAfterAllHits(user, target)
    return kifer_sp1_pbEffectAfterAllHits(user, target) if !user.hasActiveAbility?(:DISCIPLINE)
    kifer_sp1_pbEffectAfterAllHits(user, target)
    user.effects[PBEffects::Outrage] = 0   # not trapped in the rampage, no fatigue
    if !user.kifer_sp1_disc && !user.instance_variable_get(:@kifer_f_extra) &&
       user.pbHasMove?(@id)
      user.kifer_sp1_disc = [@id, KIFER::Specials1::DISCIPLINE_TURNS]
    end
  end
end

#-------------------------------------------------------------------------------
# Temporal Rupture – Roar of Time: 100 power, no recharge, target gets Slow Start
#-------------------------------------------------------------------------------
class PokeBattle_Move_0C2
  def kifer_sp1_rupture?(user)
    return @id == :ROAROFTIME && user.hasActiveAbility?(:TEMPORALRUPTURE)
  end

  alias kifer_sp1_pbBaseDamage pbBaseDamage unless method_defined?(:kifer_sp1_pbBaseDamage)
  def pbBaseDamage(baseDmg, user, target)
    return 100 if kifer_sp1_rupture?(user)
    return kifer_sp1_pbBaseDamage(baseDmg, user, target)
  end

  alias kifer_sp1_pbEffectGeneral pbEffectGeneral unless method_defined?(:kifer_sp1_pbEffectGeneral)
  def pbEffectGeneral(user)
    return if kifer_sp1_rupture?(user)   # no recharge turn
    kifer_sp1_pbEffectGeneral(user)
  end

  alias kifer_sp1_pbEffectAgainstTarget pbEffectAgainstTarget unless method_defined?(:kifer_sp1_pbEffectAgainstTarget)
  def pbEffectAgainstTarget(user, target)
    kifer_sp1_pbEffectAgainstTarget(user, target)
    return if !kifer_sp1_rupture?(user)
    return if target.fainted? || target.damageState.unaffected || target.damageState.substitute
    return if target.unstoppableAbility? || [:TRUANT, :SLOWSTART].include?(target.ability_id)
    return if !GameData::Ability.exists?(:SLOWSTART)
    @battle.pbShowAbilitySplash(user, false, true, KIFER.ability_name(:TEMPORALRUPTURE))
    @battle.pbHideAbilitySplash(user)
    old = target.ability
    target.ability = :SLOWSTART
    @battle.pbDisplay(_INTL("{1} acquired {2}!", target.pbThis, target.abilityName))
    target.pbOnAbilityChanged(old)
    # Slow Start's own entry effect (5 turns), without the target's innates
    if target.abilityActive?
      KIFER.suppress(:all) { BattleHandlers.triggerAbilityOnSwitchIn(:SLOWSTART, target, @battle) }
    end
  end
end

#-------------------------------------------------------------------------------
# Tag – a 20 power Pursuit on a foe that switches out
#-------------------------------------------------------------------------------
class PokeBattle_Move_088
  alias kifer_sp1_pbBaseDamage pbBaseDamage unless method_defined?(:kifer_sp1_pbBaseDamage)
  def pbBaseDamage(baseDmg, user, target)
    return KIFER::Specials1::TAG_POWER if user.instance_variable_get(:@kifer_sp1_tag)
    return kifer_sp1_pbBaseDamage(baseDmg, user, target)
  end
end

class PokeBattle_Battle
  alias kifer_sp1_pbPursuit pbPursuit unless method_defined?(:kifer_sp1_pbPursuit)
  def pbPursuit(idxSwitcher)
    kifer_sp1_pbPursuit(idxSwitcher)
    return if @decision > 0 || !defined?(KIFER::BatchF)
    switcher = @battlers[idxSwitcher]
    return if !switcher || switcher.fainted?
    pbPriority.each do |b|
      next if b.fainted? || !b.opposes?(idxSwitcher)
      next if b.effects[PBEffects::Pursuit]
      next if b.status == :SLEEP || b.status == :FROZEN
      next if !b.hasActiveAbility?(:TAG)
      @switching = true
      b.instance_variable_set(:@kifer_sp1_tag, true)
      begin
        KIFER::BatchF.use_extra_move(b, :PURSUIT, idxSwitcher, nil, :TAG)
      ensure
        b.instance_variable_set(:@kifer_sp1_tag, false)
        @switching = false
      end
      break if @decision > 0 || switcher.fainted?
    end
  end

  # Neutralizing Gas announces itself before the others' entry abilities
  alias kifer_sp1_pbOnActiveAll pbOnActiveAll unless method_defined?(:kifer_sp1_pbOnActiveAll)
  def pbOnActiveAll
    eachBattler { |b| KIFER::Specials1.announce_gas(b) }
    kifer_sp1_pbOnActiveAll
  end

  # Inverse Room and Discipline's lock count down at the end of each turn
  alias kifer_sp1_pbEndOfRoundPhase pbEndOfRoundPhase unless method_defined?(:kifer_sp1_pbEndOfRoundPhase)
  def pbEndOfRoundPhase
    kifer_sp1_pbEndOfRoundPhase
    return if @decision > 0
    KIFER::Specials1.inverse_tick(self)
    eachBattler { |b| KIFER::Specials1.discipline_tick(b) }
  end
end

#-------------------------------------------------------------------------------
# Inverse Room – reversed type matchups
#-------------------------------------------------------------------------------
# Flying Press multiplies in its Flying matchup after the inverted one
class PokeBattle_Move_144
  alias kifer_sp1_144_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_sp1_144_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_sp1_144_pbCalcTypeModSingle(moveType, defType, user, target)
    return ret if !defType || !GameData::Type.exists?(:FLYING) || !KIFER::Specials1.inverse_room?(@battle)
    f = Effectiveness.calculate_one(:FLYING, defType)
    return ret if f == 0
    return ret * KIFER::Specials1.invert(f).to_f / f
  end
end

class PokeBattle_Move
  alias kifer_sp1_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_sp1_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_sp1_pbCalcTypeModSingle(moveType, defType, user, target)
    return ret if !moveType || !defType || !KIFER::Specials1.inverse_room?(@battle)
    # Something else already changed this matchup: it keeps its result
    return ret if ret != Effectiveness.calculate_one(moveType, defType)
    return KIFER::Specials1.invert(ret)
  end
end
