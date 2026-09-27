# Stationery

Pure-Ruby PDF documents built from Phlex-style components. Describe the page
with rows, columns, boxes, tables, text and images; a box-layout engine
measures, places and paginates them; a small PDF writer embeds subsetted
TrueType fonts and JPEG/PNG images.

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
  font_family "Inter", regular: "fonts/Inter-Regular.ttf", bold: "fonts/Inter-Bold.ttf"
  default_text font: "Inter", size: 9, color: "#1F2937"
  metadata title: "Invoice"

  page_template do |page|
    box(at: [44, page.height - 34], width: page.content_box.width) do
      text "Page #{page.number} of #{page.count}", size: 7, align: :right
    end
  end

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

`examples/invoice.rb` is a complete, runnable invoice: `ruby -Ilib examples/invoice.rb`.

## Elements

| Element | What it does |
|---|---|
| `text(string, **style)` | A paragraph. Plain strings are literal. |
| `text(string, markup: true)` | Reads `<b> <i> <u> <strikethrough> <sub> <sup> <br> <color rgb=""> <font size="" name=""> <link href="">`; decodes numeric and HTML 4 named entities. |
| `text { b "Total"; plain " due" }` | Styled runs in Ruby. Take a block argument (`{ \|t\| t.b @x }`) to keep your own `self`. |
| `box(padding:, background:, border:, radius:, width:, height:, overflow:, at:, link:, outset:, break_inside:, decoration:) { }` | A container. Moves to the next page whole when it fits there and continues across pages when it does not; `break_inside: :auto` splits it at any page break, `:avoid` never splits it. At a cut, `decoration: :slice` (default) drops the padding and border, `:clone` keeps the padding. `overflow: :truncate` or `:shrink_to_fit` for fixed heights. `at: [x, y]` pins it to a page position. `link:` makes the whole box clickable. `outset:` bleeds the background past the box (e.g. into the page margins). |
| `row(gap:, align:, break_inside:) { column(width:) { } }` | Columns side by side. `width:` is points, a fraction (`0.5`), `:auto` or `nil` (equal share). Splits across pages like a box, every column at once; a row with a fixed-height column never splits. |
| `table(rows, widths:, width:, header:, split_rows:, cell:) { \|t\| }` | Tables. Cells are strings, layout nodes, procs built with the DSL (`-> { image logo }`) or components. Style with `t.row(0)`, `t.rows(-1)`, `t.column(1)`, `t.columns(1..)`, chained, plus `t.zebra`. Header rows repeat after a page break. A cell may be `{ content:, colspan:, rowspan: }` plus any cell option; rows list only the cells they start, as in HTML, and pages never break through a rowspan. Spans are set in the rows, not through selections. A row taller than the page continues on the next page, cut through its cells, with the header repeated; `split_rows: true` cuts any row that reaches the page bottom instead of moving it whole. |
| `image(path_or_io, width:, height:, fit:, align:)` | JPEG or PNG, aspect preserved. |
| `svg(source_or_path, width:, height:, color:, align:)` | Vector icons and drawings; `currentColor` takes `color:`. |
| `wrap(gap:, row_gap:, align:) { }` | Children side by side at their own widths, wrapping onto new rows (chips, tags). |
| `ul(style:, gap:, indent:, marker_gap:, marker_color:) { li "…" }` | Bulleted list. `style:` is `:disc`, `:circle`, `:square`, `:dash` or any String; unstyled nested lists cycle disc → circle → square. Any node added inside (not only `li`) becomes an item. Items split across pages; the marker stays with the first line. |
| `ol(format:, start:, suffix:, gap:, indent:, marker_gap:, marker_color:) { }` | Numbered list. `format:` is `:decimal`, `:alpha`, `:upper_alpha`, `:roman`, `:upper_roman` or a Proc `(n) -> String`; `suffix:` defaults to `"."`. Markers right-align so bodies line up. |
| `li(string, **style)`, `li(gap:) { }` | A list item: a paragraph, or a block of any elements (including nested lists). |
| `rule(height:, color:)`, `spacer(height)`, `page_break` | Dividers and spacing. |
| `group(keep_together: true, align:) { }` | Keep a block on one page. |
| `keep_with_next: true \| points` | On `text`, `box` or `group`: never end a page with this node; with a number, keep at least that many points of what follows with it. |
| `text_style(**style) { }` | Default text style for a block. |
| `canvas(height:) { \|canvas, rect\| }` | Draw directly: rectangles, rounded rectangles, circles, lines, Bézier paths, clipping, images, links. |

