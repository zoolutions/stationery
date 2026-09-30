# Stationery

Pure-Ruby PDF documents built from Phlex-style components. Describe the page
with rows, columns, boxes, tables, text and images; a box-layout engine
measures, places and paginates them; a small PDF writer embeds subsetted
TrueType and OpenType fonts, JPEG, PNG and lossless WebP images and SVG drawings.

**Documentation: [stationery.zoolutions.llc](https://stationery.zoolutions.llc)**

The same docs for an agent: over MCP (`search_docs`, `get_page`, `list_pages`), as
[`/llms.txt`](https://stationery.zoolutions.llc/llms.txt) and
[`/llms-full.txt`](https://stationery.zoolutions.llc/llms-full.txt), and every page
as Markdown at its URL with `.md`. In Claude Code:

```sh
claude mcp add --transport http stationery https://stationery.zoolutions.llc/mcp
```

Any other MCP client takes the same URL, `https://stationery.zoolutions.llc/mcp`,
as a remote server over HTTP: no key, read-only.

A skill for coding agents ships with the gem: how a document is built, the rules that surprise,
how to look at a render before calling it done, conformance, labels and a recipe per thing people
ask for, written from this README for the version installed:

```sh
stationery skill install                  # ~/.claude/skills/stationery, and Codex's and ~/.agents' when they are there
stationery skill install --project        # the project's .claude/skills/stationery, to commit with the app
stationery skill status                   # current, outdated or missing, by the gem's version
stationery skill print > stationery.md    # one file, for an agent that takes one
```

- **No runtime dependencies.** Standard library only.
- **No native extensions and no other processes.** No Prawn, no headless
  Chrome, nothing to leak or kill.
- **Declarative layout.** No cursor arithmetic: padding, backgrounds, borders,
  radii, column widths and page breaks are the engine's job.

```ruby
gem "stationery"
```

Ruby 3.4 or newer.

## Quick start

```ruby
class Hello < Stationery::Document
  def view_template = text("Hello, world", size: 24, weight: :bold)
end

File.binwrite("hello.pdf", Hello.new.to_pdf)
```

No fonts to configure: Inter ships inside the gem and is used until you
declare a `font_family`.

## A document

```ruby
class InvoicePdf < Stationery::Document
  page size: :a4, margin: [40, 44, 56, 44]
  default_text size: 9, color: "#1F2937"          # bundled Inter; font_family "Brand", regular: "…" for your own
  metadata title: "Invoice"

  footer { |page| text "Page #{page.number} of #{page.count}", size: 7, align: :right }

  def initialize(invoice)
    super()
    @invoice = invoice
  end

  def view_template
    row(align: :middle) do
      column(width: 0.5) { text "Invoice #{@invoice.number}", size: 22, weight: :bold }
      column(width: 0.5, align: :right) { image "logo.png", height: 34, align: :right }
    end
    rule height: 3, color: "#4F46E5"
    spacer 18
    box(background: "#F3F4F6", radius: 6, padding: 12, width: 190) do
      text "AMOUNT DUE", size: 8, weight: :bold, letter_spacing: 0.5
      text @invoice.total, size: 19, weight: :bold, color: "#4F46E5"
    end
    table(@invoice.rows, width: :full, widths: [nil, 45, 80, 85], header: true, cell: { borders: [] }) do |t|
      t.row(0).set(background: "#4F46E5", color: "#FFFFFF", weight: :bold)
      t.columns(1..).align = :right
      t.zebra(from: 2, color: "#F9FAFB")
    end
  end
end

InvoicePdf.new(invoice).to_pdf          # => "%PDF-1.7…" (binary String)
InvoicePdf.new(invoice).to_pdf("a.pdf") # also writes a path or an IO
```

`examples/` has a complete, runnable invoice, annual report, letter, packing slip, shipping label, fillable form, postcard collage, magazine article, event flyer, two-column newsletter and Factur-X e-invoice,
and one per thing people build: a 2,000-row price list written `incremental`, a contract with initials
on every page and signature fields, a landscape certificate, a two-column résumé with its body in HTML,
a restaurant menu in `columns` with floats, a till receipt on an 80 mm roll, a PDF/UA-1 accessible report and a notice in English, German
and Swedish, each hyphenated in its language
([previews and live PDFs](https://stationery.zoolutions.llc/docs/examples)); `bundle exec rake examples`
renders them all, or render one with `stationery render examples/report.rb`.
`examples/shaping/rtl_letter.rb`, a letter in Arabic, needs HarfBuzz and an Arabic font, which the gem
does not ship (see [Complex scripts](#complex-scripts-the-shaper-hook)).

The examples ship with the gem, with the images they read, so they are there to read and to run in an
application that has only the gem. Inter is the one font the gem ships: the invoice examples are set in
the Open Sans of the test suite in the repository and in Inter elsewhere.

```sh
stationery examples                          # their names and what each shows
stationery examples invoice                  # the path of one; --source prints its code
stationery render "$(stationery examples invoice)" --out invoice.pdf
ls "$(bundle show stationery)/examples"      # or: gem contents stationery
```

## Elements

| Element | What it does |
|---|---|
| `text(string, **style)` | A paragraph. Plain strings are literal. |
| `text(string, markup: true)` | Reads `<b> <i> <u> <strikethrough> <sub> <sup> <br> <color rgb=""> <font size="" name=""> <link href="">`; decodes numeric (`&#39;`, `&#x27;`) and HTML 4 named entities once, so escape user data (`ERB::Util.html_escape`) before wrapping it in your own tags: `&lt;b&gt;` stays literal text. |
| `text { b "Total"; plain " due" }` | Styled runs in Ruby. Take a block argument (`{ \|t\| t.b @x }`) to keep your own `self`. |
| `box(padding:, background:, border:, radius:, width:, height:, min_height:, overflow:, at:, link:, outset:, break_inside:, decoration:, rotate:, shadow:, float:, margin:) { }` | A container. Moves to the next page whole when it fits there and continues across pages when it does not; `break_inside: :auto` splits it at any page break, `:avoid` never splits it. At a cut, `decoration: :slice` (default) drops the padding and border, `:clone` keeps the padding. `overflow: :truncate` or `:shrink_to_fit` for fixed heights; a fixed `height:` never splits. `min_height:` is a floor that still splits: the first fragment keeps as much of it as the page holds, the next carries the rest (not combinable with `height:`). `at: [x, y]` pins it to a page position. `link:` makes the whole box clickable. `outset:` bleeds the background past the box (e.g. into the page margins). `rotate: -3` turns the painted box around its centre (layout box unchanged, never splits; a `link:` keeps its unrotated rectangle). `shadow: true` or `{ offset: [0, 4], blur: 8, color:, opacity: 0.15 }` paints a soft drop shadow under it, taking no space. `overflow: :hidden` clips the content to the rounded outline. `float: :left` or `:right` with a `width:` takes it to that side, `margin:` away from the text that wraps beside it: see [Floats](#floats). |
| `row(gap:, align:, break_inside:) { column(width:) { } }` | Columns side by side. `width:` is points, a fraction (`0.5`), `:auto` or `nil` (equal share). Splits across pages like a box, every column at once; a row with a fixed-height column never splits; columns with `min_height:` do. |
| `columns(count:, gap:, balance:, rule:) { }` | One flow poured through `count` columns, newspaper style: column 1 top to bottom, then column 2. Breaks where a page would (between lines with `orphans:`/`widows:`, never inside `break_inside: :avoid`, `keep_with_next` honoured). `balance: true` (default) ends the columns at nearly the same height where the content ends and fills them evenly, what cannot be shared going to the earlier columns (ten lines in three columns are 4, 3 and 3); `false` fills each before the next. Continues across pages; `page_break` inside ends the page; `rule: true \| { color:, width: }` draws a line between columns. |
| `table(rows, widths:, width:, header:, split_rows:, cell:) { \|t\| }` | Tables. Cells are strings, layout nodes, procs built with the DSL (`-> { image logo }`) or components. Style with `t.row(0)`, `t.rows(-1)`, `t.column(1)`, `t.columns(1..)`, chained, plus `t.zebra`. Header rows repeat after a page break. A cell may be `{ content:, colspan:, rowspan: }` plus any cell option; rows list only the cells they start, as in HTML, and pages never break through a rowspan. Spans are set in the rows, not through selections. A row taller than the page continues on the next page, cut through its cells, with the header repeated; `split_rows: true` cuts any row that reaches the page bottom instead of moving it whole. `rows` is an Array or any Enumerable; an Enumerator (lazy or not) given a width for every column is read as pages reach it, selected from its start only: see [Large documents](#large-documents). |
| `image(path_or_io, width:, height:, fit:, align:, radius:, rotate:, max_ppi:, downscale:, float:, margin:)` | JPEG, PNG or lossless WebP, aspect preserved. `fit: [w, h]` scales to fit inside; `fit: :cover` fills `width:` × `height:` and crops around the centre. `radius:` rounds the corners; `rotate:` turns it (degrees, clockwise) without changing the space it takes. Drawn at more than twice `max_ppi:` (300) it is reported as oversized; `downscale: true` resamples a PNG or WebP to that resolution instead. |
| `svg(source_or_path, width:, height:, color:, align:)` | Vector icons and drawings; `currentColor` takes `color:` (or the `color` an element sets). Linear and radial gradients (`fill="url(#id)"`, `href` chains, both gradient units); `text`/`tspan` in the document's fonts; `<style>` stylesheets (element, class, id and `*` selectors); `use`, `symbol` sprites and nested `svg` viewports (`viewBox`, `preserveAspectRatio`); `clipPath` (both `clipPathUnits`). |
| `barcode(data, type:, level:, module_size:, width:, height:, color:, quiet_zone:, native:, align:, alt:)` | A barcode drawn as vector bars, encoded in Ruby: `type: :code128` (the default; printable ASCII, digit runs in code set C), `:ean13` (12 digits and the check digit, or 13 checked), `:qr` (byte mode, `level: :l, :m, :q, :h`, versions 1 to 40, UTF-8 marked with an ECI) or `:datamatrix` (ECC 200 in ASCII encodation, digit pairs in one codeword, squares from 10 × 10 to 144 × 144). `module_size:` points a module (1, or 2 for a square one) or as many as fit `width:`; a linear one is `height:` (36) tall. The quiet zone is part of its size unless `quiet_zone: false`, and it shrinks to fit the space. Monochrome renders put it on the dot grid, a whole number of dots a module. `native: true` has `to_zpl` write the printer's own command for it: see [Label printers](#label-printers-to_zpl). A figure in a tagged PDF, its `alt:` by default the kind and the data. |
| `wrap(gap:, row_gap:, align:) { }` | Children side by side at their own widths, wrapping onto new rows (chips, tags). |
| `stack(gap:, align:) { }` | A base with layers painted over it: ordinary children set the height, `layer` children float over them and take no space. Moves to the next page whole. |
| `layer(top:, right:, bottom:, left:, width:, height:, **box) { }` | Inside `stack`: a box placed by insets from the stack's edges, in points or as a fraction (`0.4`, `1/3r`) of its width/height; negative insets overhang. Takes every box option (`rotate:`, `shadow:`, `radius:`, …). |
| `ul(style:, gap:, indent:, marker_gap:, marker_color:) { li "…" }` | Bulleted list. `style:` is `:disc`, `:circle`, `:square`, `:dash` or any String; unstyled nested lists cycle disc → circle → square. Any node added inside (not only `li`) becomes an item. Items split across pages; the marker stays with the first line. |
| `ol(format:, start:, suffix:, gap:, indent:, marker_gap:, marker_color:) { }` | Numbered list. `format:` is `:decimal`, `:alpha`, `:upper_alpha`, `:roman`, `:upper_roman` or a Proc `(n) -> String`; `suffix:` defaults to `"."`. Markers right-align so bodies line up. |
| `li(string, **style)`, `li(gap:) { }` | A list item: a paragraph, or a block of any elements (including nested lists). |
| `rule(height:, color:)`, `spacer(height)`, `page_break` | Dividers and spacing. |
| `group(keep_together: true, align:) { }` | Keep a block on one page. |
| `keep_with_next: true \| points` | On `text`, `box` or `group`: never end a page with this node; with a number, keep at least that many points of what follows with it. |
| `text_style(**style) { }` | Default text style for a block. |
| `canvas(height:) { \|canvas, rect\| }` | Draw directly: rectangles, rounded rectangles, circles, lines, Bézier paths, clipping, images, links; `rotate(degrees, around:) { }` and `transform([a, b, c, d, e, f]) { }` blocks. |
| `text_field(name, value:, width:, height:, multiline:, max_length:, comb:, read_only:, required:, font_size:, border:, background:, radius:, tooltip:, at:)` | An interactive text input (AcroForm). `width:` is `:full` or points; dotted names (`"address.city"`) group fields. See [Forms](#forms). |
| `checkbox(name, checked:, size:, label:, at:)` | An interactive check box, with an optional label drawn to its right. |
| `radio(name, value, checked:, size:, label:, at:)` | One choice of a radio group: radios sharing `name` form one field whose value is the checked `value`. |
| `select(name, options:, value:, width:, height:, editable:, at:)` | A drop-down (combo box); `editable: true` also accepts typed values. |
| `signature_field(name, width:, height:, label:, at:)` | An empty signature field for the signer to fill, drawn as a rule over the label. |
| `html(source, styles:, gap:, images:, base_path:, bookmarks:, links:, max_depth:)` | Rich text from HTML (ActionText/Trix, CMS output): paragraphs, headings, lists, quotes, code, rules, tables, images, inline marks and links, styled by a CSS subset (`<style>` rules and inline `style`). See [HTML and Markdown](#html-and-markdown). |
| `markdown(source, styles:, gap:, images:, base_path:, bookmarks:, links:, max_depth:)` | The same from CommonMark (plus GFM tables and strikethrough). |

Text style options: `font`, `size`, `weight` (`:regular`, `:bold`), `style` (`:italic`), `color`,
`letter_spacing`, `underline`, `strikethrough`, `link`, `opacity`, `kerning` (default `true`), `ligatures` (default `true`), `features` (OpenType feature tags, e.g. `%i[smcp onum]`), `hyphenate` (`true` for English, or `"de"`, `"sv"`; default off), `align` (`:left`, `:center`, `:right`, `:justify`), `leading`,
`orphans` and `widows` (the fewest lines a page break may leave behind and carry over; default 1, a paragraph that cannot meet them moves whole).
`align: :justify` stretches the spaces of wrapped lines to the full width; the last line, lines
ending in a newline and lines without spaces stay left-aligned (tabs are never stretched).
Colours are `"#RRGGBB"`, `"RRGGBB"`, `"#RGB"`, `[r, g, b]` (0-255) or `[c, m, y, k]` (0-100).

### Floats

`float: :left` or `:right` on an `image` or a `box` takes it to that edge of the flow it is written
in (the page body, a box, a column, a table cell); what follows it in that flow starts at its top
and wraps beside it, back to the full width below it, in the middle of a paragraph if need be.

```ruby
image "bay.jpg", float: :left, width: 0.4, margin: 12, alt: "The bay at dawn"
text story, align: :justify                     # beside the photo, then below it

box(float: :right, width: 170, margin: { left: 16, bottom: 6 }, padding: 10, role: :blockquote) do
  text "The view is everywhere.", size: 13, style: :italic
end
text more                                       # around the pull quote
```

- `margin:` is the space between the float and the text: a number is kept on the sides that face
  the text (the inner side and the bottom); a Hash (`{ left: 16, bottom: 6 }`, `x:`, `y:`) or an
  Array names the sides as `padding:` does. A floated box needs a `width:`: points, a fraction of
  the flow's width or `:auto`. Anything but `:left` and `:right` raises `ArgumentError`.
- Text (paragraphs, headings, the text inside a `group` or an `html` block) wraps: every line takes
  the width left at its own top and is aligned and justified in it. A paragraph whose widest word
  does not fit beside the floats starts below them.
- A list item and a `box` that takes the width it is given wrap what they hold, as a block does
  in CSS: they keep the full width, and their lines are narrow beside the float and wide below it.
  A box with a `background:`, a `border:`, a `shadow:` or a `link:` paints it across the full
  width, under the float: the float is painted after the boxes beside it, so it sits on top of the
  background, and a float with `opacity:` or a `shadow:` shows the background through it. The
  box's padding lies under the float, as a block's does in CSS, so beside the float its lines are
  the float's `margin:` away from it. A list item keeps its indent from the float, with the marker
  beside its first line, over the background of its body if the body has one.
- A `box` with a size or a place of its own (`width:`, `height:`, `rotate:`, `overflow:` other than
  `:visible`, `valign:` other than `:top`), a `row`, `columns`, a `table`, `rule`, `image`, `svg` or
  form field is a block: it goes beside the float in the width that is left, and keeps that width
  all the way down, when its own width (or the least its content takes) fits there; else it starts
  below the float. A `spacer` takes its height beside the float; a `page_break` ends the page and
  the float with it.
- Several floats: the next one goes beside those already there when it fits, else below them, and
  never above one written before it. Left and right floats share a line with the text between them.
- The flow that holds a float is at least as tall as the float, so what follows a box, a column or a
  cell starts below the floats inside it.
- Across pages a float never splits. When it does not fit what is left of the page, or the content
  after it could not start beside it there, it moves to the next page with that content. A
  paragraph beside a float splits between lines as always (`orphans:`, `widows:`); the lines carried
  over are wrapped again at the full width, because the float stayed behind. So are those of a list
  item and of a box. The part that stays on the page keeps the place its whole was given, beside
  the floats or below them.
- Floats written one after the other that are taller than a page together are cut before the
  first that does not fit: it starts the next page, with the floats and the text written after it,
  so the page it left holds the floats above it and nothing beside them. It is the same in a box, a
  list item, a column and a table cell. Only a float taller than a page by itself runs over it, and
  is reported as an `Overflow`. Floats that fit a page together stay together: when one of them
  does not fit what is left of the page, they all go to the next.
- What does not fit below the floats at the top of a page (a box that stays whole, a line where
  none is left) goes to the next page and leaves the floats behind.
- In a tagged PDF the float is where it was written, painted after the boxes beside it or not: an
  image is a `Figure`, a box has its `role:`, and a floated box without one beside a box with a
  background is a `Div`, which keeps its content in place.

A line beside a float is taken to be as tall as a line of the paragraph's own style when its width
is looked up, so one much taller word may reach a little past a float's bottom edge before the text
widens.

### HTML and Markdown

`html` and `markdown` render user content with the elements above; their parsers load on first use.

```ruby
def view_template
  html @post.body.to_s,                                   # ActionText
       images: ->(src) { blob_path_for(src) },            # path, IO or nil (skipped with a warning)
       styles: { h1: { size: 22 }, a: { color: "#0F766E" }, code: { font: "JetBrains Mono" } }
  markdown File.read("NOTES.md"), base_path: "docs", bookmarks: true
end
```

- Images come from `images:` (called with the `src`) or from files under `base_path:`; sources that
  resolve nowhere, point outside `base_path` or are remote URLs are skipped with a `SkippedImage`
  warning. Nothing is ever fetched over the network.
- `styles:` is deep-merged into the defaults: `h1`–`h6` (`scale:` of the text size, or `size:` in
  points; bold, `keep_with_next`), `p`, `a` (colour, underline), `code` (`font:`; register a
  monospace family for inline and block code, otherwise the text font is used), `pre` and
  `blockquote` (box options), `hr` (rule options), `table` (`cell:` options, `header:` text style),
  `ul` and `ol` (list options: `gap:`, `indent:`, `marker_gap:`, `marker_color:`, plus `style:` for
  `ul` and `format:`/`suffix:` for `ol`), `li` (text style) and `img` (`max_width:`, and `float_margin:` for a floated image without a CSS margin).
- Links are written only for `http`, `https`, `mailto` and `tel` hrefs (and `#anchor`); anything
  else (`javascript:`, `data:`, a relative path) keeps its text without a link and is reported as a
  `DroppedLink` warning. `links: %w[http https]` changes the list, `links: :all` keeps every href
  from a trusted source.
- `gap:` spaces the blocks (default 6); `bookmarks: true` adds h1–h3 to the PDF outline.
- `html` reads a subset of CSS from `<style>` elements and inline `style` attributes (see
  [What CSS is read](#what-css-is-read)); what it does not read is reported once as an
  `UnsupportedCss` warning. `markdown` reads none.
- `max_depth:` (default 64) is how deep the source may nest: HTML elements inside one another,
  or Markdown block quotes and lists. What lies deeper is flattened into the deepest element
  kept, so its text stays and its structure goes, and a `NestingLimit` warning says how deep the
  source went. Block quotes and lists also stop indenting after twelve levels, where they would
  leave their text no width; that is reported the same way.

#### What CSS is read

`html` applies `<style>` rules and inline `style` attributes on top of `styles:`. The cascade is
the usual one: the element's defaults from `styles:`, then stylesheet rules by specificity (id over
class over element, the later rule winning a tie), then the inline style, then the element's own
mark (`<b>`, `<i>`, `<u>`, `<s>`).

Selectors are an element name, `.class`, `#id`, any compound of them (`p.lead`, `td.n.total`),
comma lists and `*`. Selectors with combinators or pseudo-classes (`ul li`, `a > b`, `a:hover`) are
ignored and reported. At-rules are skipped, except that rules inside `@media print` and
`@media all` are read.

| Property | Values | Applies to |
| --- | --- | --- |
| `color` | `#rgb`, `#rrggbb`, `rgb()`, `rgba()` (alpha ignored), the common colour names | text, inherited |
| `font-size` | `px` (0.75 pt), `pt`, `em`, `%`, `xx-small` to `xx-large`, `smaller`, `larger`; relative sizes multiply the size around them | text, inherited |
| `font-weight` | `bold`, `normal`, `100`–`900` (600 and up is bold) | text, inherited |
| `font-style` | `italic`, `oblique`, `normal` | text, inherited |
| `text-decoration` | `underline`, `line-through`, `none` | text, inherited |
| `text-align` | `left`, `center`, `right`, `justify` | paragraphs, headings, cells, images; inherited from a container |
| `background-color` | as `color`, or `transparent` | `p`, `div` and other containers, `blockquote`, `pre`, `table`, `td`, `th` |
| `padding`, `padding-top` … `padding-left` | one to four lengths in `px` or `pt` | the same |
| `margin`, `margin-top` … `margin-left` | one to four lengths in `px` or `pt`: top and bottom are added to `gap:`, left and right indent the block. A negative margin is drawn as none | blocks, and a floated `img` |
| `border` | `1px solid #ccc` in any order, `none` | `table` (every cell), `td`, `th` |
| `width` | `px`, `pt`, `%`, `auto` | `img`, `table`, and `td`/`th` (column widths, when every cell of the first row has one) |
| `float` | `left`, `right`, `none` | `img` only: the text that follows wraps beside it. Its `margin`, with `margin-top` … `margin-left` over it, is kept around it, else `styles: { img: { float_margin: 8 } }` towards the text |
| `page-break-before`, `page-break-after`, `break-before`, `break-after` | `always`, `page`, `auto` | blocks |
| `page-break-inside`, `break-inside` | `avoid`, `auto` | blocks |
| `column-count`, `columns` | a number of columns, `auto` (a column width is not read) | `div` and other containers, `p`, headings, lists, tables, `blockquote`, `pre` |
| `column-gap` | a length in `px` or `pt`, `normal` | the same |

`margin` and its sides are read in the order of the cascade: a side wins over a `margin` declared
before it or by a lesser rule, and a `margin` takes back the sides declared before it.
`<font color size>`, `<center>` and `<img align="left|right">` (a float) are read the same way.
Everything else (`display`, `float` on anything but an image, `position`, `font-family`, `line-height`, `em` lengths outside `font-size`, `auto` margins, a negative `margin-left` or `margin-right`, `url()` values,
inline backgrounds) is ignored and named in the `UnsupportedCss` warning, so `strict` catches
content that expects more than this. No value is ever fetched: `url()` and `@import` are dropped.

```ruby
html <<~HTML
  <style>
    .note { background-color: #FEF3C7; padding: 8pt; margin: 6pt 0; break-inside: avoid }
    td.amount { text-align: right; width: 25% }
    h2 { page-break-before: always; color: #0F766E }
  </style>
  <div class="note"><p><b>Note.</b> Prices include VAT.</p></div>
HTML
```

#### Untrusted input

`html` and `markdown` are meant for content you did not write (a CMS body, a comment, an
ActionText field), and nothing in that content can reach outside the document or take the
process down:

- **No requests.** Remote images are never fetched; an image is read only from `images:` or from
  under `base_path:`, and a path that climbs out of it is skipped (`SkippedImage`).
- **No surprising links.** Only `http`, `https`, `mailto` and `tel` hrefs (and `#anchor`) become
  links (`DroppedLink` for the rest), so a `javascript:` or `file:` href is plain text.
- **No scripts, no fetched styles.** `script`, `template` and `title` content is dropped and raw
  HTML inside Markdown stays literal text. CSS is read only for the fixed list of properties
  above: `url()` and `@import` are dropped unread, and nothing in a style can position content
  outside the flow or hide it.
- **Bounded nesting.** Five thousand nested `<div>`s, block quotes or lists render flattened,
  with a `NestingLimit` warning, instead of exhausting the stack (the `svg` element guards its
  own nesting the same way, at 128 levels). Emphasis nests without recursion, at most 64
  brackets wait for their `]`, and a link label is at most 999 characters, so parsing takes time
  in proportion to the input.
- **Size is yours to bound.** There is no limit on how much text is rendered: a megabyte of
  input is a few hundred pages. Cap the length of what you accept before you render it, and use
  `strict` (or read `document.warnings`) when a warning should stop the document.

### Links, bookmarks and table of contents

A link target starting with `#` jumps to a named anchor in the same PDF; anything else is a URL.

```ruby
text "See the totals", link: "#totals"
text %(Back to the <a href="#intro">introduction</a>), markup: true
box(link: "#appendix") { text "Appendix" }

text "Introduction", anchor: "intro"      # also box(anchor:), group(anchor:), table(rows, anchor:)
box(anchor: "totals") { text "Totals" }
anchor "appendix"                         # standalone; moves to the next page with what follows it
text "Appendix", size: 16
```

An anchor on content that splits across pages points at its first page. A link to an unknown anchor
is dropped and reported as an `UnresolvedLink` warning; a name defined twice keeps the first and reports
a `DuplicateAnchor`. Anchors drawn by page templates resolve to the first page.

`bookmark:` adds an entry to the PDF outline (the viewer's bookmarks sidebar) pointing at where the
content paints. Levels nest under the nearest shallower entry above them; `open: true` shows an entry's
children expanded.

```ruby
text "Introduction", size: 18, bookmark: "Introduction"            # level 1
box(bookmark: { title: "Scope", level: 2, open: true }) { ... }    # also group(bookmark:), table(rows, bookmark:)
bookmark "Appendix", level: 1                                       # standalone; moves with what follows it
text "Appendix", size: 16
```

A document with bookmarks opens with the outline shown. A bookmark whose content never paints (cut off
by a fixed-height box) is left out; bookmarks inside page templates are ignored.

`table_of_contents` lists the bookmarks with the page each one landed on, one clickable row per entry.
It reads the outline when layout starts, so bookmarks declared after it are included.

```ruby
text "Contents", size: 18
table_of_contents                     # every level, dotted leaders
table_of_contents(levels: 1..2, leader: :line, indent: 16, size: 9, color: "#374151")
```

Options: `levels:` (a Range, or an Integer maximum depth), `leader:` (`:dots`, `:line` or `nil`),
`indent:` per level (points), `gap:` between rows and before the number, `number_width:` (defaults to
the width of "0000") plus any text style. Numbers are right-aligned in a fixed slot and filled in after
pagination, so a long contents list paginates without reflowing. An entry whose target never paints
keeps its title, with no number and no link.

### Forms

Form fields are interactive widgets (an AcroForm) that lay out like boxes, or sit at a fixed page
position with `at: [x, y]`. They work inside boxes, rows and table cells. The
[Forms guide](https://stationery.zoolutions.llc/docs/forms) lists every option of every field.

```ruby
text "Name"
text_field "applicant.name", value: @applicant.name, required: true
text_field "applicant.notes", multiline: true, height: 60
text_field "applicant.pin", comb: 6                      # six cells; sets max_length
select "applicant.country", options: %w[Sweden Norway Denmark], value: "Sweden"
radio "plan", "basic", label: "Basic"                    # radios sharing a name form one group
radio "plan", "pro", checked: true, label: "Pro"
checkbox "terms", checked: false, label: "I accept the terms"
signature_field "signature", label: "Signature of the applicant"
```

- Every widget carries its own appearance, so the form looks the same in every viewer. Text is set
  in the text style around the field, in the document's own fonts: embedded, with the fallbacks
  applied per character, so a value in any script the fonts cover is drawn (`/V` holds it as
  Unicode). A character no font has is drawn as `.notdef` inside a `Span` whose `ActualText` is the
  character, as in any other text (or as the font's stand-in under `conformance` with
  `missing_glyphs: :replace`), so the appearance still extracts as written. Check marks and radio dots are paths. `NeedAppearances` is set too, so viewers redraw
  edited values; ZapfDingbats is listed for the ones that redraw a button's mark, never embedded
  and never used by the appearances themselves.
- A field that can be edited keeps printable ASCII and Latin-1 in its font beyond the value it shows
  (and a select the glyphs of every option), about 10 KB per font, so the text a viewer redraws
  after an edit has its glyphs; what is typed outside that range falls back to the viewer's own
  font. A `read_only:` field keeps its value's glyphs only.
- `tooltip:` is a field's accessible name (`/TU`): by default a check box's or signature's `label:`,
  otherwise the field name. A radio group takes the `tooltip:` of its first choice.
- Dotted names build the field hierarchy viewers show as groups; widgets sharing a name are one field
  with several widgets. A name used as both a field and a group raises `ArgumentError`.
- `read_only:`, `required:`, `multiline:`, `max_length:` and `comb:` set the matching field flags.
- A radio group's value is its checked choice's `value` (`Off` when none is checked); a select box
  lists its `options:` and draws the chosen `value`; a signature field is left unsigned for the
  signer, unless `sign field:` signs it (see [Digital signatures](#digital-signatures)).
- `document.fields` returns `{ name => value }` for the last render (a check box's value is `true` or
  `false`, an unchecked radio group's and a signature field's `nil`). Encrypted documents keep their fields fillable.
- In tests, `document.fields` is what the form was filled with, and `have_pdf_text("Astrid", fields:
  true)` or `assert_pdf_text pdf, "Astrid", fields: true` finds what a field shows on the page. A
  value is drawn by its widget and is no part of the page content, so the text leaves it out
  without `fields: true` (see [Testing](#testing)).

## Components

Components have Phlex's lifecycle (`around_template`, `before_template`,
`view_template`, `after_template`) and `render`:

```ruby
class Callout < Stationery::Component
  def initialize(color:) = (super(); @color = color)
  def view_template(&) = box(background: @color, padding: 12, radius: 6, &)
end

render Callout.new(color: "#F3F4F6") { text "Amount due" }
```

`render` takes a component, a component class, a string, a proc or a list of those.

## Pages

- `page size: :a4 | :a3 | :a5 | :letter | :legal | :tabloid | [w, h], margin:, layout: :landscape`
- Sizes are points. `mm(102)`, `cm(2)`, `inch(4)` and `pt(12)` convert to them in every component and
  document (`include Stationery::Units` anywhere else), and `page` reads lengths with their unit:

  ```ruby
  class Label < Stationery::Document
    page size: ["102mm", "74mm"], margin: "3mm"     # or "102 x 74 mm", "4in x 6in", [mm(102), mm(74)]

    def view_template = box(at: [mm(20), mm(45)], width: mm(60)) { text "Fragile" }
  end
  ```

  Units are `mm`, `cm`, `in` and `pt`; decimals take a point (`"101.6mm"`). Beside the office sizes there
  are `:a6`, `:a7`, `:b5`, the envelopes `:dl`, `:c5` and `:c6` (short edge first: `layout: :landscape`
  is the address side) and the label stock `:label_4x6`, `:label_4x3`, `:label_4x2`, `:label_100x150`
  and `:label_100x50`. A size or margin that cannot be read raises `ArgumentError` when the class is
  defined.
- `page_template { |page| … }` runs on every page after pagination with `page.number`, `page.count`,
  `page.width`, `page.height`, `page.margin` and `page.content_box`. `page_template(layer: :background)`
  paints under the content (full-bleed backgrounds).
- `header` and `footer` reserve space at the top and bottom of the page; the body flows between them:

  ```ruby
  header(gap: 8) do |page|
    row do
      text "ACME"
      text "Page #{page.number} of #{page.count}", align: :right
    end
  end
  footer(on: :rest) { text "Confidential", size: 7, align: :center }
  header(on: :first) {} # no header on page 1
  ```

  `on:` takes `:all` (default), `:first`, `:rest`, `:odd`, `:even`, `:last`, a page number, a range or
  `->(number) { … }`; later declarations win for the pages they match, and an empty block removes the
  region there. `gap:` (default 8) is extra space between the region and the body. Without `height:` a
  region is measured once, on the first page that uses it; pass `height:` when its content varies per
  page. The footer is bottom-aligned. A region taller than its space is still drawn and listed in
  `document.warnings`; regions that leave no room for the body raise `ArgumentError`. With `on: :last`
  (say, a taller footer with totals) the paginator checks whether the rest fits above it; content that
  fits a normal page but not the last one continues onto an extra page.
- With a header or footer, a `page_template`'s `page.content_box` excludes their space (it is the
  body's area).
- `page_labels 1 => { style: :roman_lower }, 3 => { style: :decimal, start: 1, prefix: "A-" }` names
  the pages the way viewers show them ("i", "ii", "A-1", …): a 1-based first page mapped to the range
  that starts there, with `style:` `:decimal`, `:roman`, `:roman_lower`, `:alpha`, `:alpha_lower` or
  `nil` (prefix only), `start:` and `prefix:`. `to_pdf(page_labels:)` overrides it for one render.
- Content taller than a page is placed anyway; `document.warnings` lists every overflow.
- Content that does not fit a page continues on the next, as a letter or a report should. A label, a
  receipt or a card must not: `max_pages 1` in the class body says so. A render that needs more pages
  lays them all out and reports `Warnings::TooManyPages`, naming what the first page past the limit
  starts with, so `strict` raises:

  ```ruby
  class ShippingLabel < Stationery::Document
    page size: :label_4x6, margin: mm(4)
    max_pages 1
  end

  label.warnings.map(&:message)
  # => ["the document may have 1 page and needs 2: page 2 starts with a Code 128 barcode"]
  ```

  Text is named by its first line, quoted and cut at 40 characters, anything else by its kind (`a
  table`, `an image`, `a QR code`, `a box`). `to_pdf` and `to_png` keep every page, so the one that
  spilled can be looked at; `to_zpl` writes no label at all (see Label printers below). `to_pdf(max_pages:)`,
  `to_png(max_pages:)` and `to_zpl(max_pages:)` replace the limit for one render and `nil` takes it
  away, as `max_pages nil` does in a subclass; a subclass's `page` keeps it. The declaration writes
  nothing: a document that fits is byte for byte what it is without it.
- After `to_pdf`, `document.warnings` is an Enumerable of everything the render noticed but did not
  raise on, each with a `#message`: overflows, SVG elements that were skipped (`UnsupportedSvg`), and
  the other `Stationery::Warnings::*` kinds (missing glyphs, unknown font families, skipped images,
  unresolved links, duplicate anchors, in a tagged render what is missing for accessibility, and in a
  [monochrome](#monochrome) render the colours and lines a one-bit printer cannot print as they are).
  Equal warnings are listed once; warnings from page templates
  are included. `to_pdf(strict: true)`, or `strict` at class level, raises `Stationery::WarningsError`
  (with `#warnings`) instead of writing a PDF that produced any; `to_pdf(strict: false)` opts one
  render out again.
- After a render, `document.page_count` is how many pages it laid out: a tagged file's page
  dictionaries are packed into object streams, where a search of its bytes does not find them.

### Printing

A PDF can say how it wants to be printed. For a page that is the medium itself (a label, a card, a
pre-printed form) the defaults of a print dialog are the wrong ones: "fit to page" prints a
100 × 60 mm label at 94 %.

```ruby
class ShelfLabel < Stationery::Document
  page size: :label_100x50, margin: "3mm"
  print scaling: :none, copies: 2, pick_tray_by_size: true, duplex: :simplex
end

ShelfLabel.new.to_pdf(print: { copies: 1 })           # laid over the hints of the class
ShelfLabel.new.to_pdf(print: { duplex: nil })         # without one of them
ShelfLabel.new.to_pdf(print: nil)                     # without any (false does the same)
```

| Option | Values | Written as |
| --- | --- | --- |
| `scaling:` | `:none`, `:default` | `/PrintScaling` `/None`, `/AppDefault` |
| `copies:` | an Integer of 1 or more | `/NumCopies` |
| `pick_tray_by_size:` | `true`, `false` | `/PickTrayByPDFSize` |
| `duplex:` | `:simplex`, `:long_edge`, `:short_edge` | `/Duplex` `/Simplex`, `/DuplexFlipLongEdge`, `/DuplexFlipShortEdge` |
| `pages:` | a Range of page numbers from 1, or a list of them: `1..3`, `[1..1, 3..4]`, `2..` | `/PrintPageRange` |
| `dialog:` | `:on_open` | `/OpenAction << /S /Named /N /Print >>` |

- The first five are entries of the catalog's `/ViewerPreferences` (ISO 32000-1, 12.2, table 150),
  beside the `/DisplayDocTitle` of a tagged document. `dialog: :on_open` asks the viewer to open its
  print dialog when the file is opened, as `window.print()` does for a page, without JavaScript.
- `print` at class level adds to what the class inherits, and `to_pdf(print:)` to what the class
  declares. A `nil` takes a hint away (`print copies: nil` in a subclass).
- Every option is checked where it is written, the class body or the call of `to_pdf`, and raises
  `ArgumentError` naming what it takes: `print scaling: is :none or :default, not :fit`. Ranges that
  overlap are refused.
- `pages:` counts from 1, as the file does, and is written in page order. How many pages there are is
  known when the document is rendered: a range is cut at the last page (`2..` and `2..99` both end
  there) and one that starts after it is left out, because a viewer drops a range that names a page
  the document does not have.
- `/ViewerPreferences` is allowed under PDF/A and PDF/UA. The print dialog is not an action PDF/A
  has: `dialog: :on_open` with `conformance :pdf_a2b` or `:pdf_a3b` raises
  `Stationery::ConformanceError` (ISO 19005-2/3, 6.5.1; veraPDF rule 6.5.1-2). PDF/UA-1 alone takes it.
- The hints are written by every render: `incremental:`, signed and encrypted ones too.
- `print` in a class body is this declaration. Inside `view_template` and every other method of a
  document it is still `Kernel#print`.
- `Inspector#print_preferences` reads them back as `print` takes them, `pages` as a list of ranges,
  and `have_print_preference(scaling: :none)` and `assert_print_preference` assert them.

They are hints: a viewer follows the ones it knows, and whoever prints can overrule them in the
dialog. The table says what each viewer does and how that is known. Nothing in it was tried in a
running viewer: "documented" is what the vendor's PDF reference says, "source" what the viewer's
source code did when it was read on 2026-09-28, "reported" what a user wrote in the issue named.

| Viewer | `scaling:` | `copies:` | `duplex:` | `pages:` | `pick_tray_by_size:` | `dialog:` |
| --- | --- | --- | --- | --- | --- | --- |
| Acrobat, Acrobat Reader | sets the dialog (documented) | sets the dialog, 2 to 5 (documented) | sets the dialog (documented) | sets the dialog (documented) | sets the dialog (documented) | opens the dialog (reported, [pdf.js 11442](https://github.com/mozilla/pdf.js/issues/11442)) |
| Chrome, Edge (PDFium) | preset of the print preview (source) | preset of the print preview (source) | preset of the print preview (source) | not read (source) | not read (source) | starts printing (source) |
| Firefox (pdf.js) | read, not used by the viewer (source; [bug 1243580](https://bugzilla.mozilla.org/show_bug.cgi?id=1243580)) | read, not used (source) | read, not used (source) | read, not used (source) | read, not used (source) | starts printing (source) |
| Preview (macOS) | not tested | not tested | not tested | not tested | not tested | not tested |
| Evince, Okular (poppler) | not tested | not tested | not tested | not tested | not tested | not tested |

### Monochrome

A thermal label printer (203 or 300 dpi), a receipt printer or an e-paper display prints black or
nothing. Whatever else the PDF holds, the driver or the printer turns into dots of its own choosing:
grey text comes out speckled, a light rule or background vanishes or turns into a dot pattern, and a
line thinner than one dot prints or not depending on where it lands. `monochrome` makes those
choices where they can be seen, before anything is printed:

```ruby
class ShelfLabel < Stationery::Document
  page size: [mm(100), mm(60)], margin: mm(4)
  monochrome dpi: 203                               # report what a 203 dpi printer cannot print as it is
end

ShelfLabel.new.to_pdf(monochrome: { snap: true })  # change it instead, for this render
ShelfLabel.new.to_pdf(monochrome: false)           # as it was, byte for byte
```

| Option | Default | What it does |
| --- | --- | --- |
| `dpi:` | `203` | the printer's dots per inch: one dot is 72/dpi pt (0.355 pt at 203 dpi, 0.24 pt at 300) |
| `snap:` | `false` | change colours and thin lines instead of reporting them |
| `threshold:` | `0.5` | under `snap:`, a fill whose tone is darker is painted black, a lighter one is not painted |
| `dither:` | `:floyd_steinberg` | how a bitmap becomes dots: `:floyd_steinberg`, `:ordered` (an 8 × 8 Bayer pattern) or `:threshold` (cut at half) |

- **Colours.** Every colour that is not black or white, and anything painted at an `opacity:` below 1,
  is a `Warnings::NotMonochrome` naming the colour and what painted it: `text`, `a rule` (a `rule`,
  an underline, a strikethrough: a filled rectangle 3 pt thick or less), `a background` (any other
  fill), `a border or line` (any stroke), `a gradient` or `an image`, once per colour, kind and page:
  `text in #888888 on page 1 is not black or white`. `strict` raises on them. It sees whatever is
  painted, by an element, an SVG or a `canvas { }` block alike.
- **`snap: true`.** Text, rules, borders and lines are painted black, except white ones, which stay
  white (white text on a black box). A fill is painted black when its tone is darker than
  `threshold:` and left out when it is lighter; the tone is the colour's luma (ITU-R BT.601), an
  opacity laid over white paper (black at 0.3 is a tone of 0.7). A gradient is black or left out
  by the average tone of its stops. Opacity is taken away. Nothing is reported.
- **Line widths.** A stroke or a rule thinner than a dot (`width × the scale of a transform`) is a
  `Warnings::ThinLine` and is left as it is; with `snap: true` it is widened to a dot.
- **The dot grid.** Outside any transform, a filled rectangle (a rule, a background, an underline)
  and a stroke made of horizontal and vertical lines (a border, a table's cell borders, a line) are
  put on the printer's grid, counted from the top left corner of the page: their edges on whole dots
  and their widths whole numbers of dots, so a hairline is as wide on every label. A curve, a rounded
  corner, a slanted line and anything under a transform keeps its geometry.
- **Images.** A PNG, a lossless WebP or a JPEG is greyed (a transparent pixel is white paper),
  resampled to the dots it covers at `dpi:` and dithered, and embedded as a one-bit DeviceGray image
  (`/BitsPerComponent 1`): what prints is the pattern chosen here, not the driver's. A JPEG is decoded
  for it in Ruby, no larger than the dots need; one of a kind that is not decoded (lossless,
  arithmetic-coded, hierarchical, 12-bit) is embedded as it is and reported (`an image in JPEG 640x480`).
- `monochrome` at class level is inherited and adds to what the class inherits; `monochrome false`
  takes it away. `to_pdf(monochrome:)` takes `true`, `false` or options laid over the class's.
- Monochrome renders keep PDF/A and PDF/UA: the one-bit image is DeviceGray, which the sRGB output
  intent covers (checked with veraPDF, PDF/A-3b and PDF/UA-1).
- `Inspector#colors` lists what a PDF paints with, so a spec can hold it: `expect(pdf).to
  have_pdf_colors("#000000")`.

What it does not do: it does not dither a lossless, arithmetic-coded, hierarchical or 12-bit JPEG, does not look at form
fields (their widget draws them, not the page), does not put dashes, line caps or curves on the grid,
and does not make small text bolder. It changes nothing without `monochrome`. The rules live in
`Stationery::Monochrome::Rules` and `Monochrome::Grid`, apart from the PDF canvas, and `to_png` and
`to_zpl` apply the same ones (see below).

### Pictures of a render: to_png

`to_png` paints the pages `to_pdf` lays out on pixels instead, in Ruby, with nothing to install: a
preview, a picture to look at in a spec or a pull request, or what a one-bit printer will print.

```ruby
pngs = Invoice.new(invoice).to_png            # => ["\x89PNG…", …], one String per page, 96 dpi
Invoice.new(invoice).to_png("invoice.png")    # one page: invoice.png; several: invoice-1.png, invoice-2.png, …
Invoice.new(invoice).to_png(dpi: 144, pages: 1)             # pages: a number, a Range or an Array of them
ShelfLabel.new.to_png(monochrome: { dpi: 203, snap: true }) # one bit to a dot, 1-bit PNG
```

- **What is drawn**: text from the outlines of its glyphs (TrueType, CFF, WOFF; synthetic bold and
  oblique, letter spacing, rise, shaped runs), fills and strokes with their caps, joins (miter limit
  10) and dashes, even-odd and nonzero fills, clips, transforms and rotations, opacity, SVG linear and
  radial gradients, PNG, WebP and JPEG images, headers, footers, page templates (a background layer under
  the page) and page numbers. A colour picture is 24-bit RGB on white, anti-aliased; a text's origin,
  a stroke's horizontal and vertical edges and an upright image's edges are put on the pixel grid as
  poppler puts them, so it is close to `pdftoppm -r <dpi>` of the same PDF: the examples differ in
  0.0 to 0.5% of their pixels at 72 dpi, in the hinting of a few glyphs and the edges of images.
- **What is not**: a lossless, arithmetic-coded, hierarchical or 12-bit JPEG, which is not decoded, is drawn as a
  grey box with a cross and reported (`Warnings::SkippedImage`); form fields draw nothing (their
  widget is the PDF viewer's); links, bookmarks and tagging are not visible anyway.
- **Monochrome.** `monochrome:` takes what `to_pdf` takes, and the class's `monochrome` applies
  unless `monochrome: false` is given. The picture is drawn at the monochrome `dpi:` (a `dpi:` given
  to `to_png` replaces it), a pixel in or out by its centre with no anti-aliasing, and written as a
  1-bit PNG. The rules are those of the PDF (colours reported or snapped, thin lines, the dot grid,
  images dithered at the dots they cover); a page with grey left on it (a colour reported and kept
  without `snap:`) is dithered as images are. An upright image is drawn dot for dot as the one-bit
  image the PDF embeds, with its corner on the nearest dot: the PDF leaves the image's box where the
  layout put it, and its size in dots is the image's own, where poppler stretches it by a dot when both
  edges of the box round outwards. Black and white match `pdftoppm -mono` in all but 0.1 to 2% of the
  dots; dithered areas differ dot by dot, since poppler halftones where stationery dithers.
- **Options.** `dpi:` (96, or the monochrome dpi), `pages:`, `monochrome:`, `debug:` (the layout
  rectangles), `strict:`, `shaper:` and `max_pages:` as `to_pdf` has them. What only a PDF has (`sign:`, `encrypt:`,
  `conformance:`, `attachments:`, `print:`, `tagged:`, `page_labels:`, `xmp:`, `factur_x:`,
  `incremental:`, `missing_glyphs:`, `object_streams:`) raises `ArgumentError` when it is passed, and is left alone when
  the class declares it, so a signed or encrypted document still has pictures.
- **Speed.** A 100 × 150 mm label at 203 dpi (800 × 1200 dots) takes about 30 ms, a one-page invoice
  at 96 dpi about 0.1 s, a page of dithered photographs at 203 dpi about 0.7 s, a label with a
  12-megapixel JPEG photo about 1 s (Ruby 3.4 with YJIT,
  Apple M-series). Each page is kept as the list of what it was asked to draw until every page is
  painted, then drawn and encoded one at a time, so a long document does not hold a bitmap per page.

`Stationery::Raster` has the pieces: `Raster::Canvases` and `Raster::Canvas` record, `Raster::Painter`
replays onto a `Raster::Surface` through `Raster::Scanner` (coverage), `Raster::Stroker` and
`Raster::Flattener`, and `Raster::PNG` writes the file.

### Label printers: to_zpl

A thermal label printer (Zebra, and the many makes that emulate ZPL II) is driven in its own
language, not PDF. `to_zpl` writes the document as ZPL: each page is drawn one bit to a dot, as
`to_png(monochrome: …)` draws it, and sent as one graphic field, so the label is the layout `to_pdf`
produces, in any font the document uses. One document class serves the preview on screen and the
printer.

```ruby
class ShippingLabel < Stationery::Document
  page size: "4in x 6in", margin: mm(4)
  max_pages 1                               # a second page raises instead of printing a second label
  monochrome dpi: 203
end

label = ShippingLabel.new(parcel)
label.to_zpl                                # => "^XA^PW812^LL1218^LH0,0^FO0,0^GFA,…^XZ\n", one label per page
label.to_zpl("label.zpl", dpi: 300, copies: 2)
label.to_zpl(compression: :hex, pages: 1)   # plain hex, for printers that do not take Z64
```

How the ZPL reaches the printer is the application's business: a socket to port 9100, a print
server, a browser print agent. For example, over the network:

```ruby
require "socket"
TCPSocket.open("printer.local", 9100) { |socket| label.to_zpl(socket) }
```

- **What is written.** Per page `^XA`, `^PW` and `^LL` (the page's width and length in dots,
  `Raster.pixels(points, dpi)`), `^LH0,0`, `^FO0,0`, one `^GFA` graphic field, `^FS`, `^PQ` (copies)
  and `^XZ`, then a newline. The field's dots are 1 for black, each row padded to a byte with white.
  `compression: :z64` (the default) deflates the rows with zlib and writes them in Base64, followed
  by the CRC Zebra's software writes (CRC-16/XMODEM of the Base64 text, checked against a ZebraDesigner
  print file); `:hex` writes them as plain hex, about 20 times larger.
- **Always monochrome.** A label printer prints one bit, so `to_zpl` renders with the class's
  `monochrome` settings when it declares them and with the defaults when it does not (`snap: false`,
  `dither: :floyd_steinberg`): a colour is reported as `Warnings::NotMonochrome` and dithered, as
  `to_png(monochrome: true)` shows it. `monochrome:` takes options laid over them (`{ snap: true }`);
  `monochrome: false` raises.
- **`dpi:`** is the printer's: 152, 203, 300 or 600 (6, 8, 12 or 24 dots a millimetre); anything else
  raises `ArgumentError` naming them. It defaults to the class's `monochrome dpi:`, else 203, and
  replaces it when given, so `to_zpl(dpi: 300)` and `to_png(monochrome: { dpi: 300 })` are the same
  dots.
- **`copies:`** is `^PQ`, by default the class's `print copies:`, else 1. **`pages:`** a page number,
  a Range or an Array, in the order given; `target` a path or anything answering `write` (a socket).
- **One label.** Content that does not fit the label goes to a next page, and every page is a label.
  Declare `max_pages 1` (see Pages) and a document that needs a second page writes no ZPL:
  `to_zpl` raises `Stationery::WarningsError` with `Warnings::TooManyPages`, strict or not, because
  the harm of a second label is done when it prints, where no one reads a warning. `to_zpl(max_pages: nil)`
  writes them all; `to_pdf` and `to_png` of the same document keep every page and warn, so the page
  that spilled can be looked at.
- `strict:`, `debug:`, `shaper:` and `max_pages:` are those of `to_pdf`; what only a PDF has raises, as for `to_png`.
- **Speed.** A 4 × 6 in label takes about 25 ms at 203 dpi and 35 ms at 300 dpi (Ruby 3.4, Apple
  M-series), and is 10 to 20 KB of ZPL.
- The labels were read back and compared with `to_png` dot for dot, and rendered by
  [Labelary](http://labelary.com/viewer.html), a ZPL viewer, identically. They were not printed on a
  printer by the gem's specs.

**Barcodes the printer draws.** A `barcode` is part of the picture unless it asks otherwise:
`barcode "SX0042771903", native: true`, or `to_zpl(native: true)` for every barcode that does not
say `native: false`. Such a barcode is left out of the graphic field and written after it as the
printer's own command, where the picture had it, so the printer puts the bars on its own dot grid:

```
^FO146,874^BY4^BCN,124,N,N,N,N^FD>:SX>50042771903^FS             Code 128, its code sets named
^FO65,197^BY3^BEN,113,N,N^FD400638133393^FS                       EAN-13, the printer adds the check digit
^FO650,625^BQN,2,4^FDMM,B0034https://track.example/SX0042771903^FS  QR code, byte mode, level M
^FO42,42^BXN,8,200,14,14,6,_,1^FDSX0042771903^FS                  Data Matrix (ECC 200), 14 × 14
```

- `^BY` is the module in whole dots, the height in dots, and data ZPL would read as a command is
  escaped with `^FH`. A QR code's `^FO` is 10 dots above it, since `^BQ` draws that far below its
  origin. A Data Matrix is asked for at its own size, so it takes the same square.
- It stays in the picture when the printer could not draw it as it is: rotated or otherwise
  transformed, clipped, lighter than half grey, a module over 10 dots, a QR code of UTF-8 text
  (its ECI has no field in `^BQ`), or a Data Matrix holding `_` (the escape character `^BX` is given).
- Rendered by Labelary, the Code 128 is the same dots as `to_png` draws; the EAN-13's guard bars come
  out 13 dots longer, as the printer draws them; a QR code covers the same modules' square, its
  modules chosen by the printer's own encoder (another mask); a Data Matrix of digits and capitals is
  the same dots, one of other text another encodation in the same square. All decode (ZBar,
  dmtxread) to the data.
- Rules and boxes are not written as `^GB`: a box drawn natively would print over white text on it,
  which the picture keeps.

`stationery render label.rb --zpl --dpi 300` writes `label.zpl` (see [CLI](#cli)).

### Encryption

```ruby
class InvoicePdf < Stationery::Document
  encrypt owner_password: "s3cret", permissions: [:print] # every render
end

InvoicePdf.new(invoice).to_pdf(encrypt: { user_password: "1234", owner_password: "s3cret",
                                          permissions: %i[print copy] }) # override for one render
InvoicePdf.new(invoice).to_pdf(encrypt: nil) # plain
```

- `owner_password:` is required (`ArgumentError` when missing or empty); it opens the file with every
  right. `user_password:` defaults to `""`: the file opens without a prompt, but viewers enforce the
  permissions.
- `permissions:` is a subset of `%i[print modify copy annotate fill_forms extract_accessible assemble
  print_high]` (default: all).
- `algorithm:` picks the standard security handler. `:aes_256` (default, PDF 2.0 / Acrobat X+);
  `:aes_128` for older viewers; `:rc4_128` only for legacy readers that need it.
- Every string and stream is encrypted, the document info included.

### Embedded files

```ruby
class InvoicePdf < Stationery::Document
  attach_file "factur-x.xml", invoice_xml, mime: "text/xml", description: "Factur-X",
              relationship: :alternative # every render
end

InvoicePdf.new(invoice).to_pdf(attachments: [{ name: "terms.pdf", data: terms, mime: "application/pdf" }])
```

- Each file becomes a `/Filespec` with an `/EmbeddedFile` stream (`/Subtype` from `mime:`, `/Params`
  with size, MD5 checksum and `modified_at:`), listed in the catalog's `/EmbeddedFiles` name tree
  and its `/AF` array; `description:` is the `/Desc` viewers show.
- `relationship:` writes `/AFRelationship`: `:alternative` (a machine-readable twin, as Factur-X
  and ZUGFeRD require), `:source`, `:data`, `:supplement` or `:unspecified` (default).
- Per-render `attachments:` are added to the class-level ones; the same name twice raises
  `ArgumentError`. An encrypted document encrypts the embedded streams too.
- For an e-invoice, [`factur_x`](#factur-x--zugferd-e-invoices) embeds the XML, claims PDF/A-3b
  and writes the identification in one line.

### Accessibility (tagged PDF)

```ruby
class ReportPdf < Stationery::Document
  tagged                                   # or to_pdf(tagged: true) for one render
  metadata title: "Q3 report", lang: "en-US"

  def view_template
    text "Quarterly report", size: 20, heading: 1
    text "Revenue grew in every region."
    image "chart.png", width: 300, alt: "Revenue by region, Q1 to Q3"
    box(role: :note, padding: 8) { text "Figures are unaudited." }
  end
end
```

A tagged PDF carries a structure tree screen readers and reflowing viewers follow, in paint order
and across page breaks: a paragraph continued on the next page stays one `P`.

- `text` is a `P`; `heading: 1..6` makes it `H1`–`H6`.
- `image`/`svg` are a `Figure` with `/Alt` from `alt:` and a bounding box; `alt: false` marks one
  decorative (an artifact, not announced).
- `box(role:)` groups its content: `:section` (`Sect`), `:div`, `:blockquote`, `:note`, `:caption`,
  `:article` (`Art`), `:part`. Boxes without a role, rows, columns, groups and wraps add no element.
- Lists are `L` (with `/ListNumbering` from the bullet shape or number format) > `LI` > `Lbl` (a text
  marker; drawn bullets are artifacts) and `LBody`.
- Tables are `Table` > `TR` > `TH` (header rows, `/Scope /Column`) or `TD`, with `/ColSpan` and
  `/RowSpan`. A table split across pages stays one `Table`; its repeated header rows are artifacts.
- Linked text is a `Link` inside its paragraph holding the link annotation (`/OBJR`, `/StructParent`);
  `box(link:)` groups its content in a `Link`.
- `table_of_contents` is `TOC` > `TOCI` > `Link` (the title and its annotation) and `Reference` (the
  page number).
- `html`/`markdown` tag headings `H1`–`H6` (with or without `bookmarks: true`) and block quotes
  `BlockQuote`, and give images their `alt`. In `html`, `<img alt="">` is decoration as `alt: false`
  is (an `<img>` without the attribute is a description missing). Markdown has no way to say so:
  `![](photo.png)` is a description missing, and decoration goes through `html` or `image`.
- Headers, footers and page templates are pagination artifacts, but for their links: a `link:` one
  paints (`text(link:)`, markup, `html`, `markdown`, `box(link:)`) is a `Link` of the `Document`
  holding its text and its annotation, read after the content of its page, in the order header,
  footer, page templates. The rest of the region stays an artifact. Backgrounds, borders and rules
  drawn outside any element are layout artifacts.
- `metadata lang:` writes the catalog's `/Lang`; the title is shown instead of the file name.
- Every document carries an XMP packet (`/Metadata`, uncompressed) mirroring the Info dictionary:
  `dc:title`, `dc:creator`, `dc:description`, `dc:subject`, `dc:language`, the `xmp:` dates and
  `pdf:Producer`. PDF/A and PDF/UA identification lives there (see
  [PDF/A and PDF/UA](#pdfa-and-pdfua)); `metadata xmp: false` or `to_pdf(xmp: false)` leaves it out.
- An image or drawing without `alt:`, or with a blank one (`alt: ""`, whitespace alone, which
  veraPDF would accept), is a `Warnings::MissingAlt`; `alt: false` is how decoration is marked.
- A heading level that is skipped is a `Warnings::SkippedHeading` (`level`, `allowed`, `page`): the
  first heading is `heading: 1` and a heading is at most one level below the heading before it
  (`1`, then `3` skips `2`). Going back up is free (`3`, then `1`). Headings are read in the order of
  the structure tree, inside sections, lists, table cells, columns and floats; those of headers,
  footers and page templates are artifacts and do not count.
- A link annotation that belongs to no `Link` element is a `Warnings::UntaggedLink` (`target`,
  `place`, `page`): a link in the header row a table repeats on its next pages, which is an artifact
  (`place` is `:artifact`), and `canvas.link` without a `tag:` (`:canvas` in the body, `:header`,
  `:footer` or `:page_template` on the canvas of one). Every `link:` is tagged, in the body and in
  headers, footers and page templates; on a canvas of the body, pass the `Link` element that holds
  what the link draws: `canvas.link(x, y, w, h, url, tag: element)` after
  `canvas.tag(element) { … }`.
- A missing `lang` is a `Warnings::MissingLanguage`. All four are warnings, so `strict` catches them,
  and `conformance :pdf_ua1` raises on the first three.
- A tagged render packs its structure elements, and every other object that is not a stream, into
  deflated object streams (`/Type /ObjStm`, 200 objects each) with a cross-reference stream in place
  of the table and trailer (ISO 32000-1, 7.5.7 and 7.5.8). A table of 300 rows is 115 KB instead of
  501 KB. Streams, the `/Encrypt` dictionary and a signature dictionary stay out; PDF/A-2, PDF/A-3 and
  PDF/UA-1 allow them. `object_streams false` at class level, or `to_pdf(object_streams: false)`,
  writes the classic table for a reader that cannot read them; `to_pdf(object_streams: true)` packs
  an untagged render too.
- Untagged documents (the default) are written exactly as before.

Check the tree in tests with `have_structure` and `have_tagged_content` (see [Testing](#testing)):

```ruby
expect(ReportPdf.new).to have_tagged_content # tagged, and no text outside marked content
expect(ReportPdf.new).to have_structure(
  [[:Document, [[:H1, "Quarterly report"], [:P, "Revenue grew in every region."],
                [:Figure, "Revenue by region, Q1 to Q3"], [:Note, [[:P, "Figures are unaudited."]]]]]]
)
```

`tagged` alone does not label the file; `conformance :pdf_ua1` does (see
[PDF/A and PDF/UA](#pdfa-and-pdfua)). Nothing checks colour contrast or the reading order you build
out of positioned boxes (`box(at:)` joins the reading order where it paints).

### PDF/A and PDF/UA

```ruby
class InvoicePdf < Stationery::Document
  conformance :pdf_a3b            # archival: :pdf_a2b or :pdf_a3b
end

class ReportPdf < Stationery::Document
  conformance :pdf_a3b, :pdf_ua1  # archival and accessible
  metadata title: "Annual report 2026", lang: "en"
end

InvoicePdf.new(invoice).to_pdf(conformance: nil) # one render without the claim, or with another
```

A level is only claimed when the file keeps it, so what cannot conform raises instead of being
mislabelled: `ArgumentError` for options that contradict the level, `Stationery::ConformanceError`
(`levels`, `issues`) for content.

- **PDF/A-2b and PDF/A-3b** (ISO 19005, level B: the look is reproducible): an sRGB
  `OutputIntent` with the embedded ICC profile (the ICC's `sRGB2014.icc`), `pdfaid:part` and
  `pdfaid:conformance` in the XMP packet (written even with `xmp: false`), the print flag on every
  annotation. Fonts are always embedded and subsetted, and transparency is allowed from part 2 on.
  `encrypt:` raises. Embedded files need `:pdf_a3b` (part 2 only embeds PDF/A files, so
  `attach_file` raises there). CMYK colours and CMYK JPEGs are not covered by the sRGB intent and
  are reported as `Warnings::ConformanceIssue`, so `strict` refuses them.
- **PDF/UA-1** (ISO 14289): turns `tagged` on, needs `metadata title:` and `lang:`, writes
  `pdfuaid:part`, shows the title in the viewer, orders tabs by structure (`/Tabs /S`) and gives
  every link annotation a description (`/Contents`: the URL, or the target page). A figure without
  `alt:` or with a blank one raises (7.3); mark decoration with `alt: false`, or `<img alt="">` in
  `html`. A heading level that is skipped raises (7.4.2): the first heading is `heading: 1`, and a
  heading is at most one level below the heading before it. A link annotation outside the structure
  tree raises (7.18.5): a link in the header row a table repeats, or `canvas.link` without a `tag:`.
  Every other link is tagged, those of headers, footers and page templates too.
  PDF/A alone asks for none of the three. Encryption is allowed.
- Combined, the XMP packet also describes the `pdfuaid` schema to PDF/A (`pdfaExtension:schemas`).
- Interactive form fields are allowed: their appearances draw with embedded fonts and paths, every
  field has a `/TU`, and `NeedAppearances` and ZapfDingbats are left out. Only a field made without
  a font book (`Forms::Field.new` placed with `canvas.widget`) raises, since it draws with the
  standard Helvetica.
- A character no font has raises at every level, naming the character and the family: it draws as
  `.notdef`, which text may not reference under PDF/A (6.2.11.8) or PDF/UA (7.21.8). Add a font or
  `font_fallbacks` that covers it, or let the render draw a stand-in with `missing_glyphs: :replace`
  (below). Whitespace a font lacks draws as a blank and is accepted.
- Without `conformance` nothing changes: the output is byte for byte what it was.

A name in a script the fonts do not cover (a customer in Tokyo on an invoice archived as PDF/A) is
where the raise turns up in practice. Applications rescued it and rendered again without the claim:

```ruby
begin
  InvoicePdf.new(invoice).to_pdf
rescue Stationery::ConformanceError => e
  logger.warn(e.message)
  InvoicePdf.new(invoice).to_pdf(conformance: nil)   # mislabelled no more, but no longer PDF/A
end
```

`missing_glyphs: :replace` keeps the claim instead: a character no font has is drawn as the first
of U+FFFD (�), U+25A1 (□) and `?` that the font drawing it has, inside the `Span` whose `ActualText`
is the character, so the text still extracts, copies and reads aloud as written and nothing
references `.notdef`. The stand-in has its own advance, so lines are measured as they are drawn.

```ruby
class InvoicePdf < Stationery::Document
  conformance :pdf_a3b, missing_glyphs: :replace   # :raise is the default
end

InvoicePdf.new(invoice).to_pdf(conformance: :pdf_a3b, missing_glyphs: :replace) # per render
```

The `Warnings::MissingGlyph` stays (its `stand_in` is the character drawn, and `strict` still
raises on it), so what was replaced is on record. A font that has none of the three, which a
symbol font may not, still raises and says so. veraPDF passes 2b, 3b and ua1 with each of the
three stand-ins, in body text, headers and page templates, form field values and shaped text.
Without `conformance` the option changes nothing, and with `:raise` neither.

`bundle exec rake verify:conformance` renders `examples/invoice.rb` as PDF/A-3b, and
`examples/report.rb`, `examples/form.rb`, `examples/article.rb` (floats), `examples/newsletter.rb`
(columns) and `examples/accessible_report.rb` (figures, a table with header cells) as PDF/A-3b plus
PDF/UA-1, the report once more with a link in its footer, and validates
them with
[veraPDF](https://verapdf.org): a `verapdf` on the PATH when there is one (`brew install verapdf`),
else through Docker (`verapdf/cli`); CI runs it on every push. Validate your own documents the same
way:

```sh
verapdf --format text -v --flavour 3b invoice.pdf
docker run --rm -v "$PWD:/data:ro" verapdf/cli --format text -v --flavour 3b /data/invoice.pdf
```

In tests, `have_conformance(:pdf_a3b)` checks the claim (not the validity: that is veraPDF's job).

### Viewers: stationery verify

veraPDF answers whether a file keeps PDF/A or PDF/UA, not whether it works where people open it.
A file can pass PDF/A-3b and still trip a viewer, and open everywhere and still fail PDF/A. No
validator answers "works in every viewer", so `stationery verify` reads the file with the engines
the viewers are built on and holds what each reads against what the file holds, as pdf-reader
reads it (`stationery verify` needs the `pdf-reader` gem, as `inspect` does):

| Engine | Viewers | Checks |
|---|---|---|
| qpdf | (the file's structure) | `--check` without an error or a warning; the page count |
| Poppler | Evince, Okular, the Linux desktop | pages; text; each page with content paints; every font embedded, with a ToUnicode map; attachments; signatures (`pdfsig`); a tagged file's structure tree |
| MuPDF | SumatraPDF, mobile viewers | pages; text; each page with content paints |
| PDFium | Chrome, Edge | pages; text; painting; links; outline; form fields and their appearances; signatures |
| pdf.js | Firefox | pages; text; painting operators; links; outline; form fields; attachments; a tagged file's structure tree |
| PDFKit | Preview, Safari (macOS) | pages; text; painting; links; outline; form fields |

Any error or warning from any engine fails the check. Text is found, not compared: both sides lose
their whitespace and soft hyphens and are NFKC-normalized, and each text line of a page must be in
what the engine reads of it. A page drawn blank on purpose passes; one with text or an image that
an engine paints all white fails. The few messages that are the check's environment and not the
file (pdf.js warns it has no OffscreenCanvas in Node, pdfsig that the machine has no certificate
store, Debian's mutool that it was built without colour management) are listed with why in
`Stationery::Verify::Allowlist`.

```sh
stationery verify invoice.pdf report.pdf                 # every engine installed
stationery verify invoice.rb                             # render it first
stationery verify invoice.pdf --engines qpdf,poppler     # these, and fail if one is missing
stationery verify locked.pdf --password 1234 --json
```

It exits 0 when every engine passes every file, 1 otherwise (or when no engine is installed), 2 on
a usage error, and prints one line per file and engine, the problems under it, then the engines not
installed with the line that installs each. The engines are tools you install; the gem depends on
none of them:

```sh
brew install qpdf poppler mupdf        # apt-get install qpdf poppler-utils mupdf-tools
pip install pypdfium2                  # STATIONERY_PYTHON=/path/to/python names another Python
npm i pdfjs-dist                       # STATIONERY_PDFJS=/path/to/node_modules/pdfjs-dist
```

PDFKit needs macOS and Swift (`xcode-select --install`). Poppler and MuPDF take `--password` on
their command lines, where other processes of the machine can see it; qpdf reads it from a file and
the scripted engines from the environment. pdfsig takes no password, so an encrypted file's
signatures are not read by Poppler. A Docker image has every engine but PDFKit:

```sh
docker run --rm -v "$PWD:/data:ro" ghcr.io/zoolutions/stationery-verify /data/invoice.pdf
```

`bundle exec rake verify:readers` renders every example, the renders `verify:conformance`
validates, an encrypted invoice, an invoice packed with object streams and a tagged report without
them to `tmp/readers/`, and checks them (`ENGINES=qpdf,pdfkit` to choose). CI checks them with the
image on Linux and with qpdf, Poppler, MuPDF and PDFKit on macOS. Adobe Acrobat cannot be driven
in CI: before a release, the maintainer opens a fixed set of them in Acrobat Reader on macOS and
Windows (see `AGENTS.md`).

### Factur-X / ZUGFeRD e-invoices

A Factur-X (in Germany: ZUGFeRD) invoice is one PDF that people read and accounting software
books: a PDF/A-3b file with the invoice as Cross Industry Invoice XML embedded in it.

```ruby
class InvoicePdf < Stationery::Document
  metadata title: "Invoice", lang: "en"
  factur_x(profile: :en16931) { @invoice.to_cii_xml } # evaluated in the document, per render
  # factur_x :invoice_xml                             # or a method name
  # factur_x File.read("factur-x.xml")                # or the XML itself

  def initialize(invoice) = (super(); @invoice = invoice)
end

InvoicePdf.new(invoice).to_pdf(factur_x: { xml:, profile: :extended }) # per render; nil for none
```

- `factur_x` claims `conformance :pdf_a3b` (added to declared levels such as `:pdf_ua1`;
  `:pdf_a2b` raises), embeds the XML as `factur-x.xml` (`text/xml`, described as "Factur-X
  Invoice", stamped with its modification date) and writes the `fx:` identification in XMP
  (`DocumentType INVOICE`, `DocumentFileName`, `Version`, `ConformanceLevel`) with the extension
  schema description PDF/A asks for.
- `profile:` is `:minimum`, `:basic_wl`, `:basic`, `:en16931` (default), `:extended` or
  `:xrechnung` (embedded as `xrechnung.xml`). The XML is the page's `:alternative`, except for
  `:minimum` and `:basic_wl`, whose XML is `:data` beside it. `filename:`, `version:` ("1.0")
  and `relationship:` override the defaults (ZUGFeRD 1.0 used `ZUGFeRD-invoice.xml`).
- Stationery carries the XML, it does not write or validate it: anything that does not start
  with `<?xml` or `<rsm:CrossIndustryInvoice` raises `ArgumentError`, and what is inside is your
  invoicing code's. `examples/e_invoice.rb` builds a minimal EN 16931 document from the example
  invoice's lines.
- Everything PDF/A-3b asks applies: no `encrypt:`. Form fields and a signature are fine.
- Without `factur_x` nothing changes.

`bundle exec rake verify:factur_x` validates `examples/e_invoice.rb` with the
[Mustang](https://www.mustangproject.org) validator through Docker: the PDF/A-3 container and the
XML against the EN 16931 schema and business rules. CI runs it with `verify:conformance`. In
tests, `have_factur_x(profile: :en16931)` checks that the invoice is named in XMP and embedded.

### Digital signatures

`sign` signs the file with a certificate and its private key, so a reader can tell who issued it
and that not a byte changed since. It needs nothing but Ruby's own `openssl`, loaded when the first
signature is made.

```ruby
class ContractPdf < Stationery::Document
  sign certificate: -> { Rails.application.credentials.dig(:signing, :certificate) }, # PEM or OpenSSL object
       key: -> { Rails.application.credentials.dig(:signing, :key) },                 # read per render
       chain: -> { [File.read("config/intermediate.pem")] },
       reason: "Approved", location: "Malmö", contact: "legal@acme.test",
       timestamp: "https://tsa.example/tsr"                                          # optional: PAdES B-T
  # sign { { certificate: signer.certificate, key: signer.key, field: "approval" } }  # or a block for all of it

  def view_template
    text "Contract"
    signature_field "approval", label: "Approved by" # `field: "approval"` signs this one
  end
end

ContractPdf.new.to_pdf(sign: { certificate:, key:, passphrase: "…" }) # per render; nil for none
```

- The signature is `/SubFilter /ETSI.CAdES.detached`: a detached CMS over every byte of the file
  except the signature itself, SHA-256 with an RSA (PKCS #1 v1.5) or EC (ECDSA) key, with the
  signed attributes PAdES baseline B-B asks for (content type, message digest and the ESS
  signing-certificate-v2 that binds it to the certificate; the signing time is the dictionary's
  `/M`). The certificate and its `chain:` travel in the signature.
- `certificate:` and `chain:` take an `OpenSSL::X509::Certificate` or PEM, `key:` an
  `OpenSSL::PKey` or PEM (`passphrase:` when it is encrypted). Any value may be a block or callable
  answering it for the document being rendered, and `certificate:`, `key:`, `chain:` and
  `passphrase:` a method name, so secrets are read when they are needed and never at class load.
  A key that is not the certificate's raises `ArgumentError`.
- `field:` names the `signature_field` to sign, which keeps its appearance. Without it the
  signature is invisible: a field of its own (`Signature1`) whose widget has no size, on the first
  page. `name:` is the signer's name (the certificate's common name by default), `at:` the signing
  time (`Time.now`).
- `timestamp: "https://tsa.example/tsr"` asks an RFC 3161 time-stamping authority (TSA) to sign the
  signature value and the time it saw it, and carries that token in the signature's unsigned
  attributes: PAdES baseline B-T. A reader can then trust the signing time, and the signature, after
  the signer's certificate has expired. It is one HTTP request per render, with Ruby's own
  `net/http`; `timestamp: { url:, username:, password:, hash: :sha256 }` adds HTTP basic auth or
  another digest (`:sha384`, `:sha512`), and `client:` (a callable given the request DER and
  answering the response DER) replaces the HTTP client. A TSA that cannot be reached, refuses, or
  answers for another request or another digest raises `Stationery::SignatureError`: the document
  is never written without the timestamp it was asked for.
- The file is written once, with `contents_size:` bytes kept free for the signature (8192, or
  16384 with a timestamp, whose token brings the TSA's certificates along), which is then filled in
  place. A long certificate chain may need more; a signature that does not fit raises and says so.
- A signed form asks viewers not to regenerate appearances (`NeedAppearances` is left out) and
  sets `/SigFlags 3`. `encrypt:` and `conformance` combine with `sign`: the signature is the one
  string encryption leaves in the clear, and a signed PDF/A-3b or PDF/UA-1 file still validates.
- Not covered: long-term validation data (LTV: the revocation answers and document timestamps of
  PAdES B-LT and B-LTA), a second signature, and signing a file that already exists. All of them
  need incremental updates; Stationery signs what it renders, once. Whether a viewer trusts the
  signer, or the TSA, is decided by their certificates and the viewer's trust list, not by the
  file.

`bundle exec rake verify:signature` signs `examples/invoice.rb` with a throwaway certificate and
verifies it with `openssl cms -verify` and, when poppler is installed, `pdfsig`; with
`TSA_URL=http://timestamp.digicert.com` it also timestamps a PDF/A-3b render at that authority and
checks the token (`verify:timestamp`, not part of CI: it needs the network).
`verify:conformance` validates signed PDF/A-3b and PDF/UA-1 renders with veraPDF. In tests,
`have_signature(name: "Acme Legal")` checks that a signature covers the whole file and verifies
against the certificate it carries.

### Debugging

`to_pdf(debug: true)` outlines every layout rectangle on top of the content: boxes (red, padding dashed),
row columns (blue), flow slots (grey, dotted), table cells (green, padding dashed), positioned boxes (pink),
images (teal) and the page content box (cyan). Pass an Array to outline only some kinds:

```ruby
Invoice.new.to_pdf("invoice.pdf", debug: %i[cell cell_padding])
```

## Rails

```ruby
# Gemfile
gem "stationery", require: "stationery/rails"
```

### Large documents

A render holds what it still has to paint. The nodes of a page are let go once the page is
painted, a table measures its rows as pages reach them, the fonts forget the lines they shaped
after 64 KB of text, and a page nothing paints on again (no header, footer or page template, no
contents page number waiting on it) keeps its deflated content stream instead of its operators.
None of that changes a byte of the file.

`to_pdf { |chunk| … }` streams the file to the block in pieces as it is written and answers the
number of bytes: the first bytes leave sooner and no output buffer is built. Every page is laid
out and painted before the first byte. The streamed file lists its objects in the order they
were written, a page's before the next page's and fonts, the structure tree and the catalog
last; the String keeps them in numbered order. Both are the same document. A signed document
cannot go to a block, since the signature covers every byte (`ArgumentError`). `to_pdf`,
`to_pdf(path)` and `to_pdf(io)` build the String and return it. In a controller with
`ActionController::Live`, `document.to_pdf { |chunk| response.stream.write(chunk) }` streams a
download; `send_pdf` and `render pdf:` buffer.

`to_pdf(incremental: true)`, or `incremental` at class level, writes each page's content as soon
as the page is painted and lets go of it; with a block it is handed over before the next page is
painted. It is for long documents with headers, footers, page templates or a table of contents:
those are painted once every page is known, so without it such a document holds the operators
of every page until then.

```ruby
class StatementPdf < Stationery::Document
  incremental                                   # or to_pdf(incremental: true) for one render
  footer { |page| text "Page #{page.number} of #{page.count}" }
end

StatementPdf.new(account).to_pdf { |chunk| response.stream.write(chunk) }
```

- The file is the same document written another way: page contents first, then fonts, the page
  tree, the outline and the catalog. What is painted once every page is known is a content
  stream of its own, under or over the page's body, so a page has up to three and the file is
  larger (1.5 → 1.7 MB for 1,039 pages with a footer).
- To a block, bytes leave while pages are painted: an error raised on a late page leaves the
  block with the start of a file.
- A render that has to be checked before anything is written takes the usual path, as if
  `incremental:` were not given: one with `conformance:` (PDF/A, PDF/UA, Factur-X: the audit
  reads the painted pages), one with `sign:` (the signature covers the finished file), and a
  `strict` one that goes to a block (a warning on the last page has to stop the first byte).
  `strict` to a String, a path or an IO is incremental and raises before anything is written.
- A document with none of them is written the same either way and gains nothing in memory.

Peak resident memory of one render in a fresh process, and the megabytes still alive when
pagination ends (`bundle exec rake memory`; Apple M2 Max, Ruby 3.4.2 +YJIT, on a busy machine:
two runs of the same render peak up to a fifth apart, what is alive repeats; the text documents
were measured on 0.11.0, the tables on 0.12.0):

| Document | Pages | | 0.10 | Now | `incremental: true` |
|---|---:|---|---:|---:|---:|
| Headings and paragraphs | 1,000 | peak | 391 MB | 111 MB | 108 MB |
| | | alive | 216 MB | 17 MB | 14 MB |
| | 5,001 | peak | 1,556 MB | 350 MB | 415 MB |
| | | alive | 1,062 MB | 41 MB | 25 MB |
| The same with a footer and a table of contents | 1,039 | peak | 397 MB | 145 MB | 106 MB |
| | | alive | 222 MB | 44 MB | 11 MB |
| | 5,189 | peak | 1,643 MB | 614 MB | 446 MB |
| | | alive | 1,080 MB | 180 MB | 20 MB |
| One table of 33,000 rows | 1,000 | peak | 901 MB | 174 MB | 174 MB |
| | | alive | 494 MB | 26 MB | 23 MB |
| One table of 165,000 rows | 5,000 | peak | 3,792 MB | 584 MB | 586 MB |
| | | alive | 2,437 MB | 40 MB | 25 MB |

What is left is the document as it was built: every node but a table cell's exists before the
first page is painted. A table with a column without a width resolves its column widths from every
cell, and keeps the widths, not the cell's text: a cell's node is built when a page reaches its row and let go with the page
(the table of 165,000 rows holds 105 MB when its columns are resolved, its cells and their
text, where it held 913 MB). In a tagged render the `TR`, `TH` and `TD` of a row are built
when a page paints it, and the structure tree holds them until the file is written: the
same table tagged peaks at 2.2 GB.

A table whose every column has a width (`widths:` in points or fractions) measures no cell for
its columns. Given its rows as an Enumerator, lazy or not, such a table reads them as pages
reach them, and holds the rows of the page being filled and the one after them, none before
its first page:

```ruby
rows = [%w[Order Customer Total]].each + Order.find_each.lazy.map { |o| [o.number, o.customer, o.total] }
table(rows, header: true, widths: [80, 0.5, 90]) do |t|
  t.row(0).weight = :bold
  t.columns(2).align = :right
  t.zebra(from: 1, color: "#F4F4F4")
end
```

- The header rows, `zebra`, `split_rows`, cells spanning columns and selections by index from
  the start (`t.row(0)`, `t.rows(1..)`, `t.columns(…)`) work as they do for an Array, applied to
  each row as it is read. A proc or component cell is built then, in the text style the table
  was given in.
- What needs the end of the table raises `ArgumentError`: a row counted from the end
  (`t.row(-1)`, `t.rows(1..-2)`) when it is selected, and a cell spanning rows or a row with more
  columns than widths when it is read.
- Anything that needs every row reads them all first: a table in a `row`, in a box with
  `break_inside: :avoid`, or beside a float is measured whole, as an Array is.
- An Enumerator with a column without a width is read when the table is built, as before: a
  flexible column needs every row's width first. An Array is read as it always was.

A price list with every width given, a header row and zebra stripes, `incremental: true`
(`PAGES=3031 DOCUMENTS=streamed,listed FORMS=incremental bundle exec rake memory`, then
`PAGES=30303`, same machine; and the objects the render allocates):

| Rows | Pages | Rows given as | Peak | Alive when built | Alive when paginated | Objects |
|---:|---:|---|---:|---:|---:|---:|
| 100,000 | 3,031 | an Enumerator | 81 MB | 9 MB | 18 MB | 70.0 million |
| | | an Array | 485 MB | 155 MB | 20 MB | 69.3 million |
| 1,000,000 | 30,303 | an Enumerator | 130 MB | 9 MB | 47 MB | 710 million |
| | | an Array | 2,758 MB | 1,474 MB | 64 MB | 702 million |

Streamed, the rows cost the same at any length; what grows is what the file still needs of
every page until it is written (47 MB alive after 30,303 pages), and the peak with it. A
streamed table allocates a little more (reading an Enumerator one row at a time costs a few
objects a row). A tagged render keeps the `TR`,
`TH` and `TD` of every painted row in the structure tree until the file is written, streamed or
not: streaming leaves out only the rows no page has reached, so the same 100,000 rows tagged
peak at 989 MB streamed and 1,230 MB as an Array.

Controllers gain `render pdf:` and `send_pdf`:

```ruby
def show
  render pdf: InvoicePdf.new(@invoice), filename: "invoice.pdf" # disposition: "attachment" to download
end

def download = send_pdf(InvoicePdf.new(@invoice), filename: "invoice.pdf", disposition: "attachment")
```

`render pdf:` only accepts a document; anything else raises `ArgumentError`.
Configure in `config/application.rb`:

| Key | Default | |
| --- | --- | --- |
| `config.stationery.renderer` | `true` | `false` skips `render pdf:` (keeps another gem's, e.g. wicked_pdf's) |
| `config.stationery.font_paths` | `["vendor/fonts"]` | directories under `Rails.root` added to `Stationery.font_paths` when they exist |
| `config.stationery.preview_paths` | `["spec/pdfs/previews", "test/pdfs/previews"]` | directories under `Rails.root` searched for `*_preview.rb` |
| `config.stationery.show_previews` | `Rails.env.development?` | mounts the preview routes |

### Previews

Like ActionMailer previews: a class ending in `Preview` under
`spec/pdfs/previews` (or `test/pdfs/previews`), one public method per sample
document.

```ruby
# spec/pdfs/previews/invoice_pdf_preview.rb
class InvoicePdfPreview < Stationery::Preview
  def paid = InvoicePdf.new(Invoice.paid.first)
  def overdue(params) = InvoicePdf.new(Invoice.find(params.fetch("id", Invoice.overdue.first.id)))
end
```

Open `/rails/stationery/previews` for the list; each one renders inline at
`/rails/stationery/previews/invoice_pdf/paid`. Query parameters reach methods
that take an argument (`?id=42`); `?debug=1` passes `debug: true` to `to_pdf`
when the document supports it. Preview files are re-`load`ed on every request,
so edits show up on refresh.

Anything that must be in effect *while* the document renders (an I18n locale,
`CurrentAttributes`, a time zone) goes in `around_render`, which wraps both the
preview method and `to_pdf`:

```ruby
class FlyerPdfPreview < Stationery::Preview
  def month(params) = FlyerPdf.new(Event.upcoming)

  def around_render(_name, params) = I18n.with_locale(params.fetch("locale", I18n.default_locale)) { yield }
end
```

`/rails/stationery/previews/flyer_pdf/month?locale=de` renders in German.
`Preview#to_pdf(name, params, debug:)` is the same entry point for your own code.

The gem has no Rails dependency; the Railtie loads only inside a Rails app.

## CLI

```sh
stationery render app/pdfs/invoice_pdf.rb                # writes app/pdfs/invoice_pdf.pdf
stationery render invoice.rb --out - > invoice.pdf       # PDF to stdout
stationery render pdfs.rb --class InvoicePdf --strict    # pick one; fail on layout warnings
stationery render invoice.rb --png                       # also invoice-1.png, … beside the PDF
stationery render report.rb --png-only --pages 1,3-4 --dpi 144
stationery render label.rb --zpl --dpi 300               # writes label.zpl for a label printer
```

`render` loads the file and renders the `Stationery::Document` it defines. A
document whose `initialize` needs arguments renders from `def self.preview`,
which returns an instance built with sample data. Layout warnings print to
stderr; `--strict` exits 1 instead of writing. `--zpl` writes ZPL instead of a
PDF (see [Label printers](#label-printers-to_zpl)), at `--dpi` 152, 203 (the
default), 300 or 600. `stationery help` lists the commands.

`--png` writes a picture of each page beside the PDF with `to_png` (see
[Pictures of a render](#pictures-of-a-render-to_png)), pure Ruby with nothing to
install, named after the PDF with the number of the page, and prints one line
per file (`wrote invoice-1.png (page 1, 794 x 1123 px)`), so an agent that
rendered a document can open what it made. `--dpi` is 96 by default (an A4 page
is 794 × 1123 px), `--pages` takes `2` or `1,3-4`, and `--png-only` writes the
pictures without the PDF.

```sh
stationery inspect invoice.pdf                           # what is on each page, as text
stationery inspect invoice.rb                            # render it first, with its warnings
stationery inspect invoice.pdf --json                    # Inspector#layout as JSON
```

`inspect` prints what is on each page for an agent that cannot read a picture,
and for a diff between two renders: the file's metadata, conformance claims,
print hints, attachments and signatures, the outline, then each page with its
size, its text lines (x, baseline y, font, size), images, links and form fields
with their rectangles in points from the top-left corner, the structure tree of
a tagged PDF and the warnings of the render. A section with nothing in it is
left out, and the dates are, so two renders of one document print the same.
It is `Inspector#layout` (see [Testing](#testing)) and needs the `pdf-reader`
gem.

```text
examples/invoice.rb
  pages     1
  title     Invoice

Page 1  595.3 x 841.9 pt
  Text (x, baseline y, font, size, text)
      44.0   65.5  OpenSans-Bold      22  Invoice INV-2026-042
      44.0  115.6  OpenSans-Bold       9  Invoice date
     134.0  115.6  OpenSans-Regular    9  26 September 2026
  Images (x, y, width x height, pixels)
     437.9   40.0  113.3 x 34  240 x 72 px
  Links (x, y, width x height, target)
     329.2  596.5  65.6 x 11.6  mailto:hello@acme.test
```

```sh
stationery verify invoice.pdf                            # in every engine installed
stationery verify invoice.rb --engines qpdf,pdfjs --json
```

`verify` reads PDFs, or the documents Ruby files define, with the engines
viewers are built on (qpdf, Poppler, MuPDF, PDFium, pdf.js, PDFKit) and fails
when one of them errs, warns or reads something the file does not hold. See
[Viewers](#viewers-stationery-verify).

```sh
stationery fonts list                                    # packs, licenses, what is in vendor/fonts
stationery fonts install noto_sans liberation_serif      # into vendor/fonts/<pack>/
stationery fonts install noto_sans --into app/fonts --force
stationery fonts install liberation_sans --from ~/Downloads/liberation-fonts-ttf-2.1.5.tar.gz  # offline
```

`fonts install` downloads pinned files over HTTPS, checks every SHA-256
before writing anything, and writes the license next to the fonts. Files
already present are kept unless `--force`. `--from` takes a directory or a
`.tar.gz` holding the same files (still SHA-checked). In Rails,
`bin/rails generate stationery:fonts noto_sans` does the same.

```sh
stationery examples                                      # the examples in the gem, what each shows
stationery examples invoice                              # the path of examples/invoice.rb there
stationery examples invoice --source                     # its code
```

`examples` lists the documents under `examples/` of the installed gem with the
first sentence of their header comment. With a name it prints the path of that
file, to read, copy or hand to `stationery render`.

```sh
stationery skill install                                 # the skill for the agents it finds, else Claude Code
stationery skill install --target claude --project       # into ./.claude/skills/stationery
stationery skill install --dir ~/agent-skills            # into any skills directory
stationery skill status                                  # current, outdated or missing, per agent
stationery skill print                                   # SKILL.md and its files, as one document
```

`skill install` writes the skill for coding agents that ships with the gem: a
`SKILL.md` and the reference and recipe files beside it, written from this
README and the examples for the version installed, with that version in its
front matter. `--target` is `claude` (`~/.claude/skills`), `codex`
(`~/.codex/skills`), `agents` (`~/.agents/skills`, read by OpenCode and others)
or `all`; without it the skill goes to each of them whose directory is there,
and to Claude Code when none is. `--project` writes under the current directory
instead of the home directory. A skill named `stationery` that the gem did not
write is kept unless `--force`. `skill status` says for each agent whether the
skill there is current, outdated (written for an older version: install it
again) or missing.

## Fonts and images

Fonts are TrueType (`.ttf`) or OpenType/CFF (`.otf`, name-keyed or
CID-keyed) files, WOFF 1.0 web fonts (`.woff`, unwrapped in memory), or
faces of a TrueType collection (`.ttc`): a `#N` suffix
on the path picks face N, counted from 0 (face 0 without a suffix):

```ruby
font_family "Brand", regular: "Brand.ttc#0", bold: "Brand.ttc#2"
```
 Only the glyphs a document uses are embedded (a CFF font
keeps its glyph numbering and subroutines; unused glyphs are blanked), with a
ToUnicode map so text copies and searches correctly. A style without its own
file (bold, italic) is synthesised.

Inter (regular, bold, italic, bold italic; SIL Open Font License) is bundled
and used when a document declares no family. `font_family "Inter"` with no
paths selects it explicitly, and `Stationery.bundled_fonts` lists what ships.
Font files are read lazily, on first use, never when the gem is required.

More families come as font packs, installed into your app at development
time (commit them; nothing is downloaded at runtime):

| Pack | Family | License |
|---|---|---|
| `inter` | Inter (copied from the gem) | OFL 1.1 |
| `noto_sans`, `noto_serif`, `noto_sans_mono` | Noto Sans, Noto Serif, Noto Sans Mono | OFL 1.1 |
| `liberation_sans`, `liberation_serif`, `liberation_mono` | Liberation Sans, Serif, Mono (metric-compatible with Arial, Times New Roman, Courier New) | OFL 1.1, Reserved Font Name "Liberation" |

`Stationery.font_paths` lists the directories searched for installed packs;
the Railtie adds `vendor/fonts` (and `config.stationery.font_paths`) when it
exists. With the pack's directory there, the family name is enough:

```ruby
font_family "Noto Sans"                                                # found in Stationery.font_paths
font_family "Noto Sans", **Stationery::Fonts.paths(:noto_sans, dir: "vendor/fonts") # outside Rails
```

or append it yourself: `Stationery.font_paths << File.expand_path("vendor/fonts")`.
From Ruby: `Stationery::Fonts.install(:noto_sans, into: "vendor/fonts")`
returns `{ regular: path, bold: path, … }`; `Stationery::Fonts.catalog` lists
the packs. `rake fonts:verify` (development only) downloads every pack and
checks its SHA-256s.

A character the text's family has no glyph for is drawn from the first
family in `font_fallbacks` that has it, then from bundled Inter, in the same
weight and style (synthesised when the family lacks the face):

```ruby
class Report < Stationery::Document
  font_family "Brand", regular: "Brand-Regular.ttf"
  font_family "Noto Sans Symbols", regular: "NotoSansSymbols-Regular.ttf"
  font_fallbacks "Noto Sans Symbols"

  def view_template = text("Next → ☃")
end
```

Spaces, joiners, variation selectors and combining marks stay with the
character before them. Whitespace no font has (an ideographic space U+3000,
a figure space, a narrow no-break space, …) is drawn as a blank of the
character's conventional width, never as `.notdef`. Any other glyph no font
has is drawn as the family's `.notdef` and reported as a
`Warnings::MissingGlyph` counting each drawn occurrence (so `strict` raises
on it, and a `conformance` level raises `ConformanceError` unless it is
declared with `missing_glyphs: :replace`, which draws the first of U+FFFD,
U+25A1 and `?` the font has instead; see [PDF/A and PDF/UA](#pdfa-and-pdfua)). The characters
themselves travel as the `ActualText` of a `Span` around the glyphs, so the
text still extracts, copies and reads aloud as written. Fallback covers every text element,
table cell, list marker, table of contents entry and page template text;
direct `canvas.text` calls draw with the font they are given.

Text is pair-kerned from the font's GPOS `kern` feature (PairPos lookups,
including class-based pairs and Extension lookups), falling back to the
legacy `kern` table (`kerning: false` on an element or in `default_text`
turns it off). Pairs that straddle a style or
font change are not kerned. Kerning only tightens in practice, so a kerned
line is never wider than the same line unkerned.

Standard ligatures (fi, fl, ffi, …) come from the font's GSUB `liga` feature
(LigatureSubst lookups, also behind Extension lookups) and are on by default;
`ligatures: false` on an element or in `default_text` turns them off.
Ligatures form within a run of one style and font, never across a line
break, and letter spacing turns them off. The PDF's ToUnicode map sends a
ligature glyph back to all of its characters, so copied and extracted text
still reads "office". Fonts without a `liga` feature (such as the bundled
Inter) are unaffected.

Other OpenType features are opt-in per element, `text_style` or
`default_text`: `features: %i[smcp onum]` applies the font's small caps and
oldstyle figures, `tnum`/`pnum` pick tabular or proportional figures for
tables, `zero` a slashed zero, `dlig` discretionary ligatures, `ss01`… the
stylistic sets. Single (SingleSubst) and ligature (LigatureSubst) lookups
are applied in the font's own order; a feature the font lacks is ignored,
and `Font#features` lists what a font offers. Substituted glyphs keep
their source characters in ToUnicode, so "2026" in oldstyle figures still
extracts as "2026". Contextual features (`calt`, `clig`, `frac`) need
lookup types the reader does not implement and do nothing.

Hyphenation is off unless asked for: `hyphenate: "de"` on `text`, `text_style`,
`default_text` or an `html`/`markdown` style (`styles: { p: { hyphenate: "de" } }`)
breaks a word that does not fit at the longest point Liang's algorithm allows
over the bundled TeX patterns (`true` or `"en"` for American English, `"de"`
for German, `"sv"` for Swedish; `lib/stationery/hyphenation/patterns/LICENSES.md`
names their authors and licences), drawing a hyphen at the break. A soft hyphen
(U+00AD, `&shy;` in HTML) names the break points of a word yourself and, as in
TeX, exempts that word from the patterns; it is never measured or drawn and
never reaches the PDF. `Stationery::Hyphenation.hyphenate("Silbentrennung", "de")`
answers `["Sil", "ben", "tren", "nung"]` for your own use.
Lines also break at a zero-width space (U+200B, `<wbr>` in HTML), which is never
drawn, and between ideographic characters (CJK ideographs, kana, Hangul), keeping
a closing mark such as 。」 on the line before it and an opening bracket with what
follows, so Japanese, Chinese and Korean text wraps without spaces.

Images are JPEG (grey, RGB, CMYK), PNG (every colour type, alpha as a soft
mask) and lossless WebP (decoded in Ruby and embedded like a PNG, alpha as a
soft mask; lossy and animated WebP raise `UnsupportedImage`). Parsed fonts and
images are cached per process.

A bitmap keeps its pixels, so a 1600 px photo drawn 160 pt wide ships all
1600 px at 720 ppi. An image drawn at more than twice the document's
`max_ppi` (300, or `images max_ppi: 220` at class level, `nil` to switch the
check off) is reported as a `Warnings::OversizedImage` naming the file, its
pixel width and the resolution it lands at. `images downscale: true` (or
`image(..., downscale: true)`) resamples a PNG or a WebP to `max_ppi` at its drawn size
before embedding it, alpha included; a JPEG is embedded byte for byte, so
resize it before you embed it (an ActiveStorage variant per drawn size,
preprocessed, keeps a render to a download).

A JPEG's pixels are decoded in Ruby only where pixels are needed, for
`to_png` and a `monochrome` render; a PDF embeds its bytes. Baseline,
extended and progressive JPEGs are decoded (every chroma subsampling,
restart intervals, grey, RGB, YCbCr, CMYK and YCCK, CMYK turned into RGB)
to the pixels libjpeg-turbo gives them, and a photo drawn small at a half, a
quarter or an eighth of its size (libjpeg's scaled IDCT). A lossless,
arithmetic-coded, hierarchical or 12-bit JPEG, or one of more than 33 megapixels, is not:
a picture draws it as a crossed box and a monochrome PDF embeds it as it is,
each with a warning. The EXIF orientation is not applied, as the PDF does
not apply it either.

### Complex scripts: the shaper hook

Stationery places glyphs itself: one per character, the font's ligatures and single substitutions,
pair kerning. Arabic, Hebrew, Indic and Thai text need a shaper, and the gem does not have one. An
application that does (HarfBuzz) plugs it in, for a document class or for one render:

```ruby
class Invoice < Stationery::Document
  shaper HarfBuzzShaper.new            # inherited; `shaper nil` takes an inherited one away
end

Invoice.new.to_pdf(shaper: my_shaper)  # this render only
```

A shaper is anything that answers `call`:

```ruby
def call(text, font, size:, features:, language:, **)
  # => [Stationery::Shaper::Glyph.new(gid:, advance:, cluster:, x_offset: 0, y_offset: 0), …] or nil
end
```

| Argument | What it is |
|---|---|
| `text` | One stretch of a line in one font and style |
| `font` | A `Stationery::Shaper::Face`: `path` (the font file, nil when there is none), `index` (the face of a collection), `data` (the sfnt bytes; a WOFF is already unpacked), `units_per_em`, `postscript_name`, `glyph_count` |
| `size:` | The size drawn at, in points |
| `features:` | A frozen Hash of OpenType tags to switches: `"kern"` and `"liga"` always, following `kerning:` and `ligatures:` (letter spacing switches `liga` off), and the style's `features:` as `true` |
| `language:` | The document's `metadata lang:`, or nil |

The answer is the glyphs in **visual order**, left to right. `gid` is the glyph id in the font,
`advance` and the offsets are in font units, and `cluster` is the index, in characters, of the first
character of `text` the glyph stands for; glyphs of the same cluster stand together for the
characters up to the next cluster. A Hash of the same fields does for a `Glyph`. Answering `nil`
declines a text, which is then drawn as without a shaper. Anything else (a glyph id the font does
not have, a cluster outside the text, an advance that is not a number) raises
`Stationery::ShaperError`. Direction and script are not passed, because stationery knows neither:
the shaper works them out from the text.

What is shaped, and when:

- Line breaking works on the text as written and measures each word and each stretch of spaces on
  its own. Each line is then cut where the font or the style changes, and every such stretch is
  shaped whole. That one answer is the stretch's width (alignment, underline, link rectangle) and
  what is drawn, so the two always agree. The width a break was decided on is the sum of the words',
  which can differ a little from the shaped line's, as kerning across a space already does.
- The shaper is asked once per text, size and set of features in a render, and must answer the
  same for the same.
- Every text a document draws goes through it: `text`, table cells, lists, `html`, `markdown`,
  headers and footers, the table of contents, text in `svg`. Form fields do not: a viewer that
  redraws a field after an edit would not shape it either.

In the PDF the glyph ids are written as the shaper gave them. The font's widths stay its own, so an
advance the shaper changed is a `TJ` adjustment, an x offset moves the pen before the glyph and back
after it, and a y offset is a text rise (`Ts`) around it, which keeps marks in place under a
synthetic oblique, a superscript or letter spacing. Glyphs the shaper placed are embedded whether or
not a character maps to them. Where the ToUnicode map cannot give the text (glyphs out of logical
order, several glyphs for one cluster, a glyph that already stands for another text, glyph 0) the
glyphs are shown in a `Span` whose `ActualText` is the characters in logical order. Glyph 0 is
reported as a `Warnings::MissingGlyph`, like any other, and under `conformance` with
`missing_glyphs: :replace` it is drawn as the font's stand-in at the stand-in's advance.

The limits of a hook:

- The shaper reorders within the stretch it is given and nowhere else. Stretches on a line are placed
  left to right in the order written and lines break in that order, so there is no bidirectional
  reordering across a change of font or style; a right-to-left paragraph is set with `align: :right`,
  and the last line of a justified one is set left.
- Fallback fonts are chosen per character from the fonts' cmaps before anything is shaped. Give the
  text the family that covers its script, or digits and punctuation the first family has are drawn
  from it, as stretches of their own.
- Justification widens U+0020 spaces only (no kashida). Letter spacing is added after each cluster,
  so a mark stays on its base, but it pulls cursive letters apart.
- Hyphenation and the breaking of a word wider than the line cut the text as written; the pieces are
  shaped as separate words.
- Vertical advances are not read: text runs horizontally.
- Extracted text depends on the reader: the gem's `Inspector` and PDFium get a right-to-left stretch
  as written, poppler and MuPDF reversed (see the table below). pdf-reader's own `Page#text` drops a
  `Span` whose first glyph has no advance (a mark drawn first); the `Inspector` does not.

[`examples/shaping/harfbuzz_shaper.rb`](https://github.com/zoolutions/stationery/blob/main/examples/shaping/harfbuzz_shaper.rb)
is an adapter for HarfBuzz through the [`harfbuzz-ruby`](https://github.com/ydah/harfbuzz) gem
(`gem "harfbuzz-ruby"`, `require "harfbuzz"`; not the older `harfbuzz` gem, which answers to the same
`require`), about a hundred lines to copy into an application; stationery does not depend on it. It
was run with harfbuzz-ruby 1.1.0 and HarfBuzz 14.5.0 against Noto Sans Arabic, Amiri and Noto Sans
Hebrew and draws joined, right-to-left Arabic with its marks and with left-to-right digits inside it.
It cuts a stretch into runs of one direction by its letters alone, not by the Unicode bidirectional
algorithm.
The base direction of a stretch is its first letter's, so a line of an Arabic paragraph that starts
with a number stays right to left.
[`examples/shaping/rtl_letter.rb`](https://github.com/zoolutions/stationery/blob/main/examples/shaping/rtl_letter.rb)
is a letter in Arabic set with it (`ARABIC_FONT=NotoNaskhArabic-Regular.ttf ruby -Ilib
examples/shaping/rtl_letter.rb`); its booking number, in Latin letters from Inter, sits in a `row`
beside its Arabic label, since stretches of two fonts on one line are placed left to right.

What comes out of a shaped PDF depends on who reads it, and no way of writing right-to-left text
is read as written by every extractor. Seven texts (Arabic, Hebrew, Arabic with digits in it,
Arabic with its marks, an Arabic word in a Latin sentence, a justified paragraph, a line that wraps)
were rendered three ways and read back: **A**, what the gem writes, a `Span` around the stretch
with its text in logical order as `ActualText` (ISO 32000-1, 14.9.4); **B**, a `Span` for every
cluster, in visual order; **C**, no `Span` for a glyph the ToUnicode map gives its text, in visual
order, and one per cluster for the others. The cells count the texts that came back as written:

| Arabic font | | `Inspector` | PDFium | PDFKit | pdf.js | poppler | MuPDF |
|---|---|---|---|---|---|---|---|
| Amiri (a glyph per letter) | **A** | 7 of 7 | 7 of 7 | 6 of 7 | 4 of 7 | 0 of 7 | 0 of 7 |
| | B | 0 of 7 | 0 of 7 | 0 of 7 | 0 of 7 | 4 of 7 | 5 of 7 |
| | C | 0 of 7 | 1 of 7 | 6 of 7 | 4 of 7 | 4 of 7 | 5 of 7 |
| Noto Sans Arabic (a letter is its shape and its dots) | **A** | 7 of 7 | 6 of 7 | 1 of 7 | 1 of 7 | 0 of 7 | 0 of 7 |
| | B | 0 of 7 | 0 of 7 | 0 of 7 | 0 of 7 | 1 of 7 | 1 of 7 |
| | C | 0 of 7 | 0 of 7 | 1 of 7 | 1 of 7 | 1 of 7 | 1 of 7 |

- PDFium (153.0.7999, what Chrome reads with, through pypdfium2 5.13) and the gem's `Inspector`
  return `ActualText` as it is: A reads as written. Without it (C) PDFium returned the words of a
  right-to-left line in reverse order.
- poppler (`pdftotext` 26.09) and MuPDF (`mutool` 1.28.5) reorder what they read, `ActualText`
  included: A comes back reversed, B and C in Amiri as written, but for Arabic with digits or
  marks and, in poppler, a justified paragraph.
- pdf.js (pdfjs-dist 6.3.289) and PDFKit (macOS 27, what Preview reads with) returned the same for
  A and C, which differ in nothing but `ActualText`: they read the glyphs through the ToUnicode
  map and reorder them. A cluster of several glyphs comes back with its text once per glyph, so a
  letter with a mark is doubled, and so is every dotted letter of the Noto Arabic families (Sans,
  Naskh and Kufi draw a letter as two glyphs). Only `ActualText` carries the text of such a font.
- The Hebrew text (Noto Sans Hebrew) is the same in both halves of the table.
- veraPDF 1.30.2 passes all 42 renders as PDF/UA-1, so the rules of the standard do not choose.
- Acrobat, Preview itself and screen readers were not tested.

The gem keeps A: it is what the specification describes, the one PDFium reads as written, and
the only one that holds with a font whose glyphs are not letters. None of the three is read as
written by poppler or MuPDF and by PDFium.
[`examples/shaping/extraction_matrix.rb`](https://github.com/zoolutions/stationery/blob/main/examples/shaping/extraction_matrix.rb)
renders the texts, holds B and C as experiments and writes the table again, with what to install
at its head.

## Testing

`stationery/rspec` and `stationery/minitest` read a rendered PDF back for
assertions. They need the `pdf-reader` gem, which stationery itself does not
depend on:

```ruby
# Gemfile
group :test do
  gem "pdf-reader"
end
```

The subject is a document (rendered once), PDF bytes, a file path or an IO.

```ruby
# spec/spec_helper.rb
require "stationery/rspec"

RSpec.describe InvoicePdf do
  subject(:pdf) { InvoicePdf.new(invoice) }

  it { is_expected.to have_pdf_text("Invoice INV-7") }
  it { is_expected.to have_pdf_text_on_page(2, /Total €[\d ,]+/) }
  it { is_expected.to have_pdf_text("Astrid Lindqvist", fields: true) } # with what the form fields show
  it { is_expected.to have_page_count(2) }
  it { is_expected.to have_pdf_link("mailto:hello@acme.test") }
  it { is_expected.to have_image_count(1) }
  it { is_expected.to have_no_warnings }
  it { is_expected.to have_pdf_language("en") } # the catalog /Lang from `metadata lang:`
  it { is_expected.to have_page_labels(%w[i ii 1 2]) } # from `page_labels`
  it { is_expected.to have_print_preference(scaling: :none, copies: 2) } # from `print`
  it { is_expected.to have_pdf_colors("#000000") } # every colour it paints with, from `monochrome`
  it { is_expected.to have_attachment("factur-x.xml", mime: "text/xml", relationship: :alternative) }
  it { is_expected.to have_conformance(:pdf_a3b) } # the level claimed in XMP, from `conformance`
  it { is_expected.to have_factur_x(profile: :en16931) } # the e-invoice XML, named in XMP and embedded
  it { is_expected.to have_signature(name: "Acme Legal") } # covers the whole file and verifies
  it { is_expected.to have_tagged_content } # a tagged PDF with every text tagged or an artifact
  it { is_expected.to have_structure([[:Document, [[:H1, "Invoice"], [:P, "INV-7"]]]]) }
end
```

```ruby
# test/test_helper.rb
require "stationery/minitest"

class InvoicePdfTest < Minitest::Test
  include Stationery::Testing::Assertions

  def test_prints_the_total
    pdf = InvoicePdf.new(invoice)

    assert_pdf_text pdf, "Invoice INV-7"
    refute_pdf_text pdf, "DRAFT"
    assert_pdf_text pdf, "Astrid Lindqvist", fields: true
    assert_page_count pdf, 2
    assert_pdf_link pdf, /acme\.test/
    assert_no_pdf_warnings pdf
    assert_pdf_language pdf, "en"
    assert_page_labels pdf, %w[i ii 1 2]
    assert_print_preference pdf, scaling: :none, copies: 2
    assert_pdf_colors pdf, ["#000000"]
    assert_pdf_attachment pdf, "factur-x.xml", mime: "text/xml"
    assert_pdf_conformance pdf, :pdf_a3b
    assert_factur_x pdf, profile: :en16931
    assert_pdf_signature pdf, name: "Acme Legal"
    assert_tagged_content pdf
    assert_pdf_structure pdf, [[:Document, [[:H1, "Invoice"], [:P, "INV-7"]]]]
  end
end
```

The matcher names carry a `pdf_` prefix so they never clash with Capybara's
`have_text` and `have_link`. `have_bookmark` / `assert_bookmark` match outline
titles. The RSpec matchers compose like the built-ins: `.and` / `.or`, and inside
`all`, `include` or `match`. For anything else, `Stationery::Testing::Inspector.new(subject)`
exposes `text`, `page_texts`, `page_count`, `links`, `internal_links`,
`image_count`, `bookmarks`, `metadata`, `xmp` (the packet), `xmp_values` (`{ "dc:title" => …, "dc:creator" => […] }`),
`lang`, `page_labels`, `print_preferences` (`{ scaling: :none, pages: [1..3] }`), `colors`
(`["#000000", "#FF0000"]`), `attachments`, `conformance` (`[:pdf_a3b, :pdf_ua1]`), `factur_x`
(`{ profile:, filename:, version:, xml: }`), `signatures` (`[{ field:, name:, reason:, location:,
signed_at:, subfilter:, byte_range:, signer:, valid:, timestamp: }]`, the timestamp `nil` or
`{ time:, tsa:, valid: }`), `warnings`, `tagged?`,
`untagged_text` and
`structure` — a tagged PDF's structure tree as nested arrays, each element's text
read from its marked content: `[type, "text"]`, `[type, [children]]` (its own text
between the children, as for a `P` holding a `Link`) or `[type]` when empty; a
`Figure` reads as its alt text.

`colors` is every colour the page content and the form XObjects it draws set with `g`, `rg` and `k`
(and their stroking forms), once each and sorted, as `"#RRGGBB"` (CMYK converted without a profile),
with `"shading"` for a gradient and `"image"` for a bitmap that is not one bit of grey; a one-bit grey
image, as `monochrome` embeds, paints black and white only and adds nothing. Opacity and form
fields are not read. `have_pdf_colors("#000000")` and `assert_pdf_colors` hold the whole list.

`text` and `page_texts` are the text of the page content as pdf-reader lays it out, line by line. A
`Span` with `ActualText` (a stretch a shaper reordered, characters no font has) reads as that text,
once, whatever glyphs it shows.

A form field's value is not page content: its widget draws it, so `have_pdf_text("Astrid")` does not
find the value of a `text_field`. `fields: true` reads what the form fields show as well, each where
it is on its page: `have_pdf_text("Astrid", fields: true)`, `have_pdf_text_on_page(1, "Astrid",
fields: true)`, `assert_pdf_text pdf, "Astrid", fields: true`, `refute_pdf_text`, and
`Inspector#text(fields: true)` and `#page_texts(fields: true)`. What is read is the normal appearance
of every widget that is not hidden, in the state the widget is in, and never a button's `Off` state
(the marks of a `checkbox` and a `radio` are paths and read as nothing). Without `fields: true` the
text is what it always was, and the failure of `have_pdf_text` over a text that a field shows says
so.

`Inspector#layout` is what is on each page and what the file says of itself, as plain data in a
stable order: what `stationery inspect` prints (see [CLI](#cli)), for a spec that asks where
something landed. Places are in points from the top-left corner of the page, as the gem's API
speaks, rounded to a tenth; a text line's `y` is its baseline.

```ruby
layout = Stationery::Testing::Inspector.new(InvoicePdf.new(invoice)).layout
layout[:pages].first[:text].first
# => { x: 44.0, y: 65.5, font: "OpenSans-Bold", size: 22.0, text: "Invoice INV-2026-042" }
layout[:pages].first.keys  # => [:number, :label, :width, :height, :text, :images, :links, :fields]
layout.keys                # => [:metadata, :conformance, :tagged, :print, :outline, :attachments,
                           #     :signatures, :structure, :warnings, :pages]
```

A text line is a run of one font and size on one baseline, so a word set in bold is a line of its
own; lines read top to bottom, then left to right. An image is `{ x:, y:, width:, height:, pixels:
[w, h] }` in the order drawn (the rectangle it fills, before any clip); a link has its `uri:`, or the
`page:` and `top:` it goes to; a field has its full `name:`, `type:` (`:text`, `:choice`,
`:checkbox`, `:radio`, `:button`, `:signature`), `value:` and, for a button, the `state:` that turns
it on. `outline` is the bookmarks as `{ title:, page:, top:, children: }`. `metadata` leaves out the
dates, which change with every render, so two renders of one document have the same layout.
`warnings` are the render's messages when the subject is a document.

## Why not Prawn, Chrome or Typst?

- **Prawn** is an imperative cursor API: every document does its own layout
  arithmetic. Stationery is a layout engine with a component DSL.
- **sghtmltopdf** renders HTML and CSS in Rust, fast and with a real CSS layout
  engine, but writes no outline, forms, tagged PDF, PDF/A, encryption or
  signatures, and is a native extension.
- **Headless Chrome** (Grover, ferrum_pdf) renders HTML beautifully but runs
  a browser per worker; stray processes and memory are the price.
- **Typst** is excellent but a native extension and a second template language.

## Instrumentation

Every render reports its phases as events named `<phase>.stationery`, so an
APM that subscribes to `ActiveSupport::Notifications` (AppSignal, Skylight,
Rails' own log subscribers) shows where a slow PDF spends its time with no
setup: AppSignal groups them under "stationery" in the event tree. Outside
Rails the events go to a null instrumenter that costs one method call.

| Event | Around | Payload |
|---|---|---|
| `render.stationery` | the whole `to_pdf` | `document:`, `pages:`, `bytes:`, `warnings:` (count) |
| `build.stationery` | building the component tree | `document:` |
| `paginate.stationery` | layout, page breaks and page templates | `document:`, `pages:` |
| `write.stationery` | serialising, subsetting and deflating | `document:`, `bytes:` |
| `image.stationery` | decoding one image (cache misses only) | `format:`, `width:`, `height:`, `bytes:` |
| `font.stationery` | parsing a font file (`action: :parse`, cache misses only) or subsetting one for a document (`action: :subset`, `glyphs:`) | `path:` or `font:`, `action:` |
| `parse.stationery` | parsing an `html` or `markdown` source | `format:`, `bytes:` |

Payload values known only afterwards (`pages:`, `bytes:`) are filled in
before the event finishes, so subscribers always see them. Log every phase
slower than 100 ms:

```ruby
ActiveSupport::Notifications.subscribe(/\.stationery\z/) do |name, start, finish, _id, payload|
  ms = (finish - start) * 1000
  Rails.logger.info("#{name} #{ms.round}ms #{payload.inspect}") if ms > 100
end
```

Any object answering `instrument(name, payload) { |payload| }` can take the
events instead (`Stationery.instrumenter = MyInstrumenter.new`), and
`Stationery.instrument("custom.stationery", key: value) { … }` adds your own
spans inside a document. When you hit a slow render, a trace with these
events attached is the most useful thing to put in an issue.

## Performance

`bundle exec rake bench` renders three documents with Stationery, with Prawn 2.5 +
prawn-table, and with [sghtmltopdf](https://github.com/waka/sghtmltopdf) 0.5.1, an
HTML-to-PDF engine written in Rust, given HTML/CSS twins of the same documents. Every
engine embeds the same Open Sans TTF files (`benchmark/`, not part of CI). Apple M2 Max,
Ruby 3.4.2 +YJIT, 29 September 2026 (0.12.0), warm caches, the best of three runs:

| Document | Engine | Best render | Renders/s | Objects allocated | PDF bytes | Pages |
|---|---|---:|---:|---:|---:|---:|
| Invoice (`examples/invoice.rb`) | Stationery | 11.3 ms | 79.7 | 27,531 | 26,601 | 1 |
| | Prawn | 17.6 ms | 49.0 | 88,558 | 33,034 | 1 |
| | sghtmltopdf | 3.2 ms | 293.8 | 53 | 36,693 | 1 |
| Table, 1,500 rows × 5 columns, repeating header | Stationery | 205 ms | 4.46 | 1,276,408 | 133,756 | 46 |
| | Prawn | 1,299 ms | 0.74 | 6,901,819 | 2,689,487 | 40 |
| | sghtmltopdf | 94 ms | 10.05 | 53 | 369,338 | 45 |
| Cover photo and six illustrated sections | Stationery | 6.8 ms | 136.3 | 25,977 | 41,533 | 3 |
| | Prawn | 26.9 ms | 31.0 | 102,961 | 55,391 | 2 |
| | sghtmltopdf | 6.6 ms | 140.2 | 53 | 43,031 | 2 |

sghtmltopdf is the fastest on text and tables: 3.5x Stationery on the invoice and 2.2x on the
table, and level with it on the photo document (6.6 against 6.8 ms). That is native code against
Ruby, and its 53 objects are the binding's: the engine allocates outside the Ruby heap. Stationery
is 1.6x, 6.3x and 4.0x faster than Prawn and writes the smallest files of the three (28%, 64%
and 3% smaller than sghtmltopdf's). Stationery compresses content streams; Prawn does not by
default, hence its larger files. Against 0.11.0, the same three renders allocate 30% to 51% fewer
objects and take 14%, 48% and 24% less time. Page counts differ where the engines' line heights
and table padding do.
"Best render" is the fastest single render, the figure other work on the machine disturbs
least; renders per second is the average over five seconds.

What Stationery optimises for is not the last millisecond: it is pure Ruby with no native
extension to compile or precompile, its output is the same bytes on every platform, and the
PDF features (tagged output, PDF/A, forms, signatures) live in the same process as your
models. See the [comparison](https://stationery.zoolutions.llc/docs/comparison) for what
each engine does.

`PROFILE=1 bundle exec ruby -Ilib benchmark/profile.rb` prints the 20 hottest frames of the
table render under StackProf (wall mode; `MODE=cpu` or `MODE=object` for the others).
`SGHTMLTOPDF=0 bundle exec rake bench` leaves the third engine out, as does a machine
without its gem.

A lossless WebP is decoded in Ruby when it is first loaded, which a JPEG or an opaque PNG
(both passed through) never is: a 1000 × 1000 px image takes 0.2 to 0.4 s on the machine
above, by what is in it, and the image cache keeps it for the renders that follow. A JPEG is
decoded only for `to_png` or a monochrome render, once per process and scale: a 1000 × 1000
px photo in 0.25 s, a 12-megapixel phone photo in 2.8 s at full size and 0.7 s at the quarter
size a label or a preview needs (progressive: 3.4 s and 1.4 s; about four times as long
without YJIT).

Time depends on the machine, so CI holds what does not: `bundle exec rake metrics`
renders fourteen fixed documents and compares the objects each render allocates, its
page count and its bytes with `benchmark/baseline.json` (allocations may grow 3%,
bytes 1%, pages not at all). A change that moves them on purpose records a new
baseline with `bundle exec rake metrics:update` and says why in the commit.

| Document | What it holds |
|---|---|
| `invoice`, `flyer`, `form` | The examples of those names: a table with a footer, images and drawings, form fields |
| `table` | 1,500 rows × 5 columns with a repeating header, 46 pages |
| `text`, `text_hyphenated`, `text_streamed` | Ten pages of headings and paragraphs: as they are, justified and hyphenated, and written to a block |
| `article` | Floats: `examples/article.rb` |
| `newsletter` | `columns`: `examples/newsletter.rb` |
| `webp` | A lossless WebP of 320 × 240 px, decoded in the render that is measured |
| `html` | `html` with a stylesheet, inline styles, a floated image, a table, lists and two columns, five pages |
| `pdf_ua` | A tagged report under `conformance :pdf_ua1`, six pages |
| `text_incremental` | The text document with a footer, rendered with `incremental` to a block |
| `text_shaped` | The text document through a `shaper` written in Ruby, which answers the font's own glyphs |

`bundle exec rake memory` reports what long documents hold while they render
(`PAGES=5000` for more than its 1,000 pages): the peak resident set size of a render in
a fresh process, and what is alive when building, pagination and writing end. It
moves with the machine and gates nothing; the figures are under
[Large documents](#large-documents).

## Limitations

Fonts: no variable fonts (including CFF2) and no WOFF2 (it needs Brotli; convert to `.ttf` or
`.woff`); shaping stops at pair kerning and single or ligature substitutions (`liga` by default,
`smcp`, `onum`, `tnum`, `ss01`… on request), so contextual alternates (`calt`, `clig`, `frac`) do
nothing and scripts that need contextual shaping (Arabic, Indic, Thai) draw glyph by glyph unless the
application brings a shaper (`shaper`, see [the shaper hook](#complex-scripts-the-shaper-hook): the gem
shapes none of them itself), and colour or emoji glyphs no font
in the chain has are drawn as `.notdef` and reported (under a conformance level they raise, or are drawn
as a stand-in with `missing_glyphs: :replace`). Text runs left to right: a shaper orders the glyphs
within a stretch of one font and style, nothing reorders stretches or lines (CJK text wraps between
ideographs, but there is no vertical layout), and poppler and MuPDF extract shaped right-to-left text
reversed (see [the matrix](#complex-scripts-the-shaper-hook)); hyphenation
patterns are bundled for English, German and Swedish only (a soft hyphen works in any language),
and justification only widens spaces.

SVG covers the shapes, gradients, text, stylesheets, `use`/`symbol` sprites and clip paths that icon
sets and exports use, nothing else: `image`, `mask`, `pattern`, `filter` and `textPath` are skipped
and reported, text inside a `clipPath` does not clip, and the shapes of a clip path join into one
path, so overlapping shapes wound in opposite directions cancel where they overlap.
Images are JPEG, PNG (non-interlaced) and lossless WebP (not lossy or animated WebP, and no more
than 33 megapixels) and never fetched from a URL; a JPEG is embedded at its
source resolution (only PNG and WebP can be downscaled), so an oversized one is reported, not resized; a lossless, arithmetic-coded, hierarchical or 12-bit JPEG, or one of more than 33 megapixels, is not decoded for `to_png`, `to_zpl` or `monochrome`. `html` reads a fixed subset of CSS (colours, sizes, weights, alignment, margins, padding, table
borders and widths, page breaks; see [What CSS is read](#what-css-is-read)), not a layout
engine's worth: no `display`, positioning, `font-family`, `auto` or negative margins or selectors
with combinators, and floats for images only, with their `margin` around them.
`markdown` reads no CSS, and raw HTML inside Markdown stays literal text.

Layout: a box with a fixed `height:` never splits (use `min_height:` for a floor that can); a row
splits only when every column can; a rotated box and a `stack` move to the next page whole.
`columns` balances to the shortest height that holds the content and fills the columns evenly
from the first one on (ten lines in three columns are 4, 3 and 3): a column takes what fits the
height balanced for it and the columns after it, so one that ends above a block that cannot
split may stay shorter than the column after it. It has columns of one width, nothing spanning
them (end the block, write the full-width content, start another) and no column break of its
own; a spacer that lands at the top of a column keeps its height. Text
wraps around floated images and boxes, along their rectangles, never along a shape; the text
after floats cut by a page break goes to the next page with the float that moved, never beside
those that stayed; beside a float
a table, a row, `columns` and a box with a size of its own are blocks of the width that is left,
all the way down, where a box with a background wraps: a table resolves its column widths from
its width, a row shares its width between its columns and `columns` divides it, and none of them
can be laid out again at another width from some row on, which widening below the float would
take (see [Floats](#floats)). A table reads its rows as pages reach them only from an Enumerator
with a width for every column, and then refuses what needs its end (a row counted from the end, a
cell spanning rows); in a `row`, in a box with `break_inside: :avoid` or beside a float it is read
whole first (see [Large documents](#large-documents)). Link and form-widget rectangles stay in page space inside `rotate`
and `transform`, and `shadow:` is stacked rectangles, not a blur.

PDF: PDF/A-2b, PDF/A-3b and PDF/UA-1 only (no PDF/A-1, no level A or U, no PDF/UA-2, no PDF/X),
no JavaScript and no action but links and the print dialog (`print dialog: :on_open`). Under PDF/UA-1 a
link in the header row a table repeats on its next pages, and `canvas.link` without a `tag:`, raise: they
are outside the structure tree. A render carries one signature (`/ETSI.CAdES.detached`, RSA or EC with SHA-256):
no long-term validation data (PAdES B-LT), no second signature and no signing
of a file that already exists, all of which need incremental updates.
Form fields are set in the document's fonts, but text typed into one is drawn by the viewer:
characters outside the glyphs the field kept (ASCII and Latin-1) use the viewer's own font.

Pictures and labels: `to_png` and `to_zpl` draw no form fields (their widget is the viewer's), and
`to_zpl` sends each page as one graphic field, with only barcodes as the printer's own commands (no
`^GB` rules or boxes, no printer fonts). The labels were compared with `to_png` and rendered by a ZPL
viewer, not printed by the gem's specs.

## License

MIT. The PDF writer, TrueType subsetter and image decoders are derived from
the [receipts](https://github.com/excid3/receipts) gem (MIT).
