#===============================================================================
# KIF: Elite Redux – Summary screen: ABILITIES tab (approved mock-up, 2026-10-13)
#   Six tabs: Info, Memo, Skills, ABILITIES (new, purple), Moves, Pokédex.
#   * The tab strip is drawn into each page's background, so the mod uses
#     6-tab copies of PIF's backgrounds, drawn at run time from PIF's own
#     pictures (012_Graphics). PIF's own files are untouched; while the mod is
#     on, the Summary's background sprite shows the mod's copy instead.
#   * Abilities page: ability + 3 innates, like the Moves page lists moves.
#     Dual-ability fusions (010): 2 abilities + all 6 innates in one-line rows.
#     C opens the detail view: full text of the selected one on the left,
#     Up/Down to move, Left/Right for more text; C on the ability picks 1 of
#     the choice abilities, C on an innate (fusions) picks 3 of the 6.
#   * pbScene: the copy that runs is 053_PIF_Hoenn's contest version; the mod
#     runs its own copy of it with the extra page (guarded below).
#   With Innates Off everything is PIF's.
#===============================================================================
module KIFER
  module SummaryUI
    GFX_DIR = "KIF-ER/Summary"   # name prefix of the drawn pictures (no files)
    # PIF / KIF background -> the mod's 6-tab copy
    MAP = {
      "graphics/pictures/summary/bg_1"          => "bg_1",
      "graphics/pictures/summary/bg_2"          => "bg_2",
      "graphics/pictures/summary/bg_3"          => "bg_3",
      "graphics/pictures/kif/summary_bg_3"      => "kif_bg_3",
      "graphics/pictures/summary/bg_4"          => "bg_5",
      "graphics/pictures/summary/bg_5"          => "bg_6",
      "graphics/pictures/summary/bg_movedetail" => "bg_movedetail"
    }
    VPAGE_OF = { 1 => 1, 2 => 2, 3 => 3, 4 => 5, 5 => 6 }   # PIF page -> tab
    PAGE_OF  = { 1 => 1, 2 => 2, 3 => 3, 5 => 4, 6 => 5 }   # tab -> PIF page
    ROW_YS   = [98, 162, 226, 290]
    LINES_PER_TEXT_PAGE = 9
    SCENE_CRC = 1562955877   # 053_PIF_Hoenn/.../014_Summary.rb (LF) when the copy was made

    # PIF's own picture to show if a drawn one can't be made
    FALLBACK = {
      "bg_4"           => "Graphics/Pictures/Summary/bg_4",
      "bg_abil_detail" => "Graphics/Pictures/Summary/bg_movedetail"
    }

    def self.gfx(name)
      return GFX_DIR + "/" + name
    end

    # Name of the drawn picture for a PIF path or a gfx() name, or nil
    def self.name_of(file)
      key = file.to_s.tr("\\", "/").downcase.sub(/\.png\z/, "")
      return MAP[key] if MAP[key]
      pre = GFX_DIR.downcase + "/"
      return key.start_with?(pre) ? file.to_s[pre.length..-1] : nil
    end

    # The drawn 6-tab Bitmap for `file`, or nil
    def self.picture(file)
      n = name_of(file)
      return n ? KIFER::Gfx.summary(n) : nil
    end

    def self.fallback(file)
      n = name_of(file)
      return file if !n || MAP.key?(file.to_s.tr("\\", "/").downcase.sub(/\.png\z/, ""))
      return FALLBACK[n] || MAP.key(n) || file
    end

    # Words -> lines that fit `width` (bitmap's current font); "\n" = new paragraph
    def self.wrap(bitmap, text, width)
      out = []
      text.to_s.split("\n").each do |para|
        if para.strip.empty?
          out << ""
          next
        end
        line = ""
        para.split(" ").each do |word|
          t = line.empty? ? word : line + " " + word
          if bitmap.text_size(t).width <= width
            line = t
          else
            out << line unless line.empty?
            line = word
          end
        end
        out << line unless line.empty?
      end
      out.pop while out.last == ""
      return out
    end
  end
end

