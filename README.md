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
| `text(string, markup: true)` | Reads `<b> <i> <u> <strikethrough> <sub> <sup> <br> <color rgb=""> <font size="" name=""> <link href="">`. |
| `text { b "Total"; plain " due" }` | Styled runs in Ruby. Take a block argument (`{ \|t\| t.b @x }`) to keep your own `self`. |
| `box(padding:, background:, border:, radius:, width:, height:, overflow:, at:, link:, outset:, break_inside:, decoration:) { }` | A container. Moves to the next page whole when it fits there and continues across pages when it does not; `break_inside: :auto` splits it at any page break, `:avoid` never splits it. At a cut, `decoration: :slice` (default) drops the padding and border, `:clone` keeps the padding. `overflow: :truncate` or `:shrink_to_fit` for fixed heights. `at: [x, y]` pins it to a page position. `link:` makes the whole box clickable. `outset:` bleeds the background past the box (e.g. into the page margins). |
| `row(gap:, align:) { column(width:) { } }` | Columns side by side. `width:` is points, a fraction (`0.5`), `:auto` or `nil` (equal share). |
| `table(rows, widths:, width:, header:, cell:) { \|t\| }` | Tables. Style with `t.row(0)`, `t.rows(-1)`, `t.column(1)`, `t.columns(1..)`, chained, plus `t.zebra`. Header rows repeat after a page break. |
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
`letter_spacing`, `underline`, `strikethrough`, `link`, `opacity`, `align`, `leading`.
Colours are `"#RRGGBB"`, `"RRGGBB"`, `"#RGB"`, `[r, g, b]` (0-255) or `[c, m, y, k]` (0-100).

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
- Content taller than a page is placed anyway; `document.warnings` lists every overflow.

## Rails

```ruby
require "stationery/rails" # adds send_pdf to controllers

def show = send_pdf(InvoicePdf.new(@invoice), filename: "invoice.pdf")
```

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

Fonts are TrueType (`.ttf`) files. Only the glyphs a document uses are
embedded, with a ToUnicode map so text copies and searches correctly. A style
without its own file (bold, italic) is synthesised.

Inter (regular, bold, italic, bold italic; SIL Open Font License) is bundled
and used when a document declares no family. `font_family "Inter"` with no
paths selects it explicitly, and `Stationery.bundled_fonts` lists what ships.
Font files are read lazily, on first use, never when the gem is required.

Images are JPEG (grey, RGB, CMYK) and PNG (every colour type, alpha as a soft
mask). Parsed fonts and images are cached per process.

## Why not Prawn, Chrome or Typst?

- **Prawn** is an imperative cursor API: every document does its own layout
  arithmetic. Stationery is a layout engine with a component DSL.
- **Headless Chrome** (Grover, ferrum_pdf) renders HTML beautifully but runs
  a browser per worker; stray processes and memory are the price.
- **Typst** is excellent but a native extension and a second template language.

## Limitations

No kerning or ligatures, no OpenType/CFF, TrueType collections, variable
fonts or WOFF; no full justification; SVG covers the shapes icon sets use
(no text, gradients, patterns, masks or CSS stylesheets); no encryption,
outlines, forms or tagged PDF; rows do not split across pages; fixed-height
boxes never split.

## License

MIT. The PDF writer, TrueType subsetter and image decoders are derived from
the [receipts](https://github.com/excid3/receipts) gem (MIT).