Text style options: `font`, `size`, `weight` (`:regular`, `:bold`), `style` (`:italic`), `color`,
`letter_spacing`, `underline`, `strikethrough`, `link`, `opacity`, `kerning` (default `true`), `align` (`:left`, `:center`, `:right`, `:justify`), `leading`.
`align: :justify` stretches the spaces of wrapped lines to the full width; the last line, lines
ending in a newline and lines without spaces stay left-aligned (tabs are never stretched).
Colours are `"#RRGGBB"`, `"RRGGBB"`, `"#RGB"`, `[r, g, b]` (0-255) or `[c, m, y, k]` (0-100).

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
- Content taller than a page is placed anyway; `document.warnings` lists every overflow.
- After `to_pdf`, `document.warnings` is an Enumerable of everything the render noticed but did not
  raise on, each with a `#message`: overflows, SVG elements that were skipped (`UnsupportedSvg`), and
  the other `Stationery::Warnings::*` kinds (missing glyphs, unknown font families, skipped images,
  unresolved links, duplicate anchors). Equal warnings are listed once; warnings from page templates
  are included. `to_pdf(strict: true)`, or `strict` at class level, raises `Stationery::WarningsError`
  (with `#warnings`) instead of writing a PDF that produced any; `to_pdf(strict: false)` opts one
  render out again.

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

The gem has no Rails dependency; the Railtie loads only inside a Rails app.

## CLI

```sh
stationery render app/pdfs/invoice_pdf.rb                # writes app/pdfs/invoice_pdf.pdf
stationery render invoice.rb --out - > invoice.pdf       # PDF to stdout
stationery render pdfs.rb --class InvoicePdf --strict    # pick one; fail on layout warnings
```

`render` loads the file and renders the `Stationery::Document` it defines. A
document whose `initialize` needs arguments renders from `def self.preview`,
which returns an instance built with sample data. Layout warnings print to
stderr; `--strict` exits 1 instead of writing. `stationery help` lists the
commands.

## Fonts and images

Fonts are TrueType (`.ttf`) or OpenType/CFF (`.otf`, name-keyed or
CID-keyed) files. Only the glyphs a document uses are embedded (a CFF font
keeps its glyph numbering and subroutines; unused glyphs are blanked), with a
ToUnicode map so text copies and searches correctly. A style without its own
file (bold, italic) is synthesised.

Inter (regular, bold, italic, bold italic; SIL Open Font License) is bundled
and used when a document declares no family. `font_family "Inter"` with no
paths selects it explicitly, and `Stationery.bundled_fonts` lists what ships.
Font files are read lazily, on first use, never when the gem is required.

Text is pair-kerned from the font's GPOS `kern` feature (PairPos lookups,
including class-based pairs and Extension lookups), falling back to the
legacy `kern` table (`kerning: false` on an element or in `default_text`
turns it off). Pairs that straddle a style or
font change are not kerned. Kerning only tightens in practice, so a kerned
line is never wider than the same line unkerned.

Images are JPEG (grey, RGB, CMYK) and PNG (every colour type, alpha as a soft
mask). Parsed fonts and images are cached per process.

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
  it { is_expected.to have_page_count(2) }
  it { is_expected.to have_pdf_link("mailto:hello@acme.test") }
  it { is_expected.to have_image_count(1) }
  it { is_expected.to have_no_warnings }
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
    assert_page_count pdf, 2
    assert_pdf_link pdf, /acme\.test/
    assert_no_pdf_warnings pdf
  end
end
```

The matcher names carry a `pdf_` prefix so they never clash with Capybara's
`have_text` and `have_link`. `have_bookmark` / `assert_bookmark` match outline
titles. For anything else, `Stationery::Testing::Inspector.new(subject)`
exposes `text`, `page_texts`, `page_count`, `links`, `internal_links`,
`image_count`, `bookmarks`, `metadata` and `warnings`.

## Why not Prawn, Chrome or Typst?

- **Prawn** is an imperative cursor API: every document does its own layout
  arithmetic. Stationery is a layout engine with a component DSL.
- **Headless Chrome** (Grover, ferrum_pdf) renders HTML beautifully but runs
  a browser per worker; stray processes and memory are the price.
- **Typst** is excellent but a native extension and a second template language.

## Limitations

No ligatures, no TrueType collections, variable fonts (including CFF2) or
WOFF; SVG covers the shapes icon sets use
(no text, gradients, patterns, masks or CSS stylesheets); no encryption,
outlines, forms or tagged PDF; fixed-height boxes, and rows holding one,
never split across pages.

## License

MIT. The PDF writer, TrueType subsetter and image decoders are derived from
the [receipts](https://github.com/excid3/receipts) gem (MIT).
