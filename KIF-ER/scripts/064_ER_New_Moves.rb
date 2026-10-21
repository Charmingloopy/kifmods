#===============================================================================
# KIF: Elite Redux – Elite Redux moves PIF doesn't have (moves phase 2)
#   The ER-only moves that run on one of PIF's move classes as ER describes
#   them (":ready" in data/er_moves.rb ER_ONLY_MOVES, or coded by a later file)
#   are added to the game's move list while the mod is installed, whatever the
#   settings. With Innates and Moves On, species learn them from ER's lists.
#
#   Saves never hold their ids: a Pokemon's move keeps a PIF "stand-in" move
#   in @id (same type and category, nearest power) and the ER move in
#   @kifer_id. Pokemon::Move#id answers the ER move while Moves is applied,
#   otherwise the stand-in, so a save loads and plays without the mod (the
#   Pokemon knows the stand-in). The Move Relearner's first / learned move
#   lists keep the stand-in too, and the randomizer never rolls ER-only moves
#   (MOVES_PLAN question E). Animations: the stand-in's.
#===============================================================================
module KIFER
  module NewMoves
    ID_BASE = 9000
    LIST = KIFER::ER_ONLY_MOVES.keys   # data order (sorted): id number = ID_BASE + index

    # ER-only move that is (or would be) in the game
    def self.usable?(id)
      e = KIFER::ER_ONLY_MOVES[id]
      return false unless e
      return e[:ready] || KIFER::Moves::CODED.key?(id)
    end

    def self.er_only?(id)
      return KIFER::ER_ONLY_MOVES.key?(id)
    end

    def self.stand_in(id)
      return KIFER::ER_ONLY_MOVES[id][:stand_in]
    end

    # ER-only id for a value Pokemon::Move gets (Symbol, String, GameData::Move)
    def self.er_id(value)
      id = case value
           when Symbol then value
           when String then value.to_sym
           when GameData::Move then value.id
           else return nil
           end
      m = GameData::Move::DATA[id]
      return m && m.instance_variable_get(:@kifer_new) ? id : nil
    end

    # Adds the usable ER-only moves to the move list: again after a data load,
    # and the ones a later file codes (Moves.coded) on the next call
    def self.register
      return 0 unless defined?(GameData::Move::DATA) && !GameData::Move::DATA.empty?
      n = 0
      LIST.each_with_index do |id, i|
        next unless usable?(id)
        e = KIFER::ER_ONLY_MOVES[id]
        o = KIFER::Moves::CODED[id] || {}
        si = GameData::Move::DATA[e[:stand_in]]
        code = o[:function_code] || e[:code] || (si ? si.function_code : "000")
        h = {
          :id => id, :id_number => ID_BASE + i, :name => e[:name],
          :function_code => code,
          :base_damage => o[:power] || e[:power], :type => e[:type], :category => e[:category],
          :accuracy => o[:accuracy] || e[:accuracy], :total_pp => e[:pp],
          :effect_chance => o[:chance] || e[:chance], :target => o[:target] || e[:pif_target],
          :priority => o[:priority] || e[:priority], :flags => o[:flags] || e[:pif_flags],
          :description => e[:desc]
        }
        old = GameData::Move::DATA[id]
        next if old && !old.instance_variable_get(:@kifer_new)   # another mod's move by that id
        next if old && [old.function_code, old.base_damage, old.accuracy, old.effect_chance, old.target,
                         old.priority, old.flags] == h.values_at(:function_code, :base_damage, :accuracy,
                                                                 :effect_chance, :target, :priority, :flags)
        GameData::Move.register(h)
        m = GameData::Move::DATA[id]
        m.instance_variable_set(:@kifer_new, true)
        n += 1
      end
      # learnsets built from this data before the moves were in (060 loads
      # first); after a data reload, 060's sync builds them next
      if n > 0 && KIFER::Moves.applied? && GameData::Move::DATA.equal?(KIFER::Moves.instance_variable_get(:@data))
        KIFER::Moves.instance_variable_set(:@er_learn, nil)
        KIFER::Moves.set_learnsets(true)
      end
      KIFER::MoveTexts.sync if n > 0 && defined?(KIFER::MoveTexts)   # 065
      return n
    end
  end
end

module GameData
  class Move
    # ER names and texts (the game's message files don't have these moves)
    alias kifer_nm_name name unless method_defined?(:kifer_nm_name)
    def name
      return @real_name if @kifer_new
      return kifer_nm_name
    end

    alias kifer_nm_description description unless method_defined?(:kifer_nm_description)
    def description
      return @real_description if @kifer_new
      return kifer_nm_description
    end
  end
end

#-------------------------------------------------------------------------------
# A Pokemon's move: the stand-in in @id, the ER move in @kifer_id
#-------------------------------------------------------------------------------
class Pokemon
  class Move
    alias kifer_nm_initialize initialize unless method_defined?(:kifer_nm_initialize)
    def initialize(move_id)
      er = KIFER::NewMoves.er_id(move_id)
      return kifer_nm_initialize(move_id) unless er
      @id = KIFER::NewMoves.stand_in(er)
      @kifer_id = er
      @ppup = 0
      @pp = total_pp
    end

    # the ER move while Moves is applied and it is in the game (a save from a
    # mod version that had it, loaded with one that doesn't, shows the stand-in)
    def id
      return @id if !@kifer_id || !KIFER::Moves.applied?
      return GameData::Move::DATA.key?(@kifer_id) ? @kifer_id : @id
    end

    def id=(value)
      er = KIFER::NewMoves.er_id(value)
      if er
        @id = KIFER::NewMoves.stand_in(er)
        @kifer_id = er
      else
        @id = GameData::Move.get(value).id
        @kifer_id = nil
      end
      @pp = @pp.clamp(0, total_pp)
    end

    # PIF's readers look up @id; these look up the move in play
    def total_pp
      max_pp = GameData::Move.get(id).total_pp
      return max_pp + max_pp * @ppup / 5
    end
    alias totalpp total_pp

    def function_code; return GameData::Move.get(id).function_code; end
    def base_damage;   return GameData::Move.get(id).base_damage;   end
    def type;          return GameData::Move.get(id).type;          end
    def category;      return GameData::Move.get(id).category;      end
    def accuracy;      return GameData::Move.get(id).accuracy;      end
    def effect_chance; return GameData::Move.get(id).effect_chance; end
    def target;        return GameData::Move.get(id).target;        end
    def priority;      return GameData::Move.get(id).priority;      end
    def flags;         return GameData::Move.get(id).flags;         end
    def name;          return GameData::Move.get(id).name;          end
    def description;   return GameData::Move.get(id).description;   end
    def hidden_move?;  return GameData::Move.get(id).hidden_move?;  end
  end
