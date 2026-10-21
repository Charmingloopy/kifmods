#===============================================================================
# KIF: Elite Redux – Elite Redux abilities PIF doesn't have (batch J)
#   Mechanics follow the newest Elite Redux in-game texts (these abilities
#   aren't in the public C source).
#
#   Cosmic Dust       – no damage from anything but attacks (as Magic Guard);
#                       attacks on confused or enraged targets x2; confused or
#                       enraged foes take x2 when they hurt themselves
#   Cosmic Wings      – Flying moves become Fairy
#   Craving           – end of each turn: eats a random Sitrus, Liechi,
#                       Ganlon, Salac, Petaya, Apicot, Lansat or Starf Berry,
#                       or a random pinch healing berry (Figy, Wiki, Mago,
#                       Aguav, Iapapa). Not its held item.
#   Crushing Jaw      – biting moves x1.3 (ER's Strong Jaw); its biting hits
#                       have a 50% chance to lower the target's Defense by 1
#   Cryo Proficiency  – its hits, and hits on it: frostbite 30% on contact,
#                       else 20% (its own text; Freezing Point's is 20/30);
#                       being hit starts hail (8 turns, 12 with Icy Rock); no
#                       hail damage
#   Daredevil         – Attack +1 after it hits with a recoil move; half
#                       recoil damage
#   Dead Power        – physical moves: Attack x1.5; its contact hits have a
#                       20% chance to curse the target (1/4 HP each turn)
#   Deflect           – takes x0.8 damage from attacks; after a foe's move
#                       hits it, it uses a 20 power Vacuum Wave at that foe
#   Desert Cloak      – in a sandstorm: it and its allies can't get a status
#                       problem from a foe, and foes' moves have no added
#                       effects (or flinch) on them
#   Desert Spirit     – on entry: sandstorm (8 turns, 12 with Smooth Rock); in
#                       a sandstorm its Ground moves hit airborne and Flying
#                       Pokemon for normal damage; no sandstorm damage
#   Drake of Rage     – Tinted Lens + Rampage
#   Dreamstate        – can't be hit by a critical hit; takes x0.8 damage
#   Dream Whimsy      – on entry: uses Yawn on a foe
#   Droideka          – Fire moves hit it for half; no burn damage and no burn
#                       Attack drop; can't be hit by a critical hit; takes x0.8
#                       damage
#   Dune Terror       – in a sandstorm takes x0.65 damage; Ground moves x1.2
#   Early Grave       – Ghost moves +1 priority at full HP
#   Edgelord          – its first slicing move after it comes in gets +1
#                       priority; it gets it again after it KOs a Pokemon
#   Electro Booster   – on entry: uses Magnet Rise
#   Electromorphosis  – hit by an attack: charged (its next Electric attack
#                       x2, used up by that move)
#   Energy Siphon     – heals 1/4 of the damage it deals to a foe (min 1)
#   Enlightened       – Emanate + Inner Focus (no flinching; Intimidate and
#                       Scare don't affect it; Focus Blast never misses)
#   Evaporate         – Water moves don't affect it and put Mist on its side
#                       for 5 turns
#   Familia Bond      – attacks hit twice, the 2nd hit at 50% and it can't
#                       flinch (same rules as PIF's Parental Bond)
#   Fire Scales       – special moves hit it for half
#   Flower Necklace   – Sp. Def x1.5 in Grassy Terrain
#   Fluffiest         – contact moves hit it for x0.25; Fire moves x4
#   Foggy Eye         – in fog: its Ghost moves x1.5, and it resists Ghost moves
#   Gale Force Wings  – Flying moves +1 priority
#   Giant Shuriken    – its Water Shuriken hits once, 100 power, +1 crit stage
#   Gifted Mind       – Dark, Ghost and Bug moves don't affect it; its status
#                       moves never miss
#   Glacial Rage      – after it uses an Ice move, uses a 50 power Blizzard
#                       (20% frostbite chance)
#   Gleam Eyes        – Frisk + Scare: on entry finds the foes' items and stops
#                       them working for 2 turns, then lowers foes' Sp. Atk
#
#   Moves used by an ability are real move uses (025's use_extra_move).
#
# Not coded yet:
#   Current Crash – Thundercall's Smite is an ER move PIF doesn't have
#   (Cryostasis, Drakelp Head, Flame Coat and batch I's Backup Power: 042)
#===============================================================================
KIFER.er_code(:COSMICDUST, :COSMICWINGS, :CRAVING, :CRUSHINGJAW, :CRYOPROFICIENCY,
              :DAREDEVIL, :DEADPOWER, :DEFLECT, :DESERTCLOAK, :DESERTSPIRIT,
              :DRAKEOFRAGE, :DREAMSTATE, :DREAMWHIMSY, :DROIDEKA, :DUNETERROR,
              :EARLYGRAVE, :EDGELORD, :ELECTROBOOSTER, :ELECTROMORPHOSIS,
              :ENERGYSIPHON, :ENLIGHTENED, :EVAPORATE, :FAMILIABOND, :FIRESCALES,
              :FLOWERNECKLACE, :FLUFFIEST, :FOGGYEYE, :GALEFORCEWINGS,
              :GIANTSHURIKEN, :GIFTEDMIND, :GLACIALRAGE, :GLEAMEYES)

