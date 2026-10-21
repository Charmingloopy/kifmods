#===============================================================================
# KIF: Elite Redux – PIF's fusion screen ability pick
#   When two Pokémon fuse, PIF lets the player pick one of the two parents'
#   abilities (with the mod on, those are their ER choices). The pick is
#   kept as the fusion's choice (the same ability, from that parent's half of
#   the list), instead of falling back to the default start pick.
#   Dual-ability fusions also get the other parent's ability as Ability 2.
#   Hooked on pbFusionScreen (the whole fusion), which KIF's own fusion hooks
#   use too: the parents' picks are read before PIF changes the species, and
#   the ability PIF stored is read after.
#
#   Fusion ability picker (Cody, 2026-10-13): with Innates on, PIF's ability
#   row (only the two parents' current abilities) is taken off its fusion
#   screen, and once the fusion is done the player picks from all of the
#   fusion's choices (head's 3 + body's 3); dual fusions pick Ability 1 and 2.
#   Cancel keeps the start pick. If the row couldn't be taken off, the
#   ability picked on PIF's screen is kept instead (above).
#===============================================================================
module KIFER
  # Before the fusion: what each parent shows (PIF's own abilities, as
  # raw_ability is on) and which choice it is
  def self.fusion_pick_before(body, head)
    return nil unless enabled? && body && head
    return nil if body.isFusion? || head.isFusion?
    return {
      :species => body.species,
      :shown   => [body.ability_id, head.ability_id],
      :b       => choice_index(body),
      :h       => choice_index(head)
    }
  rescue StandardError => e
    log("fusion pick (before) failed: #{e.class}: #{e.message}")
    return nil
  end

  # After the fusion: the parent whose ability was picked gives the choice
  def self.fusion_pick_after(fused, ctx)
    return unless ctx && fused && fused.isFusion? && fused.species != ctx[:species]
    sel = fused.instance_variable_get(:@ability)
    sel = sel.id if sel.respond_to?(:id)
    head_n = choices_of(fused.get_head_species.id).length
    slots = [ctx[:b] && head_n + ctx[:b], ctx[:h]]
    pick = ctx[:shown].index(sel)
    if pick.nil? || slots[pick].nil?
      log("fusion pick: #{sel.inspect} isn't one of #{ctx[:shown].inspect}, start pick kept")
      return
    end
    set_choice(fused, slots[pick])
    other = slots[1 - pick]
    set_choice2(fused, other) if other && dual?(fused) && other != slots[pick]
    log("fusion pick: #{ctx[:shown].join(' / ')} -> #{sel} (#{pick == 0 ? 'body' : 'head'}), " \
        "now #{chosen_ability(fused).inspect} (#{choice_index(fused).to_i + 1} of #{choice_list(fused).length})")
  rescue StandardError => e
    log("fusion pick (after) failed: #{e.class}: #{e.message}")
  end
end

module KIFER
  class << self
    attr_accessor :fusion_row_hidden
  end

  def self.fusion_choice_label(fused, list, i, head_n)
    s = ability_name(list[i]) + (i < head_n ? _INTL(" (head)") : _INTL(" (body)"))
    s += _INTL(" (not in yet)") unless coded?(list[i])
    return s
  end

  # The player picks the fusion's ability (and Ability 2 for dual fusions)
  def self.fusion_ability_picker(fused)
    list = choice_list(fused)
    return if list.empty?
    head_n = choices_of(fused.get_head_species.id).length
    slots = dual?(fused) ? [1, 2] : [1]
    slots.each do |slot|
      cur = (slot == 1) ? choice_index(fused) : choice2_index(fused)
      cmds = (0...list.length).map do |i|
        s = fusion_choice_label(fused, list, i, head_n)
        s += _INTL(" (now)") if i == cur
        s
      end
      msg = (slots.length > 1) ? _INTL("Pick {1}'s Ability {2}.", fused.name, slot) : _INTL("Pick {1}'s ability.", fused.name)
      c = pbMessage(msg, cmds, -1, nil, cur || 0)
      next if c.nil? || c < 0 || c == cur
      (slot == 1) ? set_choice(fused, c) : set_choice2(fused, c)
    end
    log("fusion pick: #{fused.name} -> #{chosen_ability(fused).inspect}" +
        (dual?(fused) ? " + #{chosen_ability2(fused).inspect}" : ""))
  rescue StandardError => e
    log("fusion picker failed: #{e.class}: #{e.message}")
  end
end

if defined?(FusionSelectOptionsScene) && FusionSelectOptionsScene.method_defined?(:pbGetOptions)
  class FusionSelectOptionsScene
    alias kifer_pbGetOptions pbGetOptions unless method_defined?(:kifer_pbGetOptions)
    def pbGetOptions(*args)
      options = kifer_pbGetOptions(*args)
      return options unless KIFER.enabled?
      begin
        kept = options.reject { |o| o.respond_to?(:name) && o.name == _INTL("Ability") }
        if kept.length < options.length
          # PIF still stores an ability when the screen closes: give it one
          @selectedAbility ||= (@abilityList.is_a?(Array) ? @abilityList[0] : nil)
          KIFER.fusion_row_hidden = true
          return kept
        end
      rescue StandardError => e
        KIFER.log("fusion screen: ability row not taken off: #{e.class}: #{e.message}")
      end
      return options
    end
  end
end

if defined?(PokemonFusionScene) && PokemonFusionScene.method_defined?(:pbFusionScreen)
  class PokemonFusionScene
    alias kifer_pbFusionScreen pbFusionScreen unless method_defined?(:kifer_pbFusionScreen)
    def pbFusionScreen(*args)
      KIFER.fusion_row_hidden = false
      KIFER.raw_ability = true
      begin
        ctx = KIFER.fusion_pick_before(@pokemon1, @pokemon2)
        ret = kifer_pbFusionScreen(*args)
      ensure
        KIFER.raw_ability = false
      end
      if ctx && @pokemon1 && @pokemon1.isFusion? && @pokemon1.species != ctx[:species]
        if KIFER.fusion_row_hidden
          KIFER.fusion_ability_picker(@pokemon1)
        else
          KIFER.fusion_pick_after(@pokemon1, ctx)
        end
      end
      KIFER.fusion_row_hidden = false
      return ret
    end
  end
else
  KIFER.log("fusion pick: PIF's fusion screen wasn't found, picks there won't carry over")
end
