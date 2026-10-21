#===============================================================================
# KIF: Elite Redux – pictures drawn at run time (the mod ships no image files)
#   KIFER::Gfx.summary(name)        6-tab Summary backgrounds, 512x384:
#     bg_1..bg_6, kif_bg_3, bg_abil_detail, bg_movedetail
#   KIFER::Gfx.status(kind, status) frostbite / bleeding badges:
#     kind :battle (44x16), :summary (44x16, party and Summary), :ebdx (40x16)
#   Each picture is built once and kept in memory; a disposed one is rebuilt.
#
#   Summary backgrounds: made from PIF's own 5-tab pictures in
#   Graphics/Pictures/Summary (and KIF's Graphics/Pictures/KIF/summary_bg_3).
#   The tab strip is repainted with the plain band, the old pointer is removed
#   from the panel border, and 6 narrower tabs are drawn in: PIF's 5 tabs,
#   each cut out of PIF's pictures and made 8 pixels narrower, plus a purple
#   ABILITIES tab with the Ability Capsule icon. The Abilities pages are PIF's Moves
#   pages turned purple. Same steps as tools/make_summary_tabs.py.
#
#   Status badges: drawn from the small pictures below (each letter is a 2x2
#   block of pixels), in the size, colours and letter style of PIF's own
#   status icons for that screen.
#===============================================================================
module KIFER
  module Gfx
    #---------------------------------------------------------------------------
    # Cache
    #---------------------------------------------------------------------------
    @cache = {}
    @tiles = {}

    def self.cached(key)
      bmp = @cache[key]
      return bmp if bmp && !bmp.disposed?
      bmp = yield
      @cache[key] = bmp if bmp
      return bmp
    end

    # true if `bmp` is one of the pictures made here
    def self.ours?(bmp)
      return false if bmp.nil?
      return @cache.values.any? { |b| b.equal?(bmp) }
    end

    def self.dispose_all
      (@cache.values + @tiles.values).each { |b| b.dispose if b && !b.disposed? }
      @cache = {}
      @tiles = {}
    end

    # Stands in for an AnimatedBitmap where a sprite wants one
    # (IconSprite#setBitmapDirectly). The picture stays in the cache when the
    # sprite lets go of it.
    class Picture
      def initialize(bmp); @bmp = bmp; end
      def bitmap; return @bmp; end
      def width; return @bmp.width; end
      def height; return @bmp.height; end
      def disposed?; return @bmp.nil? || @bmp.disposed?; end
      def dispose; @bmp = nil; end
      def update; end
      def totalFrames; return 1; end
      def currentIndex; return 0; end
      def deanimate; return @bmp; end
      def pbSetColor(*_a); end
    end

    #---------------------------------------------------------------------------
    # Status badges
    #---------------------------------------------------------------------------
    # B base, D shade, L light edge, W letters, K see-through shadow, . clear
    STATUS_ART = {
      :battle => {
        :FROSTBITE => [
          ".BBBBBBBBBBBBBBBBBBBB.",
          "BBWWWWWDWWWWDBWWWWDBBB",
          "BBWDDDDDWDDDWDWDDDWDBB",
          "BBWWWWWDWDBBWDWWWWWDBB",
          "BBWDDDDDWWWWWDWDDDWDBB",
          "BBWDBBBBWDWDDDWDBBWDBB",
          "BBWDBBBBWDWWWDWWWWWDBB",
          ".BDDDDDDDDDDDDDDDDDDB."
        ],
        :BLEEDING => [
          ".BBBBBBBBBBBBBBBBBBBB.",
          "BBWWWWDBWDBBBBWWWWDBBB",
          "BBWDDDWDWDBBBBWDDDWDBB",
          "BBWWWWWDWDBBBBWDBBWDBB",
          "BBWDDDWDWDBBBBWDBBWDBB",
          "BBWDBBWDWDBBBBWDBBWDBB",
          "BBWWWWWDWWWWWDWWWWDDBB",
          ".BDDDDDDDDDDDDDDDDDDB."
        ]
      },
      :summary => {
        :FROSTBITE => [
          "..LLLLLLLLLLLLLLLLLL..",
          ".LBBWWWWBWWWBBWWWBBBL.",
          ".BBBWBBBBWBBWBWBBWBBB.",
          ".BBBWBBBBWBBWBWWWBBBB.",
          ".BBBWWWBBWWWBBWBBWBBB.",
          ".BBBWBBBBWBWBBWBBWBBB.",
          ".DBBWBBBBWBBWBWWWBBBD.",
          "..DDDDDDDDDDDDDDDDDD.."
        ],
        :BLEEDING => [
          "..LLLLLLLLLLLLLLLLLL..",
          ".LBBWWWBBWBBBBWWWBBBL.",
          ".BBBWBBWBWBBBBWBBWBBB.",
          ".BBBWWWBBWBBBBWBBWBBB.",
          ".BBBWBBWBWBBBBWBBWBBB.",
          ".BBBWBBWBWBBBBWBBWBBB.",
          ".DBBWWWBBWWWWBWWWBBBD.",
          "..DDDDDDDDDDDDDDDDDD.."
        ]
      },
      :ebdx => {
        :FROSTBITE => [
          "..BBBBBBBBBBBBBBBB..",
          ".BBWWWWBWWWBBWWWBBB.",
          "BBBWBBBBWBBWBWBBWBBB",
          "BBBWWWBBWWWBBWWWBBBB",
          "BBBWBBBBWBWBBWBBWBBB",
          "KBBWBBBBWBBWBWWWBBBK",
          ".KBBBBBBBBBBBBBBBBK.",
          "..KKKKKKKKKKKKKKKK.."
        ],
        :BLEEDING => [
          "..BBBBBBBBBBBBBBBB..",
          ".BBWWWBBWBBBBWWWBBB.",
          "BBBWBBWBWBBBBWBBWBBB",
          "BBBWWWBBWBBBBWBBWBBB",
          "BBBWBBWBWBBBBWBBWBBB",
          "KBBWWWBBWWWWBWWWBBBK",
          ".KBBBBBBBBBBBBBBBBK.",
          "..KKKKKKKKKKKKKKKK.."
        ]
      }
    }
    STATUS_COLORS = {
      :battle => {
        :FROSTBITE => { "B" => [112, 200, 240], "D" => [40, 120, 176], "W" => [248, 248, 248] },
        :BLEEDING  => { "B" => [208, 32, 64],   "D" => [112, 8, 32],   "W" => [248, 248, 248] }
      },
      :summary => {
        :FROSTBITE => { "L" => [184, 232, 248], "B" => [96, 184, 224], "D" => [32, 112, 160], "W" => [248, 248, 248] },
        :BLEEDING  => { "L" => [232, 104, 128], "B" => [184, 24, 56],  "D" => [104, 0, 24],   "W" => [248, 248, 248] }
      },
      :ebdx => {
        :FROSTBITE => { "B" => [96, 178, 214], "W" => [247, 247, 247], "K" => [0, 0, 0, 89] },
        :BLEEDING  => { "B" => [178, 30, 54],  "W" => [247, 247, 247], "K" => [0, 0, 0, 89] }
      }
    }

    def self.status(kind, status)
      art = STATUS_ART[kind] && STATUS_ART[kind][status]
      return nil unless art
      return cached([:status, kind, status]) { draw_art(art, STATUS_COLORS[kind][status], 2) }
    rescue StandardError => e
      KIFER.log("status badge #{kind} #{status} not drawn: #{e.class}: #{e.message}") if KIFER.respond_to?(:log)
      return nil
    end

    # Rows of letters -> Bitmap; each letter is a `scale` x `scale` block
    def self.draw_art(rows, colors, scale)
      w = rows[0].length * scale
      h = rows.length * scale
      bmp = Bitmap.new(w, h)
      bmp.fill_rect(0, 0, w, h, Color.new(255, 255, 255, 0))
      rows.each_with_index do |row, y|
        x = 0
        while x < row.length
          ch = row[x]
          run = 1
          run += 1 while x + run < row.length && row[x + run] == ch
          if ch != "."
            c = colors[ch]
            bmp.fill_rect(x * scale, y * scale, run * scale, scale, Color.new(c[0], c[1], c[2], c[3] || 255))
          end
          x += run
        end
      end
      return bmp
    end

    #---------------------------------------------------------------------------
    # Summary backgrounds
    #---------------------------------------------------------------------------
    SOURCES = {
      :bg_1       => "Graphics/Pictures/Summary/bg_1",
      :bg_2       => "Graphics/Pictures/Summary/bg_2",
      :bg_3       => "Graphics/Pictures/Summary/bg_3",
      :bg_4       => "Graphics/Pictures/Summary/bg_4",
      :bg_5       => "Graphics/Pictures/Summary/bg_5",
      :movedetail => "Graphics/Pictures/Summary/bg_movedetail",
      :kif_bg_3   => "Graphics/Pictures/KIF/summary_bg_3"
    }
    # picture => [tab shown selected (1..6), base picture, pointer split x, selected-tab source]
    SUMMARY = {
      "bg_1"           => [1, :bg_1],
      "bg_2"           => [2, :bg_2],
      "bg_3"           => [3, :bg_3],
      "bg_4"           => [4, :abilities],
      "bg_5"           => [5, :bg_4],
      "bg_6"           => [6, :bg_5],
      "kif_bg_3"       => [3, :kif_bg_3, 380, :bg_3],   # KIF's Skills page (IV/EV box)
      "bg_abil_detail" => [4, :abil_detail],
      "bg_movedetail"  => [5, :movedetail]
    }
    OLD_X   = [228, 284, 340, 396, 452]                   # left edge of PIF's 5 tabs (52 wide)
    NEW_X   = (0...6).map { |i| 512 - 6 - (6 - i) * 48 + 4 }   # 222, 270 ... 462 (44 wide)
    SLOTS   = [0, 1, 2, nil, 3, 4]                        # PIF tab in each new slot (nil = Abilities)
    OLD_SEL = { 1 => 0, 2 => 1, 3 => 2, 4 => 3, 5 => 3, 6 => 4 }   # PIF tab selected on each page
    DARK    = [64, 64, 64]                                # tab outline
    RED_TO_PURPLE   = { [240, 96, 88] => [152, 112, 216], [160, 80, 80] => [96, 64, 152],
                        [200, 88, 80] => [120, 84, 184] }
    GREEN_TO_PURPLE = { [79, 204, 101] => [152, 112, 216], [53, 153, 70] => [96, 64, 152] }
    PANEL     = [224, 232, 232]
    RULE      = [176, 184, 192]
    MOVE_ROWS = [126, 190, 254, 318]                      # move-slot icon boxes to clear
    # ABILITIES tab icon (4-point sparkle): o outline, f fill, p centre
    SPARKLE = [
      "........................",
      "............o...........",
      "............o...........",
      "...........ofo..........",
      "...........ofo..........",
      "...........offo.........",
      "..........ofpfo.........",
      "..........ofpfo.........",
      ".........offpffo........",
      "........oofpppfoo.......",
      ".....ooofffpppfffoo.....",
      "...ooffffffpppfffffooo..",
      ".oofffpppppppppppppfffoo",
      "...ooofffffpppffffffoo..",
      "......oofffpppfffooo....",
      "........oofpppfoo.......",
      ".........offpffo........",
      "..........ofpfo.........",
      "..........ofpfo.........",
      "..........offo..........",
      "...........ofo..........",
      "...........ofo..........",
      "............o...........",
      "............o..........."
    ]
    SPARKLE_ON  = { "o" => [64, 64, 64], "f" => [248, 248, 248], "p" => [232, 216, 248] }
    SPARKLE_OFF = { "o" => [64, 64, 64], "f" => [200, 208, 216], "p" => [152, 112, 216] }

    def self.summary(name)
      recipe = SUMMARY[name.to_s]
      return nil unless recipe
      return cached([:summary, name.to_s]) do
        @src = {}
        begin
          page, base, split, sel_src = recipe
          b = source(base)
          s = sel_src ? source(sel_src) : nil
          (b && (!sel_src || s)) ? build(page, b, split, s) : nil
        ensure
          @src.each_value { |bmp| bmp.dispose if bmp && !bmp.disposed? }
          @src = nil
        end
      end
    rescue StandardError => e
      KIFER.log("Summary background #{name} not drawn: #{e.class}: #{e.message}") if KIFER.respond_to?(:log)
      return nil
    end

    # The file on disk with its real upper/lower case (PIF ships bg_2.PNG next
    # to bg_1.png; the engine's file lookup minds the case of the extension)
    def self.real_file(path)
      dir = File.dirname(path)
      want = File.basename(path).downcase
      return nil unless File.directory?(dir)
      c = Dir.children(dir).find { |x| x.downcase == want + ".png" }
      return c ? File.join(dir, c) : nil
    end

    # One of PIF's pictures (loaded fresh, disposed after the build): the file
    # by its real name first, then as PIF itself would ask for it
    def self.load_source(path)
      [real_file(path), path, pbResolveBitmap(path)].compact.uniq.each do |f|
        begin
          return Bitmap.new(f)
        rescue StandardError
          next
        end
      end
      return nil
    end

    def self.source(key)
      return @src[key] if @src.key?(key)
      bmp = case key
            when :abilities    # PIF's Moves page, purple, without the move-slot icons
              b = source(:bg_4)
              b ? moves_to_abilities(b) : nil
            when :abil_detail  # the move-detail page, purple, left panel blank
              b = source(:movedetail)
              if b
                b = moves_to_abilities(b)
                fill(b, 0, 60, 239, 324, PANEL)
                fill(b, 0, 104, 239, 2, RULE)
              end
              b
            else
              path = SOURCES[key]
              path ? load_source(path) : nil
            end
      @src[key] = bmp
      return bmp
    end

    def self.moves_to_abilities(b)
      b = recolor(b, RED_TO_PURPLE)
      MOVE_ROWS.each { |y| fill(b, 244, y, 71, 32, PANEL) }
      return b
    end

    def self.color(c)
      return Color.new(c[0], c[1], c[2], c[3] || 255)
    end

    def self.fill(bmp, x, y, w, h, c)
      bmp.fill_rect(x, y, w, h, color(c))
    end

    def self.copy(bmp, x = 0, y = 0, w = nil, h = nil)
      w ||= bmp.width
      h ||= bmp.height
      out = Bitmap.new(w, h)
      out.blt(0, 0, bmp, Rect.new(x, y, w, h))
      return out
    end

    # [[r, g, b, a], ...] row by row
    def self.pixels(bmp)
      out = []
      bmp.height.times do |y|
        bmp.width.times do |x|
          c = bmp.get_pixel(x, y)
          out << [c.red.to_i, c.green.to_i, c.blue.to_i, c.alpha.to_i]
        end
      end
      return out
    end

    # Copy with some colours swapped (alpha kept)
    def self.recolor(bmp, map)
      out = copy(bmp)
      w = bmp.width
      px = pixels(bmp)
      runs = []
      bmp.height.times do |y|
        x = 0
        while x < w
          p = px[y * w + x]
          to = map[p[0, 3]]
          run = 1
          if to
            run += 1 while x + run < w && px[y * w + x + run] == p
            runs << [x, y, run, to + [p[3]]]
          end
          x += run
        end
      end
      runs.each { |x, y, n, c| fill(out, x, y, n, 1, c) }
      return out
    end

    # Clears everything outside the tab's dark outline (flood from the top,
    # left and right edges over non-outline pixels)
    def self.clear_outside(tile)
      w = tile.width
      h = tile.height
      px = pixels(tile)
      seen = Array.new(w * h, false)
      stack = (0...w).map { |x| [x, 0] } + (0...h).map { |y| [0, y] } + (0...h).map { |y| [w - 1, y] }
      clear = Array.new(w * h, false)
      until stack.empty?
        x, y = stack.pop
        next if x < 0 || y < 0 || x >= w || y >= h || seen[y * w + x]
        seen[y * w + x] = true
        next if px[y * w + x][0, 3] == DARK
        clear[y * w + x] = true
        stack.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1])
      end
      none = Color.new(0, 0, 0, 0)
      h.times do |y|
        x = 0
        while x < w
          run = 0
          run += 1 while x + run < w && clear[y * w + x + run]
          tile.fill_rect(x, y, run, 1, none) if run > 0
          x += [run, 1].max
        end
      end
      return tile
    end

    # Drops `cut` plain columns (half each side, 5 pixels in from the edges)
    def self.squeeze(tile, cut = 8)
      w = tile.width
      drop = (5...(5 + cut / 2)).to_a + ((w - 5 - cut / 2)...(w - 5)).to_a
      keep = (0...w).reject { |x| drop.include?(x) }
      out = Bitmap.new(keep.length, tile.height)
      nx = 0
      i = 0
      while i < keep.length
        run = 1
        run += 1 while i + run < keep.length && keep[i + run] == keep[i] + run
        out.blt(nx, 0, tile, Rect.new(keep[i], 0, run, tile.height))
        nx += run
        i += run
      end
      tile.dispose
      return out
    end

    def self.unselected_tab(page_bg, k)
      x = OLD_X[k]
      return squeeze(clear_outside(copy(page_bg, x, 4, 52, 54)))
    end

    def self.selected_tab(page_bg, k)
      x = OLD_X[k]
      return squeeze(clear_outside(copy(page_bg, x - 4, 0, 60, 70)))
    end

    # Repaints the inner area of a tab with its own fill colours, row by row
    def self.blank_frame(tile, ymax = 46)
      w = tile.width
      rows = (8...ymax).map do |y|
        c = tile.get_pixel(6, y)
        [y, [c.red.to_i, c.green.to_i, c.blue.to_i, c.alpha.to_i]]
      end
      rows.each { |y, c| fill(tile, 6, y, w - 12, 1, c) }
      return tile
    end

    # The ABILITIES tab icon: PIF's Ability Capsule item icon, shrunk to
    # 24x24 (dimmed on the unselected tab); the drawn sparkle if it's missing
    TAB_ICON_ITEM = "Graphics/Items/ABILITYCAPSULE"

    def self.draw_tab_icon(tile, on, ox, oy)
      cap = load_source(TAB_ICON_ITEM)
      if cap
        begin
          tile.stretch_blt(Rect.new(ox, oy, 24, 24), cap, Rect.new(0, 0, cap.width, cap.height),
                           on ? 255 : 160)
          return
        ensure
          cap.dispose
        end
      end
      draw_sparkle(tile, on, ox, oy)
    end

    def self.draw_sparkle(tile, on, ox, oy)
      colors = on ? SPARKLE_ON : SPARKLE_OFF
      SPARKLE.each_with_index do |row, y|
        x = 0
        while x < row.length
          run = 1
          run += 1 while x + run < row.length && row[x + run] == row[x]
          fill(tile, ox + x, oy + y, run, 1, colors[row[x]]) if row[x] != "."
          x += run
        end
      end
    end

    # Tiles shared by all pages: PIF's unselected tabs and the ABILITIES tab
    def self.tile(key)
      t = @tiles[key]
      return t if t && !t.disposed?
      t = case key
          when :off_0 then (b = source(:bg_3)) ? unselected_tab(b, 0) : nil
          when :off_1, :off_2, :off_3, :off_4
            (b = source(:bg_1)) ? unselected_tab(b, key.to_s[-1].to_i) : nil
          when :abil_on
            b = source(:bg_3)
            if b
              sel = selected_tab(b, 2)
              t2 = recolor(sel, GREEN_TO_PURPLE)
              sel.dispose
              blank_frame(t2, 48)
              draw_tab_icon(t2, true, (t2.width - 24) / 2, 14)
              t2
            end
          when :abil_off
            off = tile(:off_1)
            if off
              t2 = blank_frame(copy(off))
              draw_tab_icon(t2, false, (t2.width - 24) / 2, 12)
              t2
            end
          end
      raise "missing a PIF Summary picture" unless t
      @tiles[key] = t
      return t
    end

    # Plain band over the tab area; the old selected tab's pointer is removed
    # from the panel border (left of `split` copies the column just left of
    # it, right of it the column just right of it)
    def self.wipe_strip(bg, old_sel, split = nil)
      bg = copy(bg)
      col = copy(bg, 214, 0, 1, 55)
      (222...508).each { |x| bg.blt(x, 0, col, Rect.new(0, 0, 1, 55)) }
      col.dispose
      x0 = OLD_X[old_sel] - 4
      split ||= x0 + 31
      lcol = (old_sel >= 1) ? copy(bg, x0 - 4, 55, 1, 17) : nil
      rcol = (x0 + 66 < 506) ? copy(bg, x0 + 66, 55, 1, 17) : nil
      (x0...(x0 + 62)).each do |x|
        src = ((x < split && lcol) || rcol.nil?) ? lcol : rcol
        bg.blt(x, 55, src, Rect.new(0, 0, 1, 17))
      end
      lcol.dispose if lcol
      rcol.dispose if rcol
      return bg
    end

    def self.build(page_no, base, split = nil, sel_src = nil)
      bg = wipe_strip(base, OLD_SEL[page_no], split)
      SLOTS.each_with_index do |old, slot|
        x = NEW_X[slot]
        if slot + 1 == page_no
          t = old.nil? ? tile(:abil_on) : selected_tab(sel_src || base, old)
          bg.blt(x - 4, 0, t, Rect.new(0, 0, t.width, t.height))
          t.dispose unless old.nil?
        else
          t = tile(old.nil? ? :abil_off : :"off_#{old}")
          bg.blt(x, 4, t, Rect.new(0, 0, t.width, t.height))
        end
      end
      return bg
    end
  end
end