module KIFER
  module BatchJ
    CRAVING_BERRIES = [:SITRUSBERRY, :LIECHIBERRY, :GANLONBERRY, :SALACBERRY,
                       :PETAYABERRY, :APICOTBERRY, :LANSATBERRY, :STARFBERRY, :PINCH]
    PINCH_BERRIES   = [:FIGYBERRY, :WIKIBERRY, :MAGOBERRY, :AGUAVBERRY, :IAPAPABERRY]
    GIFTED_TYPES    = [:DARK, :GHOST, :BUG]
    # ER charge from Electromorphosis lasts until an Electric attack uses it
    MORPH_CHARGE    = 99

    def self.has?(battler, id)
      return KIFER::BatchH.has?(battler, id)
    end

    def self.sand?(battle)
      return battle.pbWeather == :Sandstorm
    end

    # Cosmic Dust: a foe of the battler has it
    def self.cosmic_foe?(battler)
      return false unless battler && KIFER.on_field?(battler.battle, :COSMICDUST)
      battler.battle.eachOtherSideBattler(battler.index) { |b| return true if has?(b, :COSMICDUST) }
      return false
    end

    def self.dazed?(battler)
      return battler.effects[PBEffects::Confusion] > 0 || KIFER::TerrainEnrage.enraged?(battler)
    end

    # Desert Cloak on the target's side that blocks the user (a foe), or nil
    def self.cloak(user, target)
      return nil if !user || !target || user.index == target.index || !user.opposes?(target)
      battle = target.battle
      return nil if !sand?(battle) || !KIFER.on_field?(battle, :DESERTCLOAK) || battle.moldBreaker
      return target if has?(target, :DESERTCLOAK)
      target.eachAlly { |b| return b if has?(b, :DESERTCLOAK) }
      return nil
    end

    def self.desert_spirit?(user, move)
      return false unless user && move && sand?(user.battle)
      return false unless KIFER.on_field?(user.battle, :DESERTSPIRIT)
      return (move.calcType || move.type) == :GROUND && has?(user, :DESERTSPIRIT)
    end

    def self.giant_shuriken?(user, move)
      return move.id == :WATERSHURIKEN && has?(user, :GIANTSHURIKEN)
    end

    def self.splash(battler, ability)
      battler.battle.pbShowAbilitySplash(battler, false, true, KIFER.ability_name(ability))
    end

    def self.hide(battler)
      battler.battle.pbHideAbilitySplash(battler)
    end
  end
end

#-------------------------------------------------------------------------------
# Cosmic Dust – attacks on confused / enraged targets x2
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:COSMICDUST,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if !target || target.index == user.index
    mults[:final_damage_multiplier] *= 2 if KIFER::BatchJ.dazed?(target)
  }
)

#-------------------------------------------------------------------------------
# Cosmic Wings – Flying moves become Fairy
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.add(:COSMICWINGS,
  proc { |ability, user, move, type|
    next if type != :FLYING || !GameData::Type.exists?(:FAIRY)
    next :FAIRY
  }
)

#-------------------------------------------------------------------------------
# Craving – eats a random berry at the end of each turn
#-------------------------------------------------------------------------------
BattleHandlers::EOREffectAbility.add(:CRAVING,
  proc { |ability, battler, battle|
    next if battler.fainted?
    list = KIFER::BatchJ::CRAVING_BERRIES
    berry = list[battle.pbRandom(list.length)]
    if berry == :PINCH
      pinch = KIFER::BatchJ::PINCH_BERRIES
      berry = pinch[battle.pbRandom(pinch.length)]
    end
    next if !GameData::Item.exists?(berry)
    KIFER::BatchJ.splash(battler, ability)
    battle.pbCommonAnimation("EatBerry", battler)
    battle.pbDisplay(_INTL("{1} ate a {2}!", battler.pbThis, GameData::Item.get(berry).name))
    eaten = BattleHandlers.triggerHPHealItem(berry, battler, battle, true)
    battle.pbDisplay(_INTL("But nothing happened!")) if !eaten
    KIFER::BatchJ.hide(battler)
  }
)

