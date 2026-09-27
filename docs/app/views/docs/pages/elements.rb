# frozen_string_literal: true

class Views::Docs::Pages::Elements < DocsUI::Page
  title "Elements"
  eyebrow "Guide"

  def lead = "Every element available inside view_template, with its signature, options and a small example."

  def content
    overview
    text_elements
    containers
    tables
    media
    spacing
    lists
    navigation
    forms
    rich_text
  end

  private

  def overview
    DocsUI::Section("At a glance", description: "The element table from the README.") do
      md SourceMarkdown.readme_section("Elements").split("\n### ").first
    end
  end

  def text_elements
    DocsUI::Section("text", description: "A paragraph: plain, markup, or Ruby-built runs.") do
      md <<~'MD'
        `text(content = nil, markup: false, keep_with_next:, break_inside:, anchor:, bookmark:, **style)`

        Plain strings are always literal. `markup: true` reads `<b> <i> <u> <strikethrough> <sub> <sup> <br>
        <color rgb=""> <font size="" name=""> <link href="">` and decodes numeric and all 252 HTML 4 named
        entities. A block builds styled runs in Ruby with `plain`, `br`, `b`, `i`, `u`, `strikethrough`,
        `sub`, `sup`, `color`, `size`, `font` and `link`.

        ```ruby
        text "Invoice INV-7", size: 22, weight: :bold
        text "Net <b>30</b> days &mdash; <link href='mailto:hi@acme.test'>hi@acme.test</link>", markup: true
        text { b "Total"; plain " due"; sup "1" }
        text { |t| t.color "#4F46E5", @invoice.total }   # a block argument keeps your own self
        ```
      MD

      DocsUI::PropTable(
        [
          [ "font", "String", "Inter / default_text", "A registered family name." ],
          [ "size", "Numeric", "default_text", "Points." ],
          [ "weight", ":regular, :bold", ":regular", "A face without its own file is synthesised." ],
          [ "style", ":italic", "—", "Oblique is synthesised when the family has no italic file." ],
          [ "color", "Color", "\"#000000\"", [ :md, "`\"#RRGGBB\"`, `\"RRGGBB\"`, `\"#RGB\"`, `[r, g, b]` (0-255) or `[c, m, y, k]` (0-100)." ] ],
          [ "align", ":left, :center, :right, :justify", ":left", [ :md, "`:justify` widens spaces on wrapped lines; the last line, lines ending in a newline and lines without spaces stay left." ] ],
          [ "leading", "Numeric", "0", "Extra points between lines." ],
          [ "letter_spacing", "Numeric", "0", "Extra points between characters." ],
          [ "underline / strikethrough", "Boolean", "false", "Decoration lines." ],
          [ "link", "String", "—", [ :md, "A URL, or `\"#name\"` for an [internal link](/docs/links)." ] ],
          [ "opacity", "0..1", "1", "Text transparency." ],
          [ "kerning", "Boolean", "true", "GPOS / kern-table pair kerning." ],
          [ "ligatures", "Boolean", "true", "GSUB `liga` standard ligatures (off with letter spacing)." ]
        ]
      )
    end

    DocsUI::Section("text_style", description: "Default text style for a block.") do
      md <<~'MD'
        `text_style(**style) { … }` sets the text defaults (font, size, colour, weight, align, leading, …)
        for everything built inside the block.

        ```ruby
        text_style(size: 8, color: "#6B7280") do
          text "Terms"
          text "Payment within 30 days."
        end
        ```
      MD
    end
  end

  def containers
    DocsUI::Section("box", description: "Padding, background, border, radius — and page-aware splitting.") do
      md <<~'MD'
        `box(padding:, background:, border:, radius:, width:, height:, overflow:, valign:, opacity:, at:,
        link:, outset:, break_inside:, decoration:, align:, gap:, keep_with_next:, anchor:, bookmark:) { … }`

        ```ruby
        box(background: "#F3F4F6", radius: 6, padding: [8, 12], border: { color: "#E5E7EB", width: 0.5 }) do
          text "AMOUNT DUE", size: 8, weight: :bold
          text "€ 7 330,00", size: 19, weight: :bold
        end
        ```
      MD

      DocsUI::PropTable(
        [
          [ "padding", "Box", "0", [ :md, "One value, `[y, x]`, `[top, x, bottom]`, `[top, right, bottom, left]` or `{ top:, right:, bottom:, left:, x:, y: }`." ] ],
          [ "background", "Color", "nil", "Fill colour." ],
          [ "border", "Hash", "nil", [ :md, "`{ width: 1, color: \"#000000\", sides: %i[top right bottom left] }`, merged over those defaults." ] ],
          [ "radius", "Numeric or [tl, tr, br, bl]", "0", "Corner radius." ],
          [ "width", "points, fraction, :auto", "full width", [ :md, "`0.5` is half the available width; `:auto` is the content's natural width." ] ],
          [ "height", "Numeric", "nil", "A fixed height. Fixed-height boxes never split." ],
          [ "overflow", ":visible, :truncate, :shrink_to_fit", ":visible", "What text does when a fixed height is too small." ],
          [ "valign", ":top, :middle, :bottom", ":top", "Content placement inside a fixed height." ],
          [ "at", "[x, y]", "nil", "Pins the box to a page position, outside the flow." ],
          [ "link", "String", "nil", [ :md, "Makes the whole box clickable (a URL or `\"#anchor\"`)." ] ],
          [ "outset", "Box", "0", "Bleeds the background past the box, e.g. into the page margins." ],
          [ "break_inside", "nil, :auto, :avoid", "nil", [ :md, "See [Layout rules](/docs/layout-rules#break-inside)." ] ],
          [ "decoration", ":slice, :clone", ":slice", "At a page cut: drop padding and border, or keep the padding." ],
          [ "align / gap", "Symbol / Numeric", ":left / 0", "Horizontal alignment of the children and space between them." ]
        ]
      )
    end

    DocsUI::Section("row and column", description: "Columns side by side.") do
      md <<~'MD'
        - `row(gap: 0, align: :top, break_inside: nil) { … }`
        - `column(width: nil, align: nil, gap: 0, break_inside: nil, **box_options) { … }`

        `width:` is points, a fraction (`0.5`), `:auto` or `nil` (an equal share of what is left). A column
        takes every box option. `align:` on the row (`:top`, `:middle`, `:bottom`) places columns of
        different heights. Rows split across pages like a box, every column at the same break; a row
        holding a fixed-height column never splits.

        ```ruby
        row(gap: 24, align: :middle) do
          column(width: 0.5) { text "Invoice INV-7", size: 22, weight: :bold }
          column(width: :auto) { image "logo.png", height: 34 }
          column { text "Due 26 October", align: :right }
        end
        ```
      MD
    end

    DocsUI::Section("group", description: "Keep a block together.") do
      md <<~'MD'
        `group(gap: 0, align: nil, keep_together: false, keep_with_next: nil, anchor: nil, bookmark: nil) { … }`

        A vertical group of children. `keep_together: true` moves the whole group to the next page rather
        than splitting it.

        ```ruby
        group(keep_together: true) do
          rule height: 1, color: "#E5E7EB"
          text "Thank you for your business", weight: :bold
        end
        ```
      MD
    end

    DocsUI::Section("wrap", description: "Chips and tags.") do
      md <<~'MD'
        `wrap(gap: 0, row_gap: gap, align: :left) { … }` — children side by side at their own widths,
        wrapping onto new rows. It splits between rows.

        ```ruby
        wrap(gap: 6, row_gap: 4) do
          %w[ruby pdf layout].each { |tag| box(width: :auto, padding: [2, 8], radius: 8, background: "#EEF2FF") { text tag } }
        end
        ```
      MD
    end
  end

  def tables
    DocsUI::Section("table", description: "Selections, spans, DSL cells, repeating headers.") do
      md <<~'MD'
        `table(rows, widths: nil, width: :auto, header: false, split_rows: false, cell: {}, anchor:, bookmark:) { |t| … }`

        - **Cells** are strings, layout nodes, procs built with the DSL (`-> { image logo }`) or components.
        - **`widths:`** per column: points, or `nil` for a share of the rest. **`width:`** `:auto`, `:full` or points.
        - **`header:`** `true` (one row) or a row count; header rows repeat after every page break.
        - **`cell:`** defaults for every cell: `padding` (5), `borders` (all four), `border_width` (0.5),
          `border_color`, plus `background`, `color`, `weight`, `style`, `size`, `font`, `align`, `valign`,
          `letter_spacing`, `leading` and `markup`.
      MD

      md <<~'MD'
        ### Selections and zebra stripes

        `t.row(0)`, `t.rows(-1)`, `t.column(1)`, `t.columns(1..)` and `t.cells` select cells (chainable:
        `t.row(-1).columns(3..)`); assign one option (`t.columns(1..).align = :right`) or several with `set`.
        `t.zebra(color:, from: 0, to: nil, every: 2)` stripes rows.

        ```ruby
        table(rows, width: :full, widths: [nil, 45, 80, 85], header: true, cell: { padding: [7, 8], borders: [] }) do |t|
          t.row(0).set(background: "#4F46E5", color: "#FFFFFF", weight: :bold)
          t.columns(1..).align = :right
          t.zebra(from: 1, color: "#F9FAFB")
          t.row(-1).set(weight: :bold, borders: [:top])
        end
        ```

        ### Spans

        A cell may be `{ content:, colspan:, rowspan: }` plus any cell option. Rows list only the cells they
        start, as in HTML, and pages never break through a rowspan. Spans are set in the rows, not through
        selections.

        ```ruby
        table([
          [{ content: "Q1", rowspan: 2 }, "January", "12"],
          ["February", "15"],
          [{ content: "Total", colspan: 2, align: :right, weight: :bold }, "27"]
        ])
        ```

        ### DSL cells

        ```ruby
        table([
          ["Logo", -> { image "logo.png", height: 16 }],
          ["Status", StatusPill.new("PAID")]
        ])
        ```

        ### Rows taller than the page

        A row taller than the page continues on the next page, cut through its cells, with the header
        repeated. `split_rows: true` cuts any row that reaches the page bottom instead of moving it whole —
        useful for long tables of tall rows.
      MD
    end
  end

  def media
    DocsUI::Section("image", description: "JPEG and PNG.") do
      md <<~'MD'
        `image(path_or_io, width: nil, height: nil, fit: nil, align: nil, opacity: nil)`

        Aspect ratio is preserved when only one of `width`/`height` is given; `fit: [w, h]` scales the image
        to fit inside that box; with neither, one pixel is one point. An image is never wider than the space
        it is given. Details on [Images and SVG](/docs/images-and-svg).

        ```ruby
        image "logo.png", height: 34, align: :right
        image StringIO.new(blob.download), fit: [120, 80]
        ```
      MD
    end

    DocsUI::Section("svg", description: "Vector icons and drawings.") do
      md <<~'MD'
        `svg(source_or_path, width: nil, height: nil, color: "#000000", align: nil)` — markup String or a
        path to a `.svg` file. `currentColor` takes `color:`.

        ```ruby
        svg "icons/check.svg", width: 14, color: "#0F766E"
        ```
      MD
    end

    DocsUI::Section("canvas", description: "Draw directly.") do
      md <<~'MD'
        `canvas(height:, at: nil, width: nil) { |canvas, rect| … }` reserves `height` points and hands the
        block the canvas — clipped to the reserved rectangle — and that rectangle (`rect.x`, `rect.y`,
        `rect.width`, `rect.height`, top-left page coordinates).

        Canvas methods: `fill_rect(x, y, w, h, color:)`, `rounded_rect(x, y, w, h, radius:, fill:, stroke:,
        line_width:, dash:)` (per-corner radii), `circle(cx, cy, r, fill:, stroke:)`, `line(x1, y1, x2, y2,
        color:, width:, dash:, cap:)`, `path(fill:, stroke:, …) { |p| p.move_to; p.line_to; p.curve_to; p.close }`,
        `clip(x, y, w, h, radius:) { … }`, `image(image, x:, y:, width:, height:)` and `link(x, y, w, h, target)`.

        ```ruby
        canvas(height: 40) do |canvas, rect|
          bars.each_with_index do |width, index|
            x = rect.x + bars.first(index).sum
            canvas.fill_rect(x, rect.y, width, rect.height, color: "#111827") if index.even?
          end
        end
        ```

        `rotate(degrees, around: [x, y]) { … }` paints the block turned clockwise around a page point,
        as CSS `rotate()` does; `transform([a, b, c, d, e, f]) { … }` applies any affine matrix given in
        the same top-left space. Shapes, images and text inside follow the transform. Link and form
        widget rectangles are annotations in untransformed page space, so a `link` inside a rotated
        block keeps its unrotated rectangle.

        ```ruby
        canvas(height: 120) do |canvas, rect|
          canvas.rotate(-3, around: [rect.x + 60, rect.y + 60]) do
            canvas.image(photo, x: rect.x, y: rect.y, width: 120, height: 120)
          end
        end
        ```
      MD
    end
  end

  def spacing
    DocsUI::Section("rule, spacer and page_break", description: "Dividers and spacing.") do
      md <<~'MD'
        - `rule(height: 1, color: "#000000", width: nil, radius: 0)` — a filled horizontal bar.
        - `spacer(height)` — vertical space, dropped when it lands on a page break.
        - `page_break` — forces what follows onto a new page.

        ```ruby
        rule height: 3, color: "#4F46E5"
        spacer 18
        page_break
        ```
      MD
    end
  end

  def lists
    DocsUI::Section("ul, ol and li", description: "Bulleted and numbered lists.") do
      md <<~'MD'
        - `ul(style: nil, gap: 4, indent: nil, marker_gap: 6, marker_color: nil) { … }` — `style:` is
          `:disc`, `:circle`, `:square`, `:dash` or any String; unstyled nested lists cycle disc → circle → square.
        - `ol(format: :decimal, start: 1, suffix: ".", gap: 4, indent: nil, marker_gap: 6, marker_color: nil) { … }` —
          `format:` is `:decimal`, `:alpha`, `:upper_alpha`, `:roman`, `:upper_roman` or a Proc `(n) -> String`.
          Markers right-align so bodies line up.
        - `li(string, **text_style)` or `li(gap: 0) { … }` — a paragraph, or a block of any elements,
          including nested lists.

        Any node added inside a list (not only `li`) becomes an item. Items split across pages; the marker
        stays with the first line.

        ```ruby
        ol(format: :upper_roman, marker_color: "#0F766E") do
          li "Introduction"
          li do
            text "Highlights"
            ul(style: :dash) { li "Revenue up 18%"; li "Two new markets" }
          end
        end
        ```
      MD
    end
  end

  def navigation
    DocsUI::Section("anchor, bookmark and table_of_contents", description: "Internal links and the PDF outline.") do
      md <<~'MD'
        - `anchor(name)` — a named link target (`link: "#name"`); it moves to the next page with what follows it.
          `anchor:` is also an option on `text`, `box`, `group` and `table`.
        - `bookmark(title, level: 1, open: false)` — a standalone outline entry; `bookmark:` (a title or
          `{ title:, level:, open: }`) is also an option on `text`, `box`, `group` and `table`.
        - `table_of_contents(levels: 1.., leader: :dots, indent: 12, number_width: nil, gap: 4, **text_style)` —
          one linked row per bookmark with its page number.

        ```ruby
        text "Contents", size: 18
        table_of_contents(levels: 1..2, leader: :line)
        text "Introduction", size: 16, bookmark: "Introduction", anchor: "intro"
        ```

        The full story is on [Links, bookmarks and contents](/docs/links).
      MD
    end
  end

  def forms
    DocsUI::Section("text_field, checkbox, radio, select and signature_field", description: "Interactive form fields.") do
      md <<~'MD'
        - `text_field(name, value: "", width: :full, height: 22, multiline: false, max_length: nil, comb: nil,
          read_only: false, required: false, font_size: 10, border: "#9CA3AF", background: "#FFFFFF", radius: 2,
          at: nil)` — a text input; `comb:` is a cell count (or `true` with `max_length:`).
        - `checkbox(name, checked: false, size: 12, label: nil, at: nil)` — a check box with an optional label.
        - `radio(name, value, checked: false, size: 12, label: nil, at: nil)` — one choice of the radio group `name`.
        - `select(name, options:, value: nil, width: :full, height: 22, editable: false, at: nil)` — a combo box.
        - `signature_field(name, width: :full, height: 40, label: "Signature", at: nil)` — an empty signature field.
      MD
      md SourceMarkdown.readme_section("Forms")
    end
  end

  def rich_text
    DocsUI::Section("html and markdown", description: "User content rendered with the elements above.") do
      md SourceMarkdown.readme_section("HTML and Markdown")
    end
  end
end
