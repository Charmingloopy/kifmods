#===============================================================================
# The abilities of Z-A's new Megas that PIF doesn't have, working as in Z-A /
# Pokémon Champions (Cody: "Create the ability that they use in Z-A"):
#   Mega Sol    (Mega Meganium)   its moves act as if the weather were harsh sunlight
#   Aura Guard  (Mega Lucario Z)  contact moves deal it half damage
#   Sharpness   (Mega Absol Z)    slicing moves x1.5
#   Unseen Fist (Mega Golurk)     contact moves hit through Protect and the like
#   Eelevate    (Mega Eelektross) floats (Ground immunity, no hazards) and
#                                 raises its best stat when it knocks out a foe
#   Stalwart    (Mega Skarmory)   its moves can't be drawn away (Follow Me,
#                                 Rage Powder, Spotlight, Lightning Rod, Storm Drain)
# One another mod already registered is left alone (handlers included): with
# KIF-ER's Innates on, its Elite Redux versions are used. With KIF-ER installed
# but Innates off, Megas' Z-A versions run (Cody, 2026-10-19: "without KIF:ER:
# official ability"; KIF-ER's own handlers stand down then).
#===============================================================================
module Megas
  ABILITY_ID_BASE = 8500 unless defined?(ABILITY_ID_BASE)   # KIF-ER uses 9000+
  ABILITIES = {
    :MEGASOL    => ["Mega Sol",    "Its moves act as if the weather were harsh sunlight."],
    :AURAGUARD  => ["Aura Guard",  "Halves the damage taken from contact moves."],
    :SHARPNESS  => ["Sharpness",   "Powers up slicing moves."],
    :UNSEENFIST => ["Unseen Fist", "Contact moves hit through the target's protection."],
    :EELEVATE   => ["Eelevate",    "Floats. Its best stat rises when it knocks out a foe."],
    :STALWART   => ["Stalwart",    "Ignores moves and abilities that draw in moves."]
  } unless defined?(ABILITIES)
  # Slicing moves (Gen 9 list); ones PIF doesn't have are simply never used
  SLICING = [:AERIALACE, :AIRCUTTER, :AIRSLASH, :AQUACUTTER, :BEHEMOTHBLADE, :BITTERBLADE,
             :CEASELESSEDGE, :CROSSPOISON, :CUT, :FURYCUTTER, :KOWTOWCLEAVE, :LEAFBLADE,
             :MIGHTYCLEAVE, :NIGHTSLASH, :POPULATIONBOMB, :PSYBLADE, :PSYCHOCUT, :RAZORLEAF,
             :RAZORSHELL, :SACREDSWORD, :SECRETSWORD, :SLASH, :SOLARBLADE, :STONEAXE,
             :TACHYONCUTTER, :XSCISSOR] unless defined?(SLICING)

  def self.own_ability?(id)
    a = GameData::Ability::DATA[id]
    return a && a.instance_variable_get(:@megas_own) == true
  end

  # Does Megas' own (Z-A) version of this ability run right now?
  def self.za_on?(id)
    return true if own_ability?(id)
    return defined?(::KIFER) && GameData::Ability::DATA.key?(id) && !er? ? true : false
  end

  def self.register_abilities
    ABILITIES.each_with_index do |(id, (name, desc)), i|
      next if GameData::Ability::DATA[id] && !own_ability?(id)
      n = ABILITY_ID_BASE + i
      GameData::Ability.register({ :id => id, :id_number => n, :name => name, :description => desc })
      GameData::Ability::DATA[id].instance_variable_set(:@megas_own, true)
      MessageTypes.set(MessageTypes::Abilities, n, name)
      MessageTypes.set(MessageTypes::AbilityDescs, n, desc)
    end
    register_ability_handlers
  end

  def self.register_ability_handlers
    if own_ability?(:AURAGUARD)
      BattleHandlers::DamageCalcTargetAbility.add(:AURAGUARD,
        proc { |_ability, user, _target, move, mults, _baseDmg, _type|
          mults[:final_damage_multiplier] *= 0.5 if move.pbContactMove?(user)
        })
    end
    if own_ability?(:SHARPNESS)
      BattleHandlers::DamageCalcUserAbility.add(:SHARPNESS,
        proc { |_ability, _user, _target, move, mults, _baseDmg, _type|
          mults[:base_damage_multiplier] *= 1.5 if SLICING.include?(move.id)
        })
    end
    BattleHandlers::UserAbilityEndOfMove.copy(:BEASTBOOST, :EELEVATE) if own_ability?(:EELEVATE)
  end
end

KIF::DataLoad.after_load_all("Megas: abilities") { Megas.register_abilities }
Megas.register_abilities if GameData::Ability::DATA.key?(:OVERGROW)   # data already loaded (reload, tests)

# Mega Sol and Unseen Fist need to know whose move is running
class PokeBattle_Battle
  attr_accessor :megas_user   # the battler using a move right now (nil between moves)

  # Mega Sol: during its own moves the weather counts as harsh sunlight
  # (Primal Groudon's Desolate Land already is)
  alias megas_pbWeather pbWeather unless method_defined?(:megas_pbWeather)
  def pbWeather
    w = megas_pbWeather
    return :Sun if @megas_sun && w != :HarshSun
    return w
  end
end

class PokeBattle_Battler
  alias megas_za_pbUseMove pbUseMove unless method_defined?(:megas_za_pbUseMove)
  def pbUseMove(*args, &blk)
    prev_user, prev_sun = @battle.megas_user, @battle.instance_variable_get(:@megas_sun)
    @battle.megas_user = self
    sun = Megas.za_on?(:MEGASOL) && hasActiveAbility?(:MEGASOL)
    @battle.instance_variable_set(:@megas_sun, sun)
    return megas_za_pbUseMove(*args, &blk)
  ensure
    @battle.megas_user = prev_user
    @battle.instance_variable_set(:@megas_sun, prev_sun)
  end

  # Eelevate floats like Levitate (Iron Ball, Ingrain, Smack Down and Gravity still ground it)
  alias megas_airborne? airborne? unless method_defined?(:megas_airborne?)
  def airborne?
    return true if megas_airborne?
    return false if hasActiveItem?(:IRONBALL) || @effects[PBEffects::Ingrain] ||
                    @effects[PBEffects::SmackDown] || @battle.field.effects[PBEffects::Gravity] > 0
    return Megas.za_on?(:EELEVATE) && hasActiveAbility?(:EELEVATE) && !@battle.moldBreaker
  end
end

class PokeBattle_Battler
  # Stalwart: its moves keep their target
  alias megas_pbChangeTargets pbChangeTargets unless method_defined?(:megas_pbChangeTargets)
  def pbChangeTargets(move, user, targets)
    return targets if user && Megas.za_on?(:STALWART) && user.hasActiveAbility?(:STALWART)
    return megas_pbChangeTargets(move, user, targets)
  end
end

class PokeBattle_Move
  # Unseen Fist: contact moves ignore Protect, Detect, King's Shield and the like
  alias megas_canProtectAgainst? canProtectAgainst? unless method_defined?(:megas_canProtectAgainst?)
  def canProtectAgainst?
    u = @battle.megas_user
    return false if u && Megas.za_on?(:UNSEENFIST) && u.hasActiveAbility?(:UNSEENFIST) && pbContactMove?(u)
    return megas_canProtectAgainst?
  end
end