class PokemonSummary_Scene
  INNATES_PURPLE       = Color.new(96, 64, 152)
  INNATES_PURPLE_SHADE = Color.new(200, 184, 232)
  INNATES_GREY         = Color.new(144, 152, 160)
  INNATES_GREY_SHADE   = Color.new(208, 216, 224)

  alias kifer_pbStartScene pbStartScene unless method_defined?(:kifer_pbStartScene)
  def pbStartScene(*args, &block)
    @kifer_tab = KIFER.enabled?
    @kifer_vpage = 1
    kifer_pbStartScene(*args, &block)
  end

  def kifer_tab?
    return @kifer_tab ? true : false
  end

  # Make the background sprite show the 6-tab copies (once per scene)
  def kifer_hook_background
    return if !kifer_tab? || @kifer_bg_hooked
    bg = @sprites && @sprites["background"]
    return unless bg
    bg.define_singleton_method(:setBitmap) do |file, *rest|
      if !respond_to?(:setBitmapDirectly)
        super(file, *rest)
      elsif (bmp = KIFER::SummaryUI.picture(file))
        setBitmapDirectly(KIFER::Gfx::Picture.new(bmp))
      else
        super(KIFER::SummaryUI.fallback(file), *rest)
      end
    end
    @kifer_bg_hooked = true
  rescue StandardError => e
    KIFER.log("Summary background hook failed: #{e.class}: #{e.message}")
  end

  alias kifer_drawPage drawPage unless method_defined?(:kifer_drawPage)
  def drawPage(page)
    kifer_hook_background
    if kifer_tab? && @kifer_vpage == 4 && !@pokemon.egg?
      kifer_draw_abilities_page
      return
    end
    kifer_drawPage(page)
  end

  #-----------------------------------------------------------------------------
  # Page drawing
  #-----------------------------------------------------------------------------
  def kifer_rows
    rows = []
    list = KIFER.choice_list(@pokemon)
    idx = KIFER.choice_index(@pokemon)
    if idx && KIFER.forced?(@pokemon)
      rows << [:ability, @pokemon.ability_id, idx, 0]   # capsule / script ability: n = 0, no "x of y"
    elsif idx
      rows << [:ability, list[idx], idx, list.length]
    end
    idx2 = KIFER.respond_to?(:choice2_index) ? KIFER.choice2_index(@pokemon) : nil
    rows << [:ability2, list[idx2], idx2, list.length] if idx2
    inn = @pokemon.innates
    inn.each_with_index { |id, i| rows << [:innate, id, i, inn.length] }
    return rows
  end

  def kifer_draw_rows(overlay, sel)
    rows = kifer_rows
    return kifer_draw_rows_compact(overlay, sel, rows) if rows.length > KIFER::SummaryUI::ROW_YS.length
    labels = []
    names = []
    rows.each_with_index do |(kind, id, i, n), r|
      y = KIFER::SummaryUI::ROW_YS[r]
      break unless y
      label = (kind == :ability) ? _INTL("Ability  {1} of {2}", i + 1, n) : _INTL("Innate  {1} of {2}", i + 1, n)
      label = _INTL("Ability") if kind == :ability && n == 0
      coded = KIFER.coded?(id)
      label += _INTL("  (soon)") unless coded
      labels << [label, 256, y - 2, 0, INNATES_PURPLE, INNATES_PURPLE_SHADE]
      names << [KIFER.ability_name(id), 256, y + 22, 0,
                coded ? @text_color_base : INNATES_GREY, coded ? @text_color_shadow : INNATES_GREY_SHADE]
    end
    pbSetSmallFont(overlay)
    pbDrawTextPositions(overlay, labels)
    pbSetSystemFont(overlay)
    pbDrawTextPositions(overlay, names)
    if sel
      y = KIFER::SummaryUI::ROW_YS[sel]
      c = Color.new(248, 120, 32)
      overlay.fill_rect(244, y - 4, 244, 4, c)
      overlay.fill_rect(244, y + 56, 244, 4, c)
      overlay.fill_rect(244, y - 4, 4, 64, c)
      overlay.fill_rect(484, y - 4, 4, 64, c)
    end
    return rows
  end

  # Dual abilities (layout A, Cody 2026-10-13): up to 8 one-line rows,
  # a line under the abilities
  COMPACT_TOP = 96
  COMPACT_H   = 32

  def kifer_draw_rows_compact(overlay, sel, rows)
    panel = Color.new(224, 232, 232)
    line  = Color.new(200, 208, 216)
    dark  = Color.new(64, 64, 64)
    overlay.fill_rect(244, COMPACT_TOP, 242, COMPACT_H * 8 + 2, panel)
    labels = []
    names = []
    n_ab = rows.count { |r| r[0] != :innate }
    rows.first(8).each_with_index do |(kind, id, i, _n), r|
      y = COMPACT_TOP + r * COMPACT_H
      if r > 0
        if r == n_ab
          overlay.fill_rect(244, y - 1, 242, 2, dark)
        else
          overlay.fill_rect(244, y, 242, 1, line)
        end
      end
      label = case kind
              when :ability  then _INTL("Ability 1")
              when :ability2 then _INTL("Ability 2")
              else _INTL("Innate {1}", i + 1)
              end
      coded = KIFER.coded?(id)
      labels << [label, 250, y + 2, 0, INNATES_PURPLE, INNATES_PURPLE_SHADE]
      names << [KIFER.ability_name(id), 346, y, 0,
                coded ? @text_color_base : INNATES_GREY, coded ? @text_color_shadow : INNATES_GREY_SHADE]
    end
    pbSetSmallFont(overlay)
    pbDrawTextPositions(overlay, labels)
    pbSetNarrowFont(overlay)
    pbDrawTextPositions(overlay, names)
    pbSetSystemFont(overlay)
    if sel
      y = COMPACT_TOP + sel * COMPACT_H
      c = Color.new(248, 120, 32)
      overlay.fill_rect(242, y - 1, 246, 3, c)
      overlay.fill_rect(242, y + COMPACT_H - 1, 246, 3, c)
      overlay.fill_rect(242, y - 1, 3, COMPACT_H + 3, c)
      overlay.fill_rect(485, y - 1, 3, COMPACT_H + 3, c)
    end
    return rows
  end

  def kifer_innates_pickable?
    return @pokemon.isFusion? && !(KIFER.respond_to?(:dual?) && KIFER.dual?(@pokemon))
  end

  def kifer_draw_abilities_page
    cp = @contestpage
    @contestpage = false
    begin
      kifer_drawPage(3)        # Info panel, sprite, item... (and Skills, cleared below)
    ensure
      @contestpage = cp
    end
    @page = 3
    kifer_hook_background
    @sprites["background"].setBitmap(KIFER::SummaryUI.gfx("bg_4"))
    overlay = @sprites["overlay"].bitmap
    overlay.clear_rect(0, 0, 220, 50)
    overlay.clear_rect(210, 56, 302, 328)
    base = Color.new(248, 248, 248)
    shadow = Color.new(104, 104, 104)
    pbSetSystemFont(overlay)
    pbDrawTextPositions(overlay, [[_INTL("ABILITIES"), 26, 10, 0, base, shadow]])
    kifer_draw_rows(overlay, nil)
  end

  # Returns the number of text pages for the selected row
  def kifer_draw_detail(sel, tpage)
    kifer_hook_background
    @sprites["background"].setBitmap(KIFER::SummaryUI.gfx("bg_abil_detail"))
    overlay = @sprites["overlay"].bitmap
    overlay.clear
    base = Color.new(248, 248, 248)
    shadow = Color.new(104, 104, 104)
    pbSetSystemFont(overlay)
    pbDrawTextPositions(overlay, [[_INTL("ABILITIES"), 26, 10, 0, base, shadow]])
    rows = kifer_draw_rows(overlay, sel)
    kind, id, _i, _n = rows[sel]
    pbSetSystemFont(overlay)
    pbDrawTextPositions(overlay, [[KIFER.ability_name(id), 8, 68, 0, @text_color_base, @text_color_shadow]])
    pbSetNarrowFont(overlay)
    lines = KIFER::SummaryUI.wrap(overlay, KIFER.ability_full_text(id), 224)
    per = KIFER::SummaryUI::LINES_PER_TEXT_PAGE
    pages = [(lines.length + per - 1) / per, 1].max
    tpage = [[tpage, 0].max, pages - 1].min
    textpos = []
    lines[tpage * per, per].to_a.each_with_index do |l, i|
      textpos << [l, 8, 108 + i * 26, 0, @text_color_base, @text_color_shadow]
    end
    pbDrawTextPositions(overlay, textpos)
    pbSetSmallFont(overlay)
    hints = []
    hints << _INTL("Page {1}/{2}", tpage + 1, pages) if pages > 1
    if @is_player && !@inbattle
      hints << _INTL("C: change") if kind == :ability || kind == :ability2 || (kind == :innate && kifer_innates_pickable?)
    end
    pbDrawTextPositions(overlay, [[hints.join("   "), 8, 350, 0, INNATES_GREY, INNATES_GREY_SHADE]]) unless hints.empty?
    pbSetSystemFont(overlay)
    return pages
  end

  #-----------------------------------------------------------------------------
  # Detail view and picking
  #-----------------------------------------------------------------------------
  def kifer_ability_detail
    return if kifer_rows.empty?
    hidden = []
    %w[pokemon itemicon pokeicon].each do |k|
      next unless @sprites[k] && @sprites[k].visible
      @sprites[k].visible = false
      hidden << k
    end
    sel = 0
    tpage = 0
    pages = kifer_draw_detail(sel, tpage)
    loop do
      Graphics.update
      Input.update
      pbUpdate
      n = kifer_rows.length
      redraw = false
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::UP)
        sel = (sel - 1) % n; tpage = 0; pbPlayCursorSE; redraw = true
      elsif Input.trigger?(Input::DOWN)
        sel = (sel + 1) % n; tpage = 0; pbPlayCursorSE; redraw = true
      elsif Input.trigger?(Input::LEFT) && tpage > 0
        tpage -= 1; pbPlayCursorSE; redraw = true
      elsif Input.trigger?(Input::RIGHT) && tpage < pages - 1
        tpage += 1; pbPlayCursorSE; redraw = true
      elsif Input.trigger?(Input::USE) && @is_player && !@inbattle
        kind = kifer_rows[sel][0]
        if kind == :ability || kind == :ability2
          pbPlayDecisionSE
          kifer_pick_choice(kind == :ability2 ? 2 : 1)
        elsif kind == :innate && kifer_innates_pickable?
          pbPlayDecisionSE
          kifer_pick_innates
        end
        redraw = true
      end
      pages = kifer_draw_detail(sel, tpage) if redraw
    end
    hidden.each { |k| @sprites[k].visible = true }
  end

  def kifer_pick_choice(slot = 1)
    list = KIFER.choice_list(@pokemon)
    one = KIFER.choice_index(@pokemon)
    two = KIFER.respond_to?(:choice2_index) ? KIFER.choice2_index(@pokemon) : nil
    cur   = (slot == 2) ? two : one
    other = (slot == 2) ? one : two
    return false if list.empty? || cur.nil?
    head_n = @pokemon.isFusion? ? KIFER.choices_of(@pokemon.get_head_species.id).length : 0
    cmds = list.each_with_index.map do |id, i|
      s = KIFER.ability_name(id)
      s += (i < head_n ? _INTL(" (head)") : _INTL(" (body)")) if @pokemon.isFusion?
      s += _INTL(" (now)") if i == cur && !(slot == 1 && KIFER.forced?(@pokemon))
      s += _INTL(" (Ability {1})", slot == 2 ? 1 : 2) if other && i == other
      s += _INTL(" (not in yet)") unless KIFER.coded?(id)
      s
    end
    cmds << _INTL("Cancel")
    c = pbShowCommands(cmds, cur)
    return false if c.nil? || c < 0 || c >= list.length
    return false if c == cur && !(slot == 1 && KIFER.forced?(@pokemon))
    if slot == 2
      KIFER.set_choice2(@pokemon, c)
    else
      KIFER.set_choice(@pokemon, c)
    end
    return true
  end

  # Fusion innate picker (Cody's mockup, 2026-10-21): the 6 innates grouped by
  # head / body on the right, the highlighted one's full text on the left
  # (Left/Right pages long texts). Any number can be ticked; Done saves only
  # with exactly 3 (grey under, red over; Cody 2026-10-21)
  def kifer_pick_innates
    head = @pokemon.get_head_species.id
    body = @pokemon.get_body_species.id
    pool = KIFER.fusion_pool(head, body)
    head_n = KIFER.species_innates(head).length
    want = [3, pool.length].min
    # ticked slots (pool indexes); an innate both parents have is two slots
    chosen = []
    @pokemon.innates.each do |id|
      i = (0...pool.length).find { |k| pool[k] == id && !chosen.include?(k) }
      chosen << i if i
    end
    names = [GameData::Species.get(head).name, GameData::Species.get(body).name]
    sel = 0
    tpage = 0
    pages = kifer_draw_innate_picker(pool, head_n, names, chosen, want, sel, tpage)
    loop do
      Graphics.update
      Input.update
      pbUpdate
      n = pool.length + 1     # + Done
      redraw = false
      if Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        return false
      elsif Input.trigger?(Input::UP)
        sel = (sel - 1) % n; tpage = 0; pbPlayCursorSE; redraw = true
      elsif Input.trigger?(Input::DOWN)
        sel = (sel + 1) % n; tpage = 0; pbPlayCursorSE; redraw = true
      elsif Input.trigger?(Input::LEFT) && tpage > 0
        tpage -= 1; pbPlayCursorSE; redraw = true
      elsif Input.trigger?(Input::RIGHT) && tpage < pages - 1
        tpage += 1; pbPlayCursorSE; redraw = true
      elsif Input.trigger?(Input::USE)
        if sel == pool.length
          if chosen.length == want
            pbPlayDecisionSE
            @pokemon.kifer_pick = chosen.sort.map { |k| pool[k] }
            return true
          end
          pbPlayBuzzerSE
          pbDisplay(_INTL("Pick {1} innates.", want))
        elsif chosen.include?(sel)
          pbPlayCursorSE
          chosen.delete(sel)
        else
          pbPlayDecisionSE
          chosen << sel
        end
        redraw = true
      end
      pages = kifer_draw_innate_picker(pool, head_n, names, chosen, want, sel, tpage) if redraw
    end
  end

  # Text centred in a box with KIF's pixel font (KIF::PixelFont, the KIF
  # Settings screen's text: crisp, and placed by its real height); older KIF:
  # the engine's text. font: :title / :row / :text; align 0 left, 1 right, 2 centre
  def kifer_px(b, x, y, w, h, str, base, shade, font, align = 0)
    str = str.to_s
    if defined?(KIF::PixelFont) && KIF::PixelFont.respond_to?(:draw) && KIF::PixelFont.const_defined?(:TEXT)
      f = { :title => KIF::PixelFont::TITLE, :row => KIF::PixelFont::ROW }[font] || KIF::PixelFont::TEXT
      sw = KIF::PixelFont.width(f, str)
      tx = align == 1 ? x + w - sw : (align == 2 ? x + (w - sw) / 2 : x)
      # centre the capitals (glyph "A"), not the font's line height
      cap = KIF::PixelFont.glyph(KIF::PixelFont.data(f), "A") rescue nil
      ty = cap ? y + (h - cap[4]) / 2 - cap[2] : y + (h - KIF::PixelFont.height(f)) / 2
      [[2, 0], [0, 2], [2, 2]].each { |dx, dy| KIF::PixelFont.draw(b, tx + dx, ty + dy, str, f, shade) }
      KIF::PixelFont.draw(b, tx, ty, str, f, base)
      return
    end
    font == :row ? pbSetNarrowFont(b) : (font == :title ? pbSetSystemFont(b) : pbSetSmallFont(b))
    ax = align == 1 ? x + w : (align == 2 ? x + w / 2 : x)
    pbDrawTextPositions(b, [[str, ax, y + (h - 26) / 2, align, base, shade]])
    pbSetSystemFont(b)
  end

  # Returns the number of text pages on the left
  def kifer_draw_innate_picker(pool, head_n, names, chosen, want, sel, tpage)
    kifer_hook_background
    @sprites["background"].setBitmap(KIFER::SummaryUI.gfx("bg_abil_detail"))
    o = @sprites["overlay"].bitmap
    o.clear
    white = Color.new(248, 248, 248)
    pbSetSystemFont(o)
    pbDrawTextPositions(o, [[_INTL("ABILITIES"), 26, 10, 0, white, Color.new(104, 104, 104)]])
    # left: the highlighted innate's text, or the picks while on Done
    pages = 1
    if sel < pool.length
      id = pool[sel]
      pbDrawTextPositions(o, [[KIFER.ability_name(id), 8, 68, 0, @text_color_base, @text_color_shadow]])
      pbSetNarrowFont(o)
      lines = KIFER::SummaryUI.wrap(o, KIFER.ability_full_text(id), 224)
      per = KIFER::SummaryUI::LINES_PER_TEXT_PAGE
      pages = [(lines.length + per - 1) / per, 1].max
      tpage = [[tpage, 0].max, pages - 1].min
      pbDrawTextPositions(o, lines[tpage * per, per].to_a.each_with_index.map { |l, i|
        [l, 8, 108 + i * 26, 0, @text_color_base, @text_color_shadow] })
    else
      pbDrawTextPositions(o, [[_INTL("Your innates"), 8, 68, 0, @text_color_base, @text_color_shadow]])
      chosen.sort.each_with_index do |k, i|
        pbSetNarrowFont(o)
        pbDrawTextPositions(o, [[KIFER.ability_name(pool[k]), 8, 108 + i * 52, 0, @text_color_base, @text_color_shadow]])
        pbSetSmallFont(o)
        short = KIFER::SummaryUI.wrap(o, ((KIFER::ABILITY_TEXT[pool[k]] || {})[:short] || (GameData::Ability.try_get(pool[k]) ? GameData::Ability.get(pool[k]).description : "")).to_s, 224)
        line = short[0].to_s + (short.length > 1 ? "..." : "")
        pbDrawTextPositions(o, [[line, 8, 132 + i * 52, 0, INNATES_GREY, INNATES_GREY_SHADE]])
      end
    end
    hints = [sel < pool.length ? _INTL("C: tick") : _INTL("C: save"), _INTL("X: back")]
    hints.unshift(_INTL("Page {1}/{2}", tpage + 1, pages)) if pages > 1
    kifer_px(o, 8, 352, 230, 24, hints.join("   "), INNATES_GREY, INNATES_GREY_SHADE, :text)
    # right: the picker panel
    x0, y0, x1, y1 = 246, 62, 504, 380
    dark = Color.new(64, 64, 72)
    o.fill_rect(x0 - 2, y0 - 2, x1 - x0 + 5, y1 - y0 + 5, dark)
    o.fill_rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1, Color.new(224, 232, 232))
    o.fill_rect(x0, y0, x1 - x0 + 1, 28, Color.new(112, 72, 200))
    shade = Color.new(72, 40, 136)
    kifer_px(o, x0 + 8, y0, 180, 28, _INTL("Pick {1} innates", want), white, shade, :title)
    kifer_px(o, x1 - 68, y0, 60, 28, "#{chosen.length}/#{want}", white, shade, :title, 1)
    green = Color.new(72, 168, 88)
    orange = Color.new(248, 120, 32)
    y = y0 + 31
    groups = [[names[0], _INTL("head"), (0...head_n).to_a], [names[1], _INTL("body"), (head_n...pool.length).to_a]]
    groups.each do |sp, part, ks|
      next if ks.empty?
      kifer_px(o, x0 + 8, y, x1 - x0 - 16, 20, _INTL("{1} ({2})", sp.upcase, part), INNATES_PURPLE, INNATES_PURPLE_SHADE, :text)
      y += 21
      ks.each do |k|
        if k == sel
          o.fill_rect(x0 + 3, y, x1 - x0 - 5, 3, orange)
          o.fill_rect(x0 + 3, y + 25, x1 - x0 - 5, 3, orange)
          o.fill_rect(x0 + 3, y, 3, 28, orange)
          o.fill_rect(x1 - 5, y, 3, 28, orange)
        end
        bx, by = x0 + 12, y + 7
        o.fill_rect(bx, by, 15, 15, Color.new(80, 80, 88))
        o.fill_rect(bx + 2, by + 2, 11, 11, white)
        o.fill_rect(bx + 3, by + 3, 9, 9, green) if chosen.include?(k)
        coded = KIFER.coded?(pool[k])
        kifer_px(o, x0 + 34, y + 3, x1 - x0 - 42, 22, KIFER.ability_name(pool[k]),
                 coded ? @text_color_base : INNATES_GREY, coded ? @text_color_shadow : INNATES_GREY_SHADE, :row)
        y += 28
      end
      y += 2
    end
    # Done: green with the right number ticked, grey under, red over
    full = chosen.length == want
    over = chosen.length > want
    dy = y1 - 34
    o.fill_rect(x0 + 60, dy, x1 - x0 - 119, 26, dark)
    o.fill_rect(x0 + 62, dy + 2, x1 - x0 - 123, 22, full ? green : (over ? Color.new(208, 64, 56) : Color.new(176, 184, 192)))
    if sel == pool.length
      o.fill_rect(x0 + 57, dy - 3, x1 - x0 - 113, 3, orange)
      o.fill_rect(x0 + 57, dy + 26, x1 - x0 - 113, 3, orange)
      o.fill_rect(x0 + 57, dy - 3, 3, 32, orange)
      o.fill_rect(x1 - 59, dy - 3, 3, 32, orange)
    end
    kifer_px(o, x0 + 62, dy + 2, x1 - x0 - 123, 22, _INTL("Done"), white,
             full ? Color.new(40, 96, 48) : (over ? Color.new(120, 32, 24) : Color.new(120, 128, 136)), :text, 2)
    pbSetSystemFont(o)
    return pages
  end

  #-----------------------------------------------------------------------------
  # pbScene with six tabs (copy of 053_PIF_Hoenn/.../014_Summary.rb pbScene)
  #-----------------------------------------------------------------------------
  alias kifer_pbScene pbScene unless method_defined?(:kifer_pbScene)
  def pbScene
    return kifer_pbScene unless kifer_tab?
    @kifer_vpage = KIFER::SummaryUI::VPAGE_OF[@page] || 1
    @pokemon.play_cry
    loop do
      Graphics.update
      Input.update
      pbUpdate
      dorefresh = false
      v = @kifer_vpage
      if Input.trigger?(Input::ACTION)
        pbSEStop
        @pokemon.play_cry
      elsif Input.trigger?(Input::BACK)
        pbPlayCloseMenuSE
        break
      elsif Input.trigger?(Input::USE)
        if v == 4 && !@pokemon.egg?
          pbPlayDecisionSE
          kifer_ability_detail
          dorefresh = true
        elsif v == 5
          pbPlayDecisionSE
          pbMoveSelection
          dorefresh = true
        elsif v == 6
          pbPlayDecisionSE
          pbRibbonSelection
          dorefresh = true
        elsif !@inbattle
          pbPlayDecisionSE
          dorefresh = pbOptions
        end
      elsif defined?(Input::SPECIAL) && Input.trigger?(Input::SPECIAL)
        if (v == 3 || v == 5) && defined?(ContestSettings) &&
           $game_switches[ContestSettings::CONTEST_INFO_IN_SUMMARY_SWITCH]
          @contestpage = !@contestpage
          pbPlayDecisionSE
          dorefresh = true
        end
      elsif Input.trigger?(Input::UP) && @partyindex > 0
        oldindex = @partyindex
        pbGoToPrevious
        if @partyindex != oldindex
          pbChangePokemon
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::DOWN) && @partyindex < @party.length - 1
        oldindex = @partyindex
        pbGoToNext
        if @partyindex != oldindex
          pbChangePokemon
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::LEFT) && !@pokemon.egg?
        if v > 1
          @kifer_vpage = v - 1
          pbSEPlay("GUI summary change page")
          @ribbonOffset = 0
          dorefresh = true
        end
      elsif Input.trigger?(Input::RIGHT) && !@pokemon.egg?
        if v < 6
          @kifer_vpage = v + 1
          pbSEPlay("GUI summary change page")
          @ribbonOffset = 0
          dorefresh = true
        end
      end
      kifer_show_vpage if dorefresh
    end
    return @partyindex
  end

  def kifer_show_vpage
    disposeContestStats if respond_to?(:disposeContestStats)
    if @kifer_vpage == 4 && !@pokemon.egg?
      kifer_draw_abilities_page
      return
    end
    @kifer_vpage = 1 if @kifer_vpage == 4   # an egg has no Abilities page
    @page = KIFER::SummaryUI::PAGE_OF[@kifer_vpage] || 1
    drawPage(@page)
    # the Pokédex tab opens the Pokédex and drops back to Moves
    @kifer_vpage = KIFER::SummaryUI::VPAGE_OF[@page] || 1
  end
end

# The pbScene copied above is 053_PIF_Hoenn's: note it in the log if that
# file changes (same file with other line endings is not a change)
begin
  f = "Data/Scripts/053_PIF_Hoenn/Contests/Pokemon Contests/014_Summary.rb"
  if File.exist?(f)
    data = File.binread(f).gsub("\r\n", "\n")
    if Zlib.crc32(data) != KIFER::SummaryUI::SCENE_CRC
      KIFER.log("053_PIF_Hoenn's Summary pbScene changed since the Abilities tab was made - re-check 007_SummaryTab.rb")
    end
  end
rescue StandardError
end