#-------------------------------------------------------------------------------
# Crushing Jaw – biting moves x1.3, 50% Defense -1
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:CRUSHINGJAW,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.3 if move.bitingMove?
  }
)

BattleHandlers::UserAbilityOnHit.add(:CRUSHINGJAW,
  proc { |ability, user, target, move, battle|
    next if !move.bitingMove? || target.fainted? || battle.pbRandom(100) >= 50
    target.pbLowerStatStageByAbility(:DEFENSE, 1, user, true, false, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Cryo Proficiency – frostbite both ways (30% contact, 20% otherwise); hail
# when it is hit
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:CRYOPROFICIENCY,
  proc { |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_user(ability, user, target, move, :FROSTBITE, 30, 20)
  }
)

BattleHandlers::TargetAbilityOnHit.add(:CRYOPROFICIENCY,
  proc { |ability, user, target, move, battle|
    KIFER::ERVersions.on_hit_target(ability, user, target, move, :FROSTBITE, 30, 20)
    next if target.fainted?
    KIFER::ERVersions.weather_ability(:Hail, target, battle, ability)
  }
)

#-------------------------------------------------------------------------------
# Daredevil – Attack +1 after a recoil move hits (half recoil is further down)
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:DAREDEVIL,
  proc { |ability, user, targets, move, battle|
    next if user.fainted? || !move.recoilMove?
    next unless targets.any? { |b| b.index != user.index && KIFER::BatchF.hit?(b) }
    next if !user.pbCanRaiseStatStage?(:ATTACK, user)
    user.pbRaiseStatStageByAbility(:ATTACK, 1, user, true, KIFER.ability_name(ability))
  }
)

#-------------------------------------------------------------------------------
# Dead Power – Attack x1.5; 20% curse with contact
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:DEADPOWER,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:attack_multiplier] *= 1.5 if move.physicalMove?(type)
  }
)

BattleHandlers::UserAbilityOnHit.add(:DEADPOWER,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user) || target.fainted? || user.index == target.index
    next if target.effects[PBEffects::Curse] || battle.pbRandom(100) >= 20
    next if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
    KIFER::BatchJ.splash(user, ability)
    target.effects[PBEffects::Curse] = true
    battle.pbDisplay(_INTL("{1} laid a curse on {2}!", user.pbThis, target.pbThis(true)))
    KIFER::BatchJ.hide(user)
  }
)

#-------------------------------------------------------------------------------
# Deflect – x0.8 damage taken; Vacuum Wave back after a foe's move hits it
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:DEFLECT,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.8
  }
)

BattleHandlers::TargetAbilityOnHit.add(:DEFLECT,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || !target.opposes?(user) || KIFER.in_extra_move?(user)
    target.instance_variable_set(:@kifer_j_deflect, user.index)
  }
)

#-------------------------------------------------------------------------------
# Desert Spirit – sandstorm on entry
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:DESERTSPIRIT,
  proc { |ability, battler, battle|
    KIFER::ERVersions.weather_ability(:Sandstorm, battler, battle, ability)
  }
)

#-------------------------------------------------------------------------------
# Drake of Rage – Tinted Lens + Rampage
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.copy(:TINTEDLENS, :DRAKEOFRAGE)
BattleHandlers::UserAbilityEndOfMove.copy(:RAMPAGE, :DRAKEOFRAGE)

#-------------------------------------------------------------------------------
# Dreamstate, Droideka – no critical hits, x0.8 damage taken
#-------------------------------------------------------------------------------
[:DREAMSTATE, :DROIDEKA].each do |id|
  BattleHandlers::CriticalCalcTargetAbility.add(id, proc { |ability, user, target, c| next -1 })
end

BattleHandlers::DamageCalcTargetAbility.add(:DREAMSTATE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.8
  }
)

# Droideka also: Fire moves hit it for half (burn parts are further down)
BattleHandlers::DamageCalcTargetAbility.add(:DROIDEKA,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.8
    mults[:base_damage_multiplier] /= 2 if type == :FIRE
  }
)

