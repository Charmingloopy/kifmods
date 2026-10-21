#===============================================================================
# KIF: Elite Redux – move names and descriptions through KIF's move text API
# (KIF::MoveText, KIF 0.21.63+), as 014 does for abilities: another mod
# (Differentiating Duplicates) shows its own text when its version wins (the
# highest priority wins). On older KIF nothing here runs and the mod's own
# GameData::Move aliases (060, 064) give ER's texts as before.
#
#   - ER-only moves (064): ER name and text, always.
#   - PIF moves: ER's text for the ready ones while Moves is applied (not for
#     moves another mod's version takes, KIFER::Moves.register_yield).
#===============================================================================
module KIFER
  module MoveTexts
    OWNER    = "KIF: Elite Redux"
    PRIORITY = 10   # another mod's version wins with a higher one

    module_function

    def api?
      return defined?(::KIF::MoveText) ? true : false
    end

    def sync
      return unless api? && defined?(GameData::Move::DATA) && !GameData::Move::DATA.empty?
      ::KIF::MoveText.unregister(OWNER)
      KIFER::ER_ONLY_MOVES.each do |id, e|
        m = GameData::Move::DATA[id]
        next unless m && m.instance_variable_get(:@kifer_new)
        ::KIF::MoveText.register(OWNER, id, name: e[:name], description: e[:desc], priority: PRIORITY)
      end
      return unless KIFER::Moves.applied?
      KIFER::MOVES.each do |id, e|
        next if e[:desc].to_s.empty? || !KIFER::Moves.ready?(id)
        ::KIF::MoveText.register(OWNER, id, description: e[:desc], priority: PRIORITY)
      end
    rescue StandardError => e
      KIFER.log("move texts: #{e.class}: #{e.message}")
    end
  end
end

KIFER::MoveTexts.sync