end

#-------------------------------------------------------------------------------
# Lists in the save keep PIF moves only
#-------------------------------------------------------------------------------
class Pokemon
  def kifer_nm_saved(id)
    return id unless id.is_a?(Symbol) && KIFER::NewMoves.er_only?(id)
    return KIFER::NewMoves.stand_in(id)
  end

  alias kifer_nm_record_first_moves record_first_moves unless method_defined?(:kifer_nm_record_first_moves)
  def record_first_moves
    kifer_nm_record_first_moves
    @first_moves.map! { |m| kifer_nm_saved(m) }.uniq! if @first_moves
  end

  alias kifer_nm_add_first_move add_first_move unless method_defined?(:kifer_nm_add_first_move)
  def add_first_move(move_id)
    m = GameData::Move.try_get(move_id)
    return kifer_nm_add_first_move(m ? kifer_nm_saved(m.id) : move_id)
  end

  if method_defined?(:add_learned_move)
    alias kifer_nm_add_learned_move add_learned_move unless method_defined?(:kifer_nm_add_learned_move)
    def add_learned_move(move)
      id = move.is_a?(Symbol) ? move : (move.respond_to?(:id) ? move.id : move)
      return kifer_nm_add_learned_move(kifer_nm_saved(id))
    end
  end
end

# The randomizer's move changes are saved: its picks are PIF moves, and the
# saved lists hold stand-ins (060 re-rolls them from the lists in use when the
# mod is loaded, so ER moves still come back)
module KIFER
  module NewMoves
    def self.saveable_species(ch)
      return unless ch.is_a?(Hash)
      ch.each_value do |f|
        next unless f.is_a?(Hash)
        f[:@moves] = f[:@moves].map { |l, m| [l, saved_id(m)] } if f[:@moves].is_a?(Array)
        [:@tutor_moves, :@egg_moves].each do |k|
          f[k] = f[k].map { |m| saved_id(m) }.uniq if f[k].is_a?(Array)
        end
      end
    end

    def self.saved_id(m)
      return er_only?(m) ? stand_in(m) : m
    end
  end
end

if defined?(KIF::Rand) && KIF::Rand.respond_to?(:move_pool)
  module KIF
    module Rand
      class << self
        alias kifer_nm_move_pool move_pool unless method_defined?(:kifer_nm_move_pool)
        def move_pool
          pool = kifer_nm_move_pool
          @kifer_nm_pool = [pool, pool.reject { |m| m.instance_variable_get(:@kifer_new) }] unless @kifer_nm_pool && @kifer_nm_pool[0].equal?(pool)
          return @kifer_nm_pool[1]
        end

        if method_defined?(:randomize_data)
          alias kifer_nm_randomize_data randomize_data unless method_defined?(:kifer_nm_randomize_data)
          def randomize_data
            ret = kifer_nm_randomize_data   # applied as rolled (copies), then the saved copy is cleaned
            KIFER::NewMoves.saveable_species(data[:species])
            return ret
          end
        end
      end
    end
  end
end

# Secret bases are shared with other players: PIF moves only
if defined?(SecretBaseExporter) && SecretBaseExporter.method_defined?(:export_fused_pokemon_hash)
  class SecretBaseExporter
    alias kifer_nm_export_fused_pokemon_hash export_fused_pokemon_hash unless method_defined?(:kifer_nm_export_fused_pokemon_hash)
    def export_fused_pokemon_hash(pokemon)
      h = kifer_nm_export_fused_pokemon_hash(pokemon)
      if h.is_a?(Hash) && h[:moves].is_a?(Array)
        h[:moves] = h[:moves].map { |m| KIFER::NewMoves.saved_id(m.to_sym).to_s }
      end
      return h
    end
  end
end

# Animations: the stand-in's
class PokeBattle_Battle
  alias kifer_nm_pbAnimation pbAnimation unless method_defined?(:kifer_nm_pbAnimation)
  def pbAnimation(move, user, targets, hitNum = 0)
    id = move.respond_to?(:id) ? move.id : nil
    return kifer_nm_pbAnimation(move, user, targets, hitNum) unless id && KIFER::NewMoves.er_only?(id) &&
                                                                    move.instance_variable_defined?(:@id)
    move.instance_variable_set(:@id, KIFER::NewMoves.stand_in(id))
    begin
      return kifer_nm_pbAnimation(move, user, targets, hitNum)
    ensure
      move.instance_variable_set(:@id, id)
    end
  end
end

KIF::DataLoad.after_load_all("KIF-ER: Elite Redux new moves") { KIFER::NewMoves.register } if defined?(KIF::DataLoad)
KIFER::NewMoves.register