#-------------------------------------------------------------------------------
# Dream Whimsy – Yawn on entry; Electro Booster – Magnet Rise on entry
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:DREAMWHIMSY,
  proc { |ability, battler, battle|
    foe = KIFER::BatchF.random_near_foe(battler)
    next if !foe
    KIFER::BatchF.use_extra_move(battler, :YAWN, foe.index, nil, ability)
  }
)

BattleHandlers::AbilityOnSwitchIn.add(:ELECTROBOOSTER,
  proc { |ability, battler, battle|
    KIFER::BatchF.use_extra_move(battler, :MAGNETRISE, battler.index, nil, ability)
  }
)

#-------------------------------------------------------------------------------
# Dune Terror – x0.65 damage taken in sand; Ground moves x1.2
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:DUNETERROR,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.65 if KIFER::BatchJ.sand?(target.battle)
  }
)

BattleHandlers::DamageCalcUserAbility.add(:DUNETERROR,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.2 if type == :GROUND
  }
)

#-------------------------------------------------------------------------------
# Early Grave – Ghost +1 priority at full HP; Gale Force Wings – Flying +1;
# Edgelord – first slicing move +1
#-------------------------------------------------------------------------------
BattleHandlers::PriorityChangeAbility.add(:EARLYGRAVE,
  proc { |ability, battler, move, pri|
    next pri + 1 if battler.hp == battler.totalhp && move.pbCalcType(battler) == :GHOST
  }
)

BattleHandlers::PriorityChangeAbility.add(:GALEFORCEWINGS,
  proc { |ability, battler, move, pri|
    next pri + 1 if move.pbCalcType(battler) == :FLYING
  }
)

BattleHandlers::PriorityChangeAbility.add(:EDGELORD,
  proc { |ability, battler, move, pri|
    next pri + 1 if KIFER::SLICING_MOVES.include?(move.id) && !battler.instance_variable_get(:@kifer_j_edge_used)
  }
)

BattleHandlers::UserAbilityEndOfMove.add(:EDGELORD,
  proc { |ability, user, targets, move, battle|
    user.instance_variable_set(:@kifer_j_edge_ko, true) if targets.any? { |b| b.damageState.fainted }
  }
)

#-------------------------------------------------------------------------------
# Electromorphosis – charged when hit
#-------------------------------------------------------------------------------
BattleHandlers::TargetAbilityOnHit.add(:ELECTROMORPHOSIS,
  proc { |ability, user, target, move, battle|
    next if target.fainted? || target.instance_variable_get(:@kifer_j_morph)
    KIFER::BatchJ.splash(target, ability)
    target.effects[PBEffects::Charge] = KIFER::BatchJ::MORPH_CHARGE
    target.instance_variable_set(:@kifer_j_morph, true)
    battle.pbDisplay(_INTL("{1} began charging power!", target.pbThis))
    KIFER::BatchJ.hide(target)
  }
)

#-------------------------------------------------------------------------------
# Energy Siphon – heals 1/4 of the damage it deals to a foe, after each hit
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityOnHit.add(:ENERGYSIPHON,
  proc { |ability, user, target, move, battle|
    next if !target.opposes?(user) || !user.canHeal?
    dmg = target.damageState.hpLost
    next if dmg <= 0
    KIFER::BatchJ.splash(user, ability)
    user.pbRecoverHP([dmg / 4, 1].max)
    battle.pbDisplay(_INTL("{1}'s HP was restored.", user.pbThis))
    KIFER::BatchJ.hide(user)
  }
)

#-------------------------------------------------------------------------------
# Enlightened – Emanate + Inner Focus (flinch / Intimidate / Scare further down)
#-------------------------------------------------------------------------------
BattleHandlers::MoveBaseTypeModifierAbility.copy(:EMANATE, :ENLIGHTENED)
BattleHandlers::DamageCalcUserAbility.copy(:EMANATE, :ENLIGHTENED)
BattleHandlers::UserAbilityOnHit.copy(:EMANATE, :ENLIGHTENED)

BattleHandlers::AccuracyCalcUserAbility.add(:ENLIGHTENED,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0 if move.id == :FOCUSBLAST
  }
)

#-------------------------------------------------------------------------------
# Evaporate – Water moves don't affect it; Mist on its side
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:EVAPORATE,
  proc { |ability, user, target, move, type, battle|
    next false if user.index == target.index || type != :WATER
    KIFER::BatchJ.splash(target, ability)
    side = target.pbOwnSide
    if side.effects[PBEffects::Mist] <= 0
      side.effects[PBEffects::Mist] = 5
      battle.pbDisplay(_INTL("{1} became shrouded in mist!", target.pbTeam))
    else
      battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
    end
    KIFER::BatchJ.hide(target)
    next true
  }
)

