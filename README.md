# Stationery

Pure-Ruby PDF documents built from Phlex-style components. Describe the page
with rows, columns, boxes, tables, text and images; a box-layout engine
measures, places and paginates them; a small PDF writer embeds subsetted
TrueType and OpenType fonts, JPEG/PNG images and SVG drawings.

**Documentation: [stationery.zoolutions.llc](https://stationery.zoolutions.llc)**

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

`examples/` has a complete, runnable invoice, annual report, letter, packing slip, fillable form, postcard collage, event flyer and Factur-X e-invoice
([previews and live PDFs](https://stationery.zoolutions.llc/docs/examples)); `bundle exec rake examples`
renders them all, or render one with `stationery render examples/report.rb`.

## Elements

| Element | What it does |
|---|---|
| `text(string, **style)` | A paragraph. Plain strings are literal. |
| `text(string, markup: true)` | Reads `<b> <i> <u> <strikethrough> <sub> <sup> <br> <color rgb=""> <font size="" name=""> <link href="">`; decodes numeric (`&#39;`, `&#x27;`) and HTML 4 named entities once, so escape user data (`ERB::Util.html_escape`) before wrapping it in your own tags: `&lt;b&gt;` stays literal text. |
| `text { b "Total"; plain " due" }` | Styled runs in Ruby. Take a block argument (`{ \|t\| t.b @x }`) to keep your own `self`. |
| `box(padding:, background:, border:, radius:, width:, height:, min_height:, overflow:, at:, link:, outset:, break_inside:, decoration:, rotate:, shadow:) { }` | A container. Moves to the next page whole when it fits there and continues across pages when it does not; `break_inside: :auto` splits it at any page break, `:avoid` never splits it. At a cut, `decoration: :slice` (default) drops the padding and border, `:clone` keeps the padding. `overflow: :truncate` or `:shrink_to_fit` for fixed heights; a fixed `height:` never splits. `min_height:` is a floor that still splits: the first fragment keeps as much of it as the page holds, the next carries the rest (not combinable with `height:`). `at: [x, y]` pins it to a page position. `link:` makes the whole box clickable. `outset:` bleeds the background past the box (e.g. into the page margins). `rotate: -3` turns the painted box around its centre (layout box unchanged, never splits; a `link:` keeps its unrotated rectangle). `shadow: true` or `{ offset: [0, 4], blur: 8, color:, opacity: 0.15 }` paints a soft drop shadow under it, taking no space. `overflow: :hidden` clips the content to the rounded outline. |
| `row(gap:, align:, break_inside:) { column(width:) { } }` | Columns side by side. `width:` is points, a fraction (`0.5`), `:auto` or `nil` (equal share). Splits across pages like a box, every column at once; a row with a fixed-height column never splits; columns with `min_height:` do. |
| `table(rows, widths:, width:, header:, split_rows:, cell:) { \|t\| }` | Tables. Cells are strings, layout nodes, procs built with the DSL (`-> { image logo }`) or components. Style with `t.row(0)`, `t.rows(-1)`, `t.column(1)`, `t.columns(1..)`, chained, plus `t.zebra`. Header rows repeat after a page break. A cell may be `{ content:, colspan:, rowspan: }` plus any cell option; rows list only the cells they start, as in HTML, and pages never break through a rowspan. Spans are set in the rows, not through selections. A row taller than the page continues on the next page, cut through its cells, with the header repeated; `split_rows: true` cuts any row that reaches the page bottom instead of moving it whole. |
| `image(path_or_io, width:, height:, fit:, align:, radius:, rotate:, max_ppi:, downscale:)` | JPEG or PNG, aspect preserved. `fit: [w, h]` scales to fit inside; `fit: :cover` fills `width:` × `height:` and crops around the centre. `radius:` rounds the corners; `rotate:` turns it (degrees, clockwise) without changing the space it takes. Drawn at more than twice `max_ppi:` (300) it is reported as oversized; `downscale: true` resamples a PNG to that resolution instead. |
| `svg(source_or_path, width:, height:, color:, align:)` | Vector icons and drawings; `currentColor` takes `color:` (or the `color` an element sets). Linear and radial gradients (`fill="url(#id)"`, `href` chains, both gradient units); `text`/`tspan` in the document's fonts; `<style>` stylesheets (element, class, id and `*` selectors); `use`, `symbol` sprites and nested `svg` viewports (`viewBox`, `preserveAspectRatio`); `clipPath` (both `clipPathUnits`). |
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
| `html(source, styles:, gap:, images:, base_path:, bookmarks:, links:, max_depth:)` | Rich text from HTML (ActionText/Trix, CMS output): paragraphs, headings, lists, quotes, code, rules, tables, images, inline marks and links. See [HTML and Markdown](#html-and-markdown). |
| `markdown(source, styles:, gap:, images:, base_path:, bookmarks:, links:, max_depth:)` | The same from CommonMark (plus GFM tables and strikethrough). |

Text style options: `font`, `size`, `weight` (`:regular`, `:bold`), `style` (`:italic`), `color`,
`letter_spacing`, `underline`, `strikethrough`, `link`, `opacity`, `kerning` (default `true`), `ligatures` (default `true`), `features` (OpenType feature tags, e.g. `%i[smcp onum]`), `hyphenate` (`true` for English, or `"de"`, `"sv"`; default off), `align` (`:left`, `:center`, `:right`, `:justify`), `leading`,
`orphans` and `widows` (the fewest lines a page break may leave behind and carry over; default 1, a paragraph that cannot meet them moves whole).
`align: :justify` stretches the spaces of wrapped lines to the full width; the last line, lines
ending in a newline and lines without spaces stay left-aligned (tabs are never stretched).
Colours are `"#RRGGBB"`, `"RRGGBB"`, `"#RGB"`, `[r, g, b]` (0-255) or `[c, m, y, k]` (0-100).

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
  `ul` and `format:`/`suffix:` for `ol`), `li` (text style) and `img` (`max_width:`).
- Links are written only for `http`, `https`, `mailto` and `tel` hrefs (and `#anchor`); anything
  else (`javascript:`, `data:`, a relative path) keeps its text without a link and is reported as a
  `DroppedLink` warning. `links: %w[http https]` changes the list, `links: :all` keeps every href
  from a trusted source.
- `gap:` spaces the blocks (default 6); `bookmarks: true` adds h1–h3 to the PDF outline.
- `max_depth:` (default 64) is how deep the source may nest: HTML elements inside one another,
  or Markdown block quotes and lists. What lies deeper is flattened into the deepest element
  kept, so its text stays and its structure goes, and a `NestingLimit` warning says how deep the
  source went. Block quotes and lists also stop indenting after twelve levels, where they would
  leave their text no width; that is reported the same way.

#### Untrusted input

`html` and `markdown` are meant for content you did not write (a CMS body, a comment, an
ActionText field), and nothing in that content can reach outside the document or take the
process down:

- **No requests.** Remote images are never fetched; an image is read only from `images:` or from
  under `base_path:`, and a path that climbs out of it is skipped (`SkippedImage`).
- **No surprising links.** Only `http`, `https`, `mailto` and `tel` hrefs (and `#anchor`) become
  links (`DroppedLink` for the rest), so a `javascript:` or `file:` href is plain text.
- **No scripts or styles.** `script`, `style`, `template` and `title` content is dropped, raw HTML
  inside Markdown stays literal text, and no CSS is evaluated beyond `text-align` and inline
  bold and italic.
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
  Unicode). Check marks and radio dots are paths. `NeedAppearances` is set too, so viewers redraw
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
- `page_labels 1 => { style: :roman_lower }, 3 => { style: :decimal, start: 1, prefix: "A-" }` names
  the pages the way viewers show them ("i", "ii", "A-1", …): a 1-based first page mapped to the range
  that starts there, with `style:` `:decimal`, `:roman`, `:roman_lower`, `:alpha`, `:alpha_lower` or
  `nil` (prefix only), `start:` and `prefix:`. `to_pdf(page_labels:)` overrides it for one render.
- Content taller than a page is placed anyway; `document.warnings` lists every overflow.
- After `to_pdf`, `document.warnings` is an Enumerable of everything the render noticed but did not
  raise on, each with a `#message`: overflows, SVG elements that were skipped (`UnsupportedSvg`), and
  the other `Stationery::Warnings::*` kinds (missing glyphs, unknown font families, skipped images,
  unresolved links, duplicate anchors). Equal warnings are listed once; warnings from page templates
  are included. `to_pdf(strict: true)`, or `strict` at class level, raises `Stationery::WarningsError`
  (with `#warnings`) instead of writing a PDF that produced any; `to_pdf(strict: false)` opts one
  render out again.

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
  `BlockQuote`, and give images their `alt`.
- Headers, footers and page templates are pagination artifacts; backgrounds, borders and rules drawn
  outside any element are layout artifacts.
- `metadata lang:` writes the catalog's `/Lang`; the title is shown instead of the file name.
- Every document carries an XMP packet (`/Metadata`, uncompressed) mirroring the Info dictionary:
  `dc:title`, `dc:creator`, `dc:description`, `dc:subject`, `dc:language`, the `xmp:` dates and
  `pdf:Producer`. PDF/A and PDF/UA identification lives there (see
  [PDF/A and PDF/UA](#pdfa-and-pdfua)); `metadata xmp: false` or `to_pdf(xmp: false)` leaves it out.
- An image or drawing without `alt:` (`Warnings::MissingAlt`) and a missing `lang`
  (`Warnings::MissingLanguage`) are warnings, so `strict` catches them.
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
  `alt:` raises; mark decoration with `alt: false`. Encryption is allowed.
- Combined, the XMP packet also describes the `pdfuaid` schema to PDF/A (`pdfaExtension:schemas`).
- Interactive form fields are allowed: their appearances draw with embedded fonts and paths, every
  field has a `/TU`, and `NeedAppearances` and ZapfDingbats are left out. Only a field made without
  a font book (`Forms::Field.new` placed with `canvas.widget`) raises, since it draws with the
  standard Helvetica.
- Without `conformance` nothing changes: the output is byte for byte what it was.

`bundle exec rake verify:conformance` renders `examples/invoice.rb` as PDF/A-3b, and
`examples/report.rb` and `examples/form.rb` as PDF/A-3b plus PDF/UA-1, and validates them with
[veraPDF](https://verapdf.org) through Docker (`verapdf/cli`); CI runs it on every push. Validate
your own documents the same way:

```sh
docker run --rm -v "$PWD:/data:ro" verapdf/cli --format text -v --flavour 3b /data/invoice.pdf
```

In tests, `have_conformance(:pdf_a3b)` checks the claim (not the validity: that is veraPDF's job).

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
       reason: "Approved", location: "Malmö", contact: "legal@acme.test"
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
- The file is written once, with `contents_size:` bytes (8192) kept free for the signature, which
  is then filled in place. A long certificate chain may need more; a signature that does not fit
  raises and says so.
- A signed form asks viewers not to regenerate appearances (`NeedAppearances` is left out) and
  sets `/SigFlags 3`. `encrypt:` and `conformance` combine with `sign`: the signature is the one
  string encryption leaves in the clear, and a signed PDF/A-3b or PDF/UA-1 file still validates.
- Not covered: signature timestamps (PAdES-T) and long-term validation data (LTV), a second
  signature, and signing a file that already exists. All of them need incremental updates;
  Stationery signs what it renders, once. Whether a viewer trusts the signer is decided by the
  certificate and the viewer's trust list, not by the file.

`bundle exec rake verify:signature` signs `examples/invoice.rb` with a throwaway certificate and
verifies it with `openssl cms -verify` and, when poppler is installed, `pdfsig`;
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
```

`render` loads the file and renders the `Stationery::Document` it defines. A
document whose `initialize` needs arguments renders from `def self.preview`,
which returns an instance built with sample data. Layout warnings print to
stderr; `--strict` exits 1 instead of writing. `stationery help` lists the
commands.

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
on it). Fallback covers every text element,
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

Images are JPEG (grey, RGB, CMYK) and PNG (every colour type, alpha as a soft
mask). Parsed fonts and images are cached per process.

A bitmap keeps its pixels, so a 1600 px photo drawn 160 pt wide ships all
1600 px at 720 ppi. An image drawn at more than twice the document's
`max_ppi` (300, or `images max_ppi: 220` at class level, `nil` to switch the
check off) is reported as a `Warnings::OversizedImage` naming the file, its
pixel width and the resolution it lands at. `images downscale: true` (or
`image(..., downscale: true)`) resamples a PNG to `max_ppi` at its drawn size
before embedding it, alpha included; a JPEG is embedded byte for byte, so
resize it before you embed it (an ActiveStorage variant per drawn size,
preprocessed, keeps a render to a download).

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
  it { is_expected.to have_pdf_language("en") } # the catalog /Lang from `metadata lang:`
  it { is_expected.to have_page_labels(%w[i ii 1 2]) } # from `page_labels`
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
    assert_page_count pdf, 2
    assert_pdf_link pdf, /acme\.test/
    assert_no_pdf_warnings pdf
    assert_pdf_language pdf, "en"
    assert_page_labels pdf, %w[i ii 1 2]
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
`lang`, `page_labels`, `attachments`, `conformance` (`[:pdf_a3b, :pdf_ua1]`), `factur_x`
(`{ profile:, filename:, version:, xml: }`), `signatures` (`[{ field:, name:, reason:, location:,
signed_at:, subfilter:, byte_range:, signer:, valid: }]`), `warnings`, `tagged?`,
`untagged_text` and
`structure` — a tagged PDF's structure tree as nested arrays, each element's text
read from its marked content: `[type, "text"]`, `[type, [children]]` (its own text
between the children, as for a `P` holding a `Link`) or `[type]` when empty; a
`Figure` reads as its alt text.

## Why not Prawn, Chrome or Typst?

- **Prawn** is an imperative cursor API: every document does its own layout
  arithmetic. Stationery is a layout engine with a component DSL.
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

`bundle exec rake bench` renders two documents with Stationery and with Prawn
2.5 + prawn-table, both embedding the same Open Sans TTF files
(`benchmark/`, not part of CI). Apple M2 Max, Ruby 3.4.2 +YJIT, 28 September 2026:

| Document | Engine | Renders/s | Objects allocated | PDF bytes |
|---|---|---:|---:|---:|
| Invoice (1 page, `examples/invoice.rb`) | Stationery | 66.5 | 39,574 | 26,599 |
| | Prawn | 41.3 (1.61x slower) | 88,558 | 33,034 |
| Table, 1,500 rows × 5 columns, repeating header | Stationery | 2.31 (46 pages) | 2,596,554 | 133,754 |
| | Prawn | 0.58 (40 pages; 4.01x slower) | 6,901,811 | 2,689,487 |

Stationery compresses content streams; Prawn does not by default, hence the
larger file. `PROFILE=1 bundle exec ruby -Ilib benchmark/profile.rb` prints the
20 hottest frames of the table render under StackProf (wall mode; `MODE=cpu` or
`MODE=object` for the others).

Time depends on the machine, so CI holds what does not: `bundle exec rake metrics`
renders six fixed documents and compares the objects each render allocates, its
page count and its bytes with `benchmark/baseline.json` (allocations may grow 3%,
bytes 1%, pages not at all). A change that moves them on purpose records a new
baseline with `bundle exec rake metrics:update` and says why in the commit.

## Limitations

Fonts: no variable fonts (including CFF2) and no WOFF2 (it needs Brotli; convert to `.ttf` or
`.woff`); shaping stops at pair kerning and single or ligature substitutions (`liga` by default,
`smcp`, `onum`, `tnum`, `ss01`… on request), so contextual alternates (`calt`, `clig`, `frac`) do
nothing and scripts that need contextual shaping (Arabic, Indic, Thai) draw glyph by glyph, and colour or emoji glyphs no font
in the chain has are drawn as `.notdef` and reported. Text runs left to right (CJK text wraps between
ideographs, but there is no vertical layout); hyphenation
patterns are bundled for English, German and Swedish only (a soft hyphen works in any language),
and justification only widens spaces.

SVG covers the shapes, gradients, text, stylesheets, `use`/`symbol` sprites and clip paths that icon
sets and exports use, nothing else: `image`, `mask`, `pattern`, `filter` and `textPath` are skipped
and reported, text inside a `clipPath` does not clip, and the shapes of a clip path join into one
path, so overlapping shapes wound in opposite directions cancel where they overlap.
Images are JPEG and PNG (non-interlaced) and never fetched from a URL; a JPEG is embedded at its
source resolution (only PNGs can be downscaled), so an oversized one is reported, not resized. `html` and `markdown` render structure and inline marks, not CSS: only `text-align`
and inline `font-weight`/`font-style` are read, and raw HTML inside Markdown stays literal text.

Layout: a box with a fixed `height:` never splits (use `min_height:` for a floor that can); a row
splits only when every column can; a rotated box and a `stack` move to the next page whole. Text
does not wrap around images. Link and form-widget rectangles stay in page space inside `rotate`
and `transform`, and `shadow:` is stacked rectangles, not a blur.

PDF: PDF/A-2b, PDF/A-3b and PDF/UA-1 only (no PDF/A-1, no level A or U, no PDF/UA-2, no PDF/X) and
no JavaScript. A render carries one signature (`/ETSI.CAdES.detached`, RSA or EC with SHA-256):
no signature timestamp (PAdES-T) or long-term validation data, no second signature and no signing
of a file that already exists, all of which need incremental updates.
Form fields are set in the document's fonts, but text typed into one is drawn by the viewer:
characters outside the glyphs the field kept (ASCII and Latin-1) use the viewer's own font.

## License

MIT. The PDF writer, TrueType subsetter and image decoders are derived from
the [receipts](https://github.com/excid3/receipts) gem (MIT).
