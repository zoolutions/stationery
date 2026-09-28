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
        <color rgb=""> <font size="" name=""> <link href="">` and decodes numeric (`&#39;`, `&#x27;`) and all
        252 HTML 4 named entities, each once: escape user data (`ERB::Util.html_escape`) before wrapping it in
        your own tags, and `&lt;b&gt;` stays the literal text `<b>`. A block builds styled runs in Ruby with
        `plain`, `br`, `b`, `i`, `u`, `strikethrough`, `sub`, `sup`, `color`, `size`, `font` and `link`.

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
          [ "orphans / widows", "Integer", "1", [ :md, "The fewest lines a page break may leave at the foot of a page and carry to the next; a paragraph that cannot meet them moves whole. See [Page breaks in text](/docs/layout-rules#page-breaks-in-text)." ] ],
          [ "letter_spacing", "Numeric", "0", "Extra points between characters." ],
          [ "underline / strikethrough", "Boolean", "false", "Decoration lines." ],
          [ "link", "String", "—", [ :md, "A URL, or `\"#name\"` for an [internal link](/docs/links)." ] ],
          [ "opacity", "0..1", "1", "Text transparency." ],
          [ "kerning", "Boolean", "true", "GPOS / kern-table pair kerning." ],
          [ "ligatures", "Boolean", "true", "GSUB `liga` standard ligatures (off with letter spacing)." ],
          [ "hyphenate", "true, \"en\", \"de\", \"sv\"", "off", [ :md, "Breaks a word that does not fit at a point the language's patterns allow, drawing a hyphen; a soft hyphen (U+00AD, `&shy;`) names the points yourself. See [Fonts](/docs/fonts#hyphenation)." ] ]
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
        `box(padding:, background:, border:, radius:, width:, height:, overflow:, valign:, opacity:, at:, float:, margin:,
        link:, outset:, break_inside:, decoration:, rotate:, shadow:, align:, gap:, keep_with_next:, anchor:,
        bookmark:) { … }`

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
          [ "overflow", ":visible, :hidden, :truncate, :shrink_to_fit", ":visible", [ :md, "What text does when a fixed height is too small. `:hidden` also clips the content to the rounded outline (`radius:`) and still splits across pages." ] ],
          [ "valign", ":top, :middle, :bottom", ":top", "Content placement inside a fixed height." ],
          [ "at", "[x, y]", "nil", "Pins the box to a page position, outside the flow." ],
          [ "float", ":left, :right", "nil", [ :md, "Takes the box to that side of the flow it is in; what follows wraps beside it. Needs a `width:`. See [Floats](#floats)." ] ],
          [ "margin", "Numeric or Box", "0", [ :md, "With `float:`, the space kept between the box and the text around it: a number on the sides that face the text, or sides named as for `padding:`." ] ],
          [ "link", "String", "nil", [ :md, "Makes the whole box clickable (a URL or `\"#anchor\"`)." ] ],
          [ "outset", "Box", "0", "Bleeds the background past the box, e.g. into the page margins." ],
          [ "break_inside", "nil, :auto, :avoid", "nil", [ :md, "See [Layout rules](/docs/layout-rules#break-inside)." ] ],
          [ "decoration", ":slice, :clone", ":slice", "At a page cut: drop padding and border, or keep the padding." ],
          [ "rotate", "degrees", "0", [ :md, "Turns the painted box clockwise around its centre, like CSS `rotate()`. The layout rectangle is unchanged, the box never splits, and a `link:` keeps its unrotated rectangle (annotations live in page space)." ] ],
          [ "shadow", "true or Hash", "nil", [ :md, "A soft drop shadow under the box: `{ offset: [0, 4], blur: 8, color: \"#000000\", opacity: 0.15 }`, merged over those defaults. Painted as stacked, fading rounded rectangles (an artifact), it takes no layout space and is skipped on a fragment cut by a page break." ] ],
          [ "align / gap", "Symbol / Numeric", ":left / 0", "Horizontal alignment of the children and space between them." ]
        ]
      )

      md <<~'MD'
        A tilted, white-framed photo with a shadow — the pieces of a collage:

        ```ruby
        box(width: 180, padding: 4, background: "#FFFFFF", radius: 12, shadow: true, rotate: -3) do
          image "beach.jpg", width: 172, height: 129
        end
        ```
      MD
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

    DocsUI::Section("columns", description: "One flow through several columns.") do
      md <<~'MD'
        `columns(count: 2, gap: 12, balance: true, rule: nil, align: nil) { … }`

        The block's content is one flow, poured through `count` columns newspaper style: column 1 top to
        bottom, then column 2. (A `row` is the other thing: columns side by side, each with content of its
        own.) Every column is `(width - gap * (count - 1)) / count` wide, and a column ends where a page
        would: between children, between the lines of a paragraph (honouring `orphans:` and `widows:`),
        inside boxes and tables by their own rules, never inside `break_inside: :avoid`. A heading with
        `keep_with_next: true` stays in the column of what follows it.

        ```ruby
        text "The sea wall is whole again", size: 30, weight: :bold
        columns(count: 2, gap: 22, rule: { color: "#D1D5DB" }) do
          text "What it cost", weight: :bold, keep_with_next: true
          text body, align: :justify, orphans: 2, widows: 2
          image "bay.png", width: 1.0
        end
        text "A note across the page, below the tallest column."
        ```

        - **`balance: true`** ends the columns at nearly the same height wherever the content ends: on the
          last page of the block and before a `page_break` inside it. The height is the shortest at which
          everything fits, and the columns are filled evenly in it: the first takes what fits, and what
          it leaves is balanced through the columns after it in the same way. Ten lines in three columns
          are 4, 3 and 3, what cannot be shared going to the earlier columns. The break rules hold, so
          a heading, a box or `orphans:` and `widows:` can keep the columns further apart than a line,
          and a column that ends above a block that cannot split may stay shorter than the one after it.
          **`balance: false`** fills each column to the height available before the next starts.
        - **Across pages.** A block that does not fit fills the height left on the page, every column
          full, and continues on the next page; the last page is balanced. Below other content it starts
          only when every column takes something in the height left, and otherwise moves to the next
          page. A `page_break` inside ends the page. What follows the block starts below its tallest column.
        - **`rule:`** `true` or `{ color:, width: }` draws a line in the middle of each gap, an artifact in
          a tagged PDF.
        - **`count: 1`** lays out like a `group`. `count:` must be an Integer of at least 1 and `gap:` a
          number of at least 0, or `ArgumentError` is raised.
        - **Nesting.** `columns` works inside a `box`, a `column` and another `columns`.
        - **Tagged PDF.** Reading order is column 1, then column 2; a paragraph split across columns is
          one `P`, as it is across pages. Links, anchors, bookmarks and `table_of_contents` page numbers
          work inside.
        - A child too tall for a column at the top of a page is kept and reported as an overflow warning.

        `examples/newsletter.rb` is a complete page. In `html`, `column-count`, `columns: <n>` and
        `column-gap` map to it.
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
    DocsUI::Section("image", description: "JPEG, PNG and lossless WebP.") do
      md <<~'MD'
        `image(path_or_io, width: nil, height: nil, fit: nil, align: nil, opacity: nil, float: nil, margin: nil)`

        Aspect ratio is preserved when only one of `width`/`height` is given; `fit: [w, h]` scales the image
        to fit inside that box; with neither, one pixel is one point. An image is never wider than the space
        it is given. `float: :left` or `:right` takes it to that side, and the text that follows wraps
        beside it ([Floats](#floats)). Details on [Images and SVG](/docs/images-and-svg).

        ```ruby
        image "logo.png", height: 34, align: :right
        image StringIO.new(blob.download), fit: [120, 80]
        image "bay.jpg", float: :left, width: 0.4, margin: 12, alt: "The bay at dawn"
        ```
      MD
    end

    DocsUI::Section("Floats", description: "Text that wraps around an image or a box.") do
      md <<~'MD'
        `float: :left` or `:right` on an `image` or a `box` takes it to that edge of the flow it is written
        in: the page body, a box, a column or a table cell. What follows it in that flow starts at its top
        and wraps beside it, and takes the full width again below it, in the middle of a paragraph if
        need be. `examples/article.rb` is a page built this way.

        ```ruby
        image "bay.jpg", float: :left, width: 0.4, margin: 12, alt: "The bay at dawn"
        text story, align: :justify                     # beside the photo, then below it

        box(float: :right, width: 170, margin: { left: 16, bottom: 6 }, padding: 10, role: :blockquote) do
          text "The view is everywhere.", size: 13, style: :italic
        end
        text more                                       # around the pull quote
        ```

        | | Rule |
        | --- | --- |
        | `margin:` | A number is kept on the sides that face the text (the inner side and the bottom). A Hash (`{ left: 16, bottom: 6 }`, `x:`, `y:`) or an Array names the sides as `padding:` does. |
        | `width:` | A floated box needs one: points, a fraction of the flow's width or `:auto`. An image has its own size. |
        | Text | Paragraphs, headings and the text inside a `group` or an `html` block wrap: every line takes the width left at its own top and is aligned and justified in it. A paragraph whose widest word does not fit beside the floats starts below them. |
        | List items and plain boxes | A list item and a `box` that paints nothing of its own wrap what they hold: they keep the full width, and their lines are narrow beside the float and wide below it. That is a box without `background:`, `border:`, `shadow:` or `link:` and without `width:`, `height:`, `rotate:`, `overflow:` or `valign:`. Its padding lies under the float, as a block's does in CSS; a list item keeps its indent from the float, with the marker beside its first line. |
        | Other elements | A `box` with a background, a border or a size of its own, a `row`, `columns`, `table`, `rule`, `image`, `svg` or form field is a block: beside the float in the width that is left, all the way down, when its own width (or the least its content takes) fits there; else below the float. A `spacer` takes its height beside the float; a `page_break` ends the page and the float with it. |
        | Several floats | The next goes beside those already there when it fits, else below them, and never above one written before it. Left and right floats share a line with the text between them. |
        | Height | The flow that holds a float is at least as tall as the float: what follows the box, column or cell starts below it. |
        | Page breaks | A float never splits. When it does not fit what is left of the page, or the content after it could not start beside it there, it moves to the next page with that content. The lines a paragraph, a list item or a box carries over a break are wrapped again at the full width; the part that stays keeps the place its whole was given, beside the floats or below them. |
        | Floats taller than the page | Floats written one after the other that are taller than a page together are cut before the first that does not fit: it starts the next page, with what was written after it, in a box, a list item, a column and a table cell as in the page body. Floats that fit a page together stay together: when one of them does not fit what is left of the page, they all go to the next. Only a float taller than a page by itself runs over it, and is reported as an `Overflow`. What does not fit below the floats at the top of a page goes to the next page and leaves them behind. |
        | Tagged PDF | The float is read where it was written: an image is a `Figure`, a box has its `role:`. |

        Anything but `:left` and `:right` raises `ArgumentError`, as do `margin:` without `float:` and
        `float:` together with `at:`. Text wraps along the float's rectangle, never along a shape.
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

    DocsUI::Section("stack and layer", description: "Overlapping content: a collage, a badge on a photo, a stamp on a card.") do
      md <<~'MD'
        `stack(gap: 0, align: nil) { … }` is a container whose ordinary children form the base and set the
        height. `layer(top:, right:, bottom:, left:, width:, height:, **box_options) { … }` inside it is a
        box painted over the base, placed by insets from the stack's edges and taking no space. Insets,
        `width:` and `height:` are points, or a fraction of the stack's width (horizontal) or height
        (vertical) when given as a Float between -1 and 1 or a Rational (`1/3r`); negative insets overhang.
        A layer takes every `box` option, so `rotate:`, `shadow:`, `padding:`, `background:` and `radius:`
        make tilted, framed snapshots. A stack never splits: it moves to the next page whole.

        Overhanging layers paint past the stack, so wrap it in a `box(padding:)` at least as big as the
        overhang to keep them inside the page margins (what `examples/postcard.rb` does):

        ```ruby
        box(padding: 18) do
          stack do
            box(width: :auto, radius: 16, shadow: true) do
              image "sea.png", width: 228, height: 171, fit: :cover, radius: 16, alt: "The bay at dawn"
            end
            layer(bottom: -18, left: -18, width: 0.4, rotate: -3, padding: 4, background: "#FFFFFF", radius: 12, shadow: true) do
              image "hills.png", width: 83, height: 62, fit: :cover, radius: 8, alt: "Hills above the village"
            end
            layer(top: -18, right: -18, width: 1/3r, rotate: 2, padding: 4, background: "#FFFFFF", radius: 12, shadow: true) do
              image "stone.png", width: 68, height: 68, fit: :cover, radius: 8, alt: "A sandstone wall"
            end
          end
        end
        ```

        Without `left:`/`top:` a layer sits at the stack's top-left; without `width:` it takes its content's
        natural width (at most the stack's). In a tagged PDF the base and the layers attach in paint order.
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
        `text_field`, `checkbox`, `radio`, `select` and `signature_field` make a PDF fillable: each takes a
        name and lays out like a box, or sits at `at: [x, y]`. Their options, naming, fonts and
        accessibility have a page of their own: [Forms](/docs/forms).
      MD
    end
  end

  def rich_text
    rich, untrusted = SourceMarkdown.readme_section("HTML and Markdown").split("#### Untrusted input\n", 2)

    DocsUI::Section("html and markdown", description: "User content rendered with the elements above.") do
      md rich
    end

    DocsUI::Section("Untrusted input", description: "What html and markdown do with content you did not write.") do
      md untrusted
    end
  end
end