#-------------------------------------------------------------------------------
# Fire Scales – special hits x0.5; Fluffiest – contact x0.25, Fire x4
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.copy(:ICESCALES, :FIRESCALES)

BattleHandlers::DamageCalcTargetAbility.add(:FLUFFIEST,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:final_damage_multiplier] *= 0.25 if move.pbContactMove?(user)
    mults[:final_damage_multiplier] *= 4 if type == :FIRE
  }
)

#-------------------------------------------------------------------------------
# Flower Necklace – Sp. Def x1.5 in Grassy Terrain
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcTargetAbility.add(:FLOWERNECKLACE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    next if target.battle.field.terrain != :Grassy || !move.specialMove?(type)
    mults[:defense_multiplier] *= 1.5
  }
)

#-------------------------------------------------------------------------------
# Foggy Eye – Ghost moves x1.5 in fog (the resistance is further down)
#-------------------------------------------------------------------------------
BattleHandlers::DamageCalcUserAbility.add(:FOGGYEYE,
  proc { |ability, user, target, move, mults, baseDmg, type|
    mults[:base_damage_multiplier] *= 1.5 if type == :GHOST && KIFER::Fog.active?(user.battle)
  }
)

#-------------------------------------------------------------------------------
# Gifted Mind – Dark, Ghost and Bug moves don't affect it; its status moves
# never miss
#-------------------------------------------------------------------------------
BattleHandlers::MoveImmunityTargetAbility.add(:GIFTEDMIND,
  proc { |ability, user, target, move, type, battle|
    next false if user.index == target.index || !KIFER::BatchJ::GIFTED_TYPES.include?(type)
    KIFER::BatchJ.splash(target, ability)
    battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
    KIFER::BatchJ.hide(target)
    next true
  }
)

BattleHandlers::AccuracyCalcUserAbility.add(:GIFTEDMIND,
  proc { |ability, mods, user, target, move, type|
    mods[:base_accuracy] = 0 if move.statusMove?
  }
)

#-------------------------------------------------------------------------------
# Glacial Rage – after an Ice move, a 50 power Blizzard (025's follow-up)
#-------------------------------------------------------------------------------
BattleHandlers::UserAbilityEndOfMove.add(:GLACIALRAGE,
  proc { |ability, user, targets, move, battle|
    next if user.instance_variable_get(:@kifer_f_extra)
    next if move.calcType != :ICE || user.fainted? || user.lastMoveFailed
    next if user.instance_variable_get(:@kifer_f_follow) || !GameData::Move.exists?(:BLIZZARD)
    t = targets.find { |b| b.index != user.index && !b.fainted? && !b.damageState.unaffected }
    next if !t
    user.instance_variable_set(:@kifer_f_follow, [:BLIZZARD, t.index, 50, ability])
  }
)

#-------------------------------------------------------------------------------
# Gleam Eyes – Frisk (ER: items stop working for 2 turns) + Scare
#-------------------------------------------------------------------------------
BattleHandlers::AbilityOnSwitchIn.add(:GLEAMEYES,
  proc { |ability, battler, battle|
    foes = []
    battle.eachOtherSideBattler(battler.index) { |b| foes.push(b) if b.item }
    if !foes.empty?
      KIFER::BatchJ.splash(battler, ability)
      foes.each do |b|
        battle.pbDisplay(_INTL("{1} frisked {2} and found its {3}!", battler.pbThis, b.pbThis(true), b.itemName))
        b.effects[PBEffects::Embargo] = 2 if b.effects[PBEffects::Embargo] <= 0
      end
      KIFER::BatchJ.hide(battler)
    end
    # as Scare itself, so abilities that block Scare block it
    BattleHandlers::AbilityOnSwitchIn[:SCARE].call(:SCARE, battler, battle)
  }
)

#===============================================================================
# Game method hooks
#===============================================================================
class PokeBattle_Battler
  # Cosmic Dust: Magic Guard
  alias kifer_j_takesIndirectDamage? takesIndirectDamage? unless method_defined?(:kifer_j_takesIndirectDamage?)
  def takesIndirectDamage?(showMsg = false)
    if !fainted? && hasActiveAbility?(:COSMICDUST)
      if showMsg
        KIFER::BatchJ.splash(self, :COSMICDUST)
        @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis))
        KIFER::BatchJ.hide(self)
      end
      return false
    end
    return kifer_j_takesIndirectDamage?(showMsg)
  end

  # Desert Spirit: no sandstorm damage. Cryo Proficiency: no hail damage.
  alias kifer_j_takesSandstormDamage? takesSandstormDamage? unless method_defined?(:kifer_j_takesSandstormDamage?)
  def takesSandstormDamage?
    return false if hasActiveAbility?(:DESERTSPIRIT)
    return kifer_j_takesSandstormDamage?
  end

  alias kifer_j_takesHailDamage? takesHailDamage? unless method_defined?(:kifer_j_takesHailDamage?)
  def takesHailDamage?
    return false if hasActiveAbility?(:CRYOPROFICIENCY)
    return kifer_j_takesHailDamage?
  end

  # Desert Cloak: no status problems from foes in sand
  alias kifer_j_pbCanInflictStatus? pbCanInflictStatus? unless method_defined?(:kifer_j_pbCanInflictStatus?)
  def pbCanInflictStatus?(newStatus, user, showMessages, move = nil, ignoreStatus = false)
    if !fainted? && (cloak = KIFER::BatchJ.cloak(user, self))
      if showMessages
        KIFER::BatchJ.splash(cloak, :DESERTCLOAK)
        @battle.pbDisplay(_INTL("{1} is unaffected!", pbThis))
        KIFER::BatchJ.hide(cloak)
      end
      return false
    end
    return kifer_j_pbCanInflictStatus?(newStatus, user, showMessages, move, ignoreStatus)
  end

  # Droideka: no burn damage
  alias kifer_j_pbContinueStatus pbContinueStatus unless method_defined?(:kifer_j_pbContinueStatus)
  def pbContinueStatus(*args, &block)
    return if block && @status == :BURN && hasActiveAbility?(:DROIDEKA)
    return kifer_j_pbContinueStatus(*args, &block)
  end

  # Enlightened: no flinching, no Intimidate, no Scare
  alias kifer_j_pbFlinch pbFlinch unless method_defined?(:kifer_j_pbFlinch)
  def pbFlinch(user = nil)
    return if hasActiveAbility?(:ENLIGHTENED) && !@battle.moldBreaker
    kifer_j_pbFlinch(user)
  end

  def kifer_j_enlightened_blocks
    KIFER::BatchJ.splash(self, :ENLIGHTENED)
    @battle.pbDisplay(_INTL("{1}'s stats were not lowered!", pbThis))
    KIFER::BatchJ.hide(self)
  end

  alias kifer_j_pbLowerAttackStatStageIntimidate pbLowerAttackStatStageIntimidate unless method_defined?(:kifer_j_pbLowerAttackStatStageIntimidate)
  def pbLowerAttackStatStageIntimidate(user)
    if !fainted? && hasActiveAbility?(:ENLIGHTENED)
      kifer_j_enlightened_blocks
      return false
    end
    return kifer_j_pbLowerAttackStatStageIntimidate(user)
  end

  alias kifer_j_pbLowerStatStageByAbility pbLowerStatStageByAbility unless method_defined?(:kifer_j_pbLowerStatStageByAbility)
  def pbLowerStatStageByAbility(stat, increment, user, splashAnim = true, checkContact = false, ability_name = nil)
    if ability_name && ability_name == KIFER.ability_name(:SCARE) && !fainted? &&
       hasActiveAbility?(:ENLIGHTENED)
      kifer_j_enlightened_blocks
      return false
    end
    return kifer_j_pbLowerStatStageByAbility(stat, increment, user, splashAnim, checkContact, ability_name)
  end

  # Cosmic Dust: a confused or enraged foe's self-damage x2 (enrage recoil)
  alias kifer_j_pbReduceHP pbReduceHP unless method_defined?(:kifer_j_pbReduceHP)
  def pbReduceHP(amt, *args)
    amt *= 2 if @kifer_j_double_loss && amt > 0
    return kifer_j_pbReduceHP(amt, *args)
  end

  # Entry state: Edgelord's first slicing move, Electromorphosis charge
  alias kifer_j_pbInitEffects pbInitEffects unless method_defined?(:kifer_j_pbInitEffects)
  def pbInitEffects(batonPass)
    kifer_j_pbInitEffects(batonPass)
    @kifer_j_edge_used = false
    @kifer_j_morph = false
    @kifer_j_deflect = nil
  end

  # Desert Spirit: its Ground moves get past Levitate and the like in sand
  alias kifer_j_pbSuccessCheckAgainstTarget pbSuccessCheckAgainstTarget unless method_defined?(:kifer_j_pbSuccessCheckAgainstTarget)
  def pbSuccessCheckAgainstTarget(move, user, target)
    if KIFER::BatchJ.desert_spirit?(user, move)
      move.instance_variable_set(:@kifer_j_desert, true)
      begin
        return kifer_j_pbSuccessCheckAgainstTarget(move, user, target)
      ensure
        move.instance_variable_set(:@kifer_j_desert, false)
      end
    end
    return kifer_j_pbSuccessCheckAgainstTarget(move, user, target)
  end

  # After a move: Edgelord's state, Electromorphosis charge used up,
  # Deflect's Vacuum Wave
  alias kifer_j_pbUseMove pbUseMove unless method_defined?(:kifer_j_pbUseMove)
  def pbUseMove(choice, specialUsage = false)
    @kifer_j_edge_ko = false
    kifer_j_pbUseMove(choice, specialUsage)
    move = choice[2]
    if move.is_a?(PokeBattle_Move)
      @kifer_j_edge_used = true if KIFER::SLICING_MOVES.include?(move.id)
      @kifer_j_edge_used = false if @kifer_j_edge_ko
      if @kifer_j_morph && move.damagingMove? && move.calcType == :ELECTRIC && !@lastMoveFailed
        @effects[PBEffects::Charge] = 0
        @kifer_j_morph = false
      end
    end
    @battle.battlers.each do |b|
      next if !b || b.instance_variable_get(:@kifer_j_deflect) != @index
      b.instance_variable_set(:@kifer_j_deflect, nil)
      next if b.fainted? || fainted? || @battle.decision > 0 || !b.hasActiveAbility?(:DEFLECT)
      KIFER::BatchF.use_extra_move(b, :VACUUMWAVE, @index, 20, :DEFLECT)
    end
  end
end

class PokeBattle_Move
  # Familia Bond: hits twice
  alias kifer_j_pbNumHits pbNumHits unless method_defined?(:kifer_j_pbNumHits)
  def pbNumHits(user, targets)
    user.instance_variable_set(:@kifer_j_familia, false)
    n = kifer_j_pbNumHits(user, targets)
    if n == 1 && pbDamagingMove? && !chargingTurnMove? && targets.length == 1 &&
       KIFER::BatchJ.has?(user, :FAMILIABOND)
      user.effects[PBEffects::ParentalBond] = 3
      user.instance_variable_set(:@kifer_j_familia, true)
      return 2
    end
    return n
  end

  def kifer_j_familia_2nd?(user)
    return user.instance_variable_get(:@kifer_j_familia) && user.effects[PBEffects::ParentalBond] == 1
  end

  alias kifer_j_pbCalcDamageMultipliers pbCalcDamageMultipliers unless method_defined?(:kifer_j_pbCalcDamageMultipliers)
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    kifer_j_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    # Familia Bond: the 2nd hit is 50% (PIF already quartered it)
    multipliers[:base_damage_multiplier] *= 2 if kifer_j_familia_2nd?(user)
    # Cosmic Dust: a confused foe hurting itself takes x2
    if defined?(PokeBattle_Confusion) && is_a?(PokeBattle_Confusion) && KIFER::BatchJ.cosmic_foe?(user)
      multipliers[:final_damage_multiplier] *= 2
    end
    # Droideka: no burn Attack drop (once, and not if ER Heatproof undid it)
    if user.status == :BURN && physicalMove?(type) && damageReducedByBurn? &&
       !user.hasActiveAbility?(:GUTS) && user.hasActiveAbility?(:DROIDEKA) &&
       !(KIFER::ERVersions.on? && user.hasActiveAbility?([:HEATPROOF, :FLAREBOOST]))
      multipliers[:final_damage_multiplier] *= 2
    end
  end

  # Desert Cloak: no added effects from foes. Familia Bond: no flinch on the
  # 2nd hit. Glacial Rage's Blizzard: 20% frostbite.
  alias kifer_j_pbAdditionalEffectChance pbAdditionalEffectChance unless method_defined?(:kifer_j_pbAdditionalEffectChance)
  def pbAdditionalEffectChance(user, target, effectChance = 0)
    return 0 if KIFER::BatchJ.cloak(user, target)
    return 0 if flinchingMove? && kifer_j_familia_2nd?(user)
    effectChance = 20 if @id == :BLIZZARD && @kifer_f_power == 50 && user.instance_variable_get(:@kifer_f_extra)
    return kifer_j_pbAdditionalEffectChance(user, target, effectChance)
  end

  alias kifer_j_pbFlinchChance pbFlinchChance unless method_defined?(:kifer_j_pbFlinchChance)
  def pbFlinchChance(user, target)
    return 0 if KIFER::BatchJ.cloak(user, target) || kifer_j_familia_2nd?(user)
    return kifer_j_pbFlinchChance(user, target)
  end

  # Desert Spirit: Ground hits Flying for normal damage in sand
  alias kifer_j_pbCalcTypeModSingle pbCalcTypeModSingle unless method_defined?(:kifer_j_pbCalcTypeModSingle)
  def pbCalcTypeModSingle(moveType, defType, user, target)
    ret = kifer_j_pbCalcTypeModSingle(moveType, defType, user, target)
    if moveType == :GROUND && defType == :FLYING && Effectiveness.ineffective_type?(moveType, defType) &&
       user && KIFER::BatchJ.sand?(@battle) && KIFER::BatchJ.has?(user, :DESERTSPIRIT)
      ret = Effectiveness::NORMAL_EFFECTIVE_ONE
    end
    return ret
  end

  # Foggy Eye: resists Ghost moves in fog
  alias kifer_j_pbCalcTypeMod pbCalcTypeMod unless method_defined?(:kifer_j_pbCalcTypeMod)
  def pbCalcTypeMod(moveType, user, target)
    ret = kifer_j_pbCalcTypeMod(moveType, user, target)
    if moveType == :GHOST && ret > 0 && target && KIFER::Fog.active?(@battle) &&
       !@battle.moldBreaker && KIFER::BatchJ.has?(target, :FOGGYEYE)
      ret /= 2
    end
    return ret
  end

  alias kifer_j_hitsFlyingTargets? hitsFlyingTargets? unless method_defined?(:kifer_j_hitsFlyingTargets?)
  def hitsFlyingTargets?
    return true if @kifer_j_desert
    return kifer_j_hitsFlyingTargets?
  end
end

# Giant Shuriken: Water Shuriken hits once, 100 power, +1 crit stage
# own alias names: PokeBattle_Move's kifer_j_ aliases would make the guards skip these
class PokeBattle_Move_0C0
  alias kifer_j_0c0_pbNumHits pbNumHits unless method_defined?(:kifer_j_0c0_pbNumHits)
  def pbNumHits(user, targets)
    return 1 if KIFER::BatchJ.giant_shuriken?(user, self)
    return kifer_j_0c0_pbNumHits(user, targets)
  end

  alias kifer_j_0c0_pbBaseDamage pbBaseDamage unless method_defined?(:kifer_j_0c0_pbBaseDamage)
  def pbBaseDamage(baseDmg, user, target)
    return 100 if KIFER::BatchJ.giant_shuriken?(user, self)
    return kifer_j_0c0_pbBaseDamage(baseDmg, user, target)
  end

  alias kifer_j_0c0_pbIsCritical? pbIsCritical? unless method_defined?(:kifer_j_0c0_pbIsCritical?)
  def pbIsCritical?(user, target)
    @kifer_j_giant = KIFER::BatchJ.giant_shuriken?(user, self)
    begin
      return kifer_j_0c0_pbIsCritical?(user, target)
    ensure
      @kifer_j_giant = false
    end
  end

  alias kifer_j_0c0_highCriticalRate? highCriticalRate? unless method_defined?(:kifer_j_0c0_highCriticalRate?)
  def highCriticalRate?
    return true if @kifer_j_giant
    return kifer_j_0c0_highCriticalRate?
  end
end

# Daredevil: half recoil (Limber's flag in 050)
class PokeBattle_RecoilMove
  alias kifer_j_pbEffectAfterAllHits pbEffectAfterAllHits unless method_defined?(:kifer_j_pbEffectAfterAllHits)
  def pbEffectAfterAllHits(user, target)
    half = user.hasActiveAbility?(:DAREDEVIL) && !user.instance_variable_get(:@kifer_v_half_hp_loss)
    user.instance_variable_set(:@kifer_v_half_hp_loss, true) if half
    begin
      kifer_j_pbEffectAfterAllHits(user, target)
    ensure
      user.instance_variable_set(:@kifer_v_half_hp_loss, nil) if half
    end
  end
end

# Cosmic Dust: an enraged foe's rampage damage x2 is hooked in 033, which
# defines KIFER::TerrainEnrage (this file loads first)
