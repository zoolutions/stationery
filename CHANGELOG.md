# Changelog

## Unreleased

- Tagged (accessible) PDF: `tagged` at class level or `to_pdf(tagged: true)` writes a structure tree (`/StructTreeRoot` with a `/ParentTree`, `/MarkInfo`, `/StructParents` on pages) and marks every painted leaf as marked content (`/P <</MCID n>> BDC … EMC`). Text is `P`, or `H1`–`H6` with `text(…, heading: 1..6)`; images and SVG drawings are `Figure` with `/Alt` from `alt:` (`alt: false`: decorative) and a `/BBox`; `box(role: :section | :div | :blockquote | :note | :caption | :article | :part)` groups its content. A node split across pages stays one element with marked content on each page. Headers, footers and page templates are `/Pagination` artifacts, other decoration is a layout artifact. `metadata lang:` writes `/Lang` (and is kept out of the document info); a tagged document with a title sets `/DisplayDocTitle`. New warnings `MissingAlt` and `MissingLanguage` let `strict` catch accessibility gaps. Untagged output is byte-for-byte unchanged. `Canvas#tag`, `#structure` and `#artifact`, `Stationery::Tagging::{Tree, Element, Writer}`.
- Tagged PDF structure for lists (`L` with `/ListNumbering` > `LI` > `Lbl` + `LBody`; drawn bullets are artifacts), tables (`Table` > `TR` > `TH` with `/Scope /Column` or `TD`, `/ColSpan`/`/RowSpan` attributes; one `Table` across pages, repeated header rows as artifacts), links (linked text is a `Link` inside its paragraph with the annotation's `/OBJR`; annotations get `/StructParent`; `box(link:)` groups its content in a `Link`) and `table_of_contents` (`TOC` > `TOCI` > `Link` + `Reference`). `html`/`markdown` tag headings `H1`–`H6` and block quotes. `Canvas#tag_runs`, `Canvas#link(…, tag:)`, `Layout::Flow.new(…, tag:)`, `Tagging::Element.new(…, attributes:)`.
- Testing tagged PDFs: `Inspector#structure` reads the structure tree as nested arrays with each element's text taken from its marked content (`[[:Document, [[:H1, "Intro"], [:P, ["Read", [:Link, "the docs"], "now"]]]]]`), `Inspector#tagged?` and `#untagged_text`; matchers `have_structure` and `have_tagged_content`, assertions `assert_pdf_structure` and `assert_tagged_content`. `examples/report.rb` is tagged, with headings and a decorative icon. Empty table cells stay in the tree.

## 0.3.0 (2026-09-27)

The Limitations page, shortened: TrueType collections, WOFF, ligatures, splittable
`min_height:` boxes, SVG gradients, text and stylesheets, and encryption.

- SVG: `linearGradient` and `radialGradient` fills (`fill="url(#id)"`, also in `style`), with stops, `href`/`xlink:href` inheritance, `objectBoundingBox` and `userSpaceOnUse` units and `gradientTransform`, drawn as PDF axial/radial shadings clipped to the shape. Approximations: `reflect`/`repeat` spreads are drawn as `pad` (reported in `unsupported`), stop opacity is the first stop's for the whole gradient, and a gradient stroke is drawn in the gradient's middle colour. A reference to a missing gradient paints its fallback colour or nothing and is reported as `url(#id)`. `Canvas#shade` paints a shading dictionary inside a path.
- SVG: `text` and `tspan` (`x`/`y`/`dx`/`dy`, first value each; `font-family`, first family the font book knows — registered, bundled or an installed pack — else the document's default; `font-size`, `font-weight`, `font-style`, `text-anchor`, `fill`, `opacity`, transforms), drawn through the document's fonts so they subset and extract like any text. Whitespace collapses as in browsers. Glyphs stay upright: a transform moves the baseline origin and scales the size uniformly, so rotated or skewed text is approximated; `dominant-baseline` is ignored and a gradient fill uses its middle colour. `Layout::Svg` takes `context:`, `SVG::Document#draw` takes `book:` and `family:`, and `FontBook#known?` tells whether a family resolves without substitution.
- SVG: `<style>` stylesheets (plain or CDATA) as Illustrator and Inkscape export them. Selectors: element, `.class` (`.a.b`), `#id`, `element.class`, comma lists and `*`; rules with combinators (`g path`, `a > b`, …) are ignored and reported once as `style selectors: …`. Cascade: presentation attributes, then rules by specificity (id > class > element, later wins on ties), then inline `style`. Rules style shapes, text (`font-*`) and gradient stops (`stop-color`, `stop-opacity`); `display: none` skips an element and its children, `visibility: hidden` skips it (a `visible` child draws). `class` takes several classes.

- Encryption with the standard security handler: `to_pdf(encrypt: { owner_password:, user_password:, permissions:, algorithm: })` or `encrypt …` at class level (`to_pdf(encrypt: nil)` opts out). AES-256 (R6, default), AES-128 (R4) and RC4-128 (R3); every string and stream, document info included, is encrypted.

- Standard ligatures from the font's GSUB `liga` feature (LigatureSubst lookups, also behind Extension lookups), **on by default**: "office" in Open Sans draws the ffi ligature, so widths of affected words change slightly. `ligatures: false` on `text`/`text_style` or in `default_text` opts out; any `letter_spacing` turns them off. Text extraction and copy still yield the source characters (ToUnicode maps a ligature glyph to all of them). Fonts without `liga` ligatures, such as the bundled Inter, are unaffected.

### Fonts

- TrueType collections (`.ttc`): `font_family "Brand", regular: "Brand.ttc#0", bold: "Brand.ttc#2"` picks a face by a `#N` suffix (face 0 without one); each face is parsed, cached, subset and embedded on its own. `TrueType.new(data, index:)`, `TrueType.collection?` and `TrueType.faces`; an index out of range raises `ArgumentError` naming the face count.
- WOFF 1.0 web fonts (`.woff`): `font_family "Web", regular: "Brand.woff"`. Tables are inflated with zlib into an in-memory sfnt (`Fonts::WOFF.unpack`), then measured, subset and embedded like the `.ttf`. WOFF2 is still rejected: it needs Brotli, so convert to `.ttf` or `.woff`.

- `box(min_height:)` and `column(min_height:)`: a height floor that, unlike `height:`, still splits across pages. The first fragment keeps as much of the floor as the page holds and the next carries the rest, so a row of equal-height cards or an empty signature area can span a page break. Passing both `height:` and `min_height:` raises `ArgumentError`.

## 0.2.0 (2026-09-27)

Everything from the three planned milestones ("works out of the box", "typography and layout",
"documents, Rails and testing") shipped together.

### Breaking changes

- **Behaviour change:** boxes taller than a page now continue on the next page instead of overflowing; pass `break_inside: :avoid` for the old behaviour. A box that fits on a page still moves there whole; `break_inside: :auto` splits it at any page break. `box(decoration: :slice | :clone)` chooses whether padding repeats at a cut; borders are left open and rounded corners cut square.
- Pair kerning from the font's `kern` table, **on by default**: measured widths shift slightly (kerned lines only get narrower), so wrapping and right-aligned positions can move by a fraction of a point. `kerning: false` on `text`/`text_style` or in `default_text` restores unkerned output. Pairs across a style or font change are not kerned.

### Fonts

- Inter (OFL) is bundled: documents render without any `font_family`; `font_family "Inter"` needs no paths; `Stationery.bundled_fonts`. An unknown family name without paths raises.
- Font packs: `stationery fonts list` and `stationery fonts install noto_sans liberation_serif [--into DIR] [--force] [--from PATH]` copy pinned, SHA-256-verified Noto Sans/Serif/Sans Mono, Liberation Sans/Serif/Mono and Inter files (plus their OFL license) into `vendor/fonts/<pack>/`, atomically and offline-capable. `font_family "Noto Sans"` with no paths finds an installed pack through `Stationery.font_paths`, as does an unregistered family name at render time. Ruby API `Stationery::Fonts.install`/`catalog`/`paths`, Rails generator `stationery:fonts`, and `rake fonts:verify`. No runtime downloads.
- Per-character font fallback: `font_fallbacks "Noto Sans Symbols", ...` (inherited by subclasses). A character missing from the text's family is drawn from the first fallback that has it, then bundled Inter; spaces, joiners and combining marks stay with their base. Glyphs no font has are reported as `MissingGlyph` warnings counted per drawn occurrence. `Font#glyph?` is memoised per character.
- GPOS pair kerning: the `kern` feature's PairPos lookups (formats 1 and 2, also behind Extension lookups) take precedence over the `kern` table, so GPOS-only fonts such as Inter are kerned too.
- OpenType fonts with CFF outlines (`.otf`), name-keyed and CID-keyed: embedded whole as a CIDFontType0 (`FontFile3 /OpenType`), CID-keyed text written as CIDs with the font's ROS. Variable CFF2 fonts are rejected with a named reason.
- CFF fonts are subset: undrawn glyphs become a bare `endchar` (glyph ids, charset, FDSelect, Private DICTs and Subrs kept), embedded as `FontFile3 /CIDFontType0C` with a subset tag.

### Text

- `align: :justify` on `text`, `text_style` and table cells: wrapped lines are stretched to the full width by widening their spaces (kerning is kept); the last line, lines ending in a newline and lines without spaces stay left-aligned. Link areas widen with the stretched text.
- `html` and `markdown` elements: ActionText/Trix HTML and CommonMark (GFM tables and strikethrough) rendered as paragraphs, headings, lists, blockquotes, code blocks, rules, tables and images with inline bold/italic/underline/strike/code/links/sub/sup. `styles:` deep-merges per-block defaults, `images:` resolves image sources (or `base_path:`), missing/remote images are skipped with a `SkippedImage` warning and never fetched, `bookmarks: true` outlines h1–h3. Parsers load on first use.
- Markup decodes all 252 HTML 4 named entities (`&mdash;`, `&euro;`, `&hellip;`, …); the table loads on first use.
- Internal: `Stationery::Rich` block model (paragraphs, headings, lists, quotes, code, rules, tables, images; inlines with marks) with lenient `HTML.parse` (implied end tags, browser whitespace collapsing, Trix/ActionText output) and CommonMark-subset `Markdown.parse` (GFM tables and strikethrough, reference links). Loaded on demand; `html`/`markdown` elements follow.
- Internal: `Fonts::GlyphRun` carries per-glyph advance adjustments (Tj/TJ emission) for upcoming kerning and justification; output unchanged.

### Layout

- `ul` / `ol` / `li` lists: drawn (disc, circle, square) or text bullets (dash, any String), decimal / alpha / roman / Proc numbering, `start:` and `suffix:`, aligned bodies, nested lists with depth-cycled bullets, and items that split across pages keeping the marker with their first line.
- `box(break_inside:)` and `column(break_inside:)`.
- Rows split across pages like boxes, every column at the same break; a column that ends early continues as an empty fragment so backgrounds stay aligned. `row(break_inside:)`.
- `keep_with_next` now moves with a following node that avoids breaking inside and would not start on the page.
- `wrap` element: children at their own widths, wrapping onto rows; splits between rows.
- `box(link:)` makes the whole box clickable; `box(outset:)` bleeds its background past its edges.
- `keep_with_next:` accepts a number of points of following content to keep.
- `group(align:)`.
- Fixed-width children of a flow (`box(width:)`) are measured, split and paginated at their own width, not the flow's.
- Layout: `split` takes `fresh:` on every node; a flow passes it on to the child that starts a fresh page.

### Tables

- Table cells span columns and rows: `{ content:, colspan:, rowspan: }`, placed as in HTML; a table only splits between rows no rowspan crosses.
- A table row taller than the page continues on the next page below the repeated header, its cells cut at the page bottom; `table(split_rows: true)` cuts any row that reaches the page bottom rather than moving it whole.
- Table cells accept procs built with the DSL (`-> { image logo }`) and components.
- Faster tables: cell padding is normalised once per cell, and PDF numbers are trimmed without a regexp (about 13% off a 1,500-row table render).

### Pages and structure

- `header` and `footer` regions that reserve page space, with `height:`, `gap:` and `on:` (`:all`, `:first`, `:rest`, `:odd`, `:even`, a page number, a range or a proc); later declarations win. A `page_template`'s `page.content_box` now excludes their space. `Page#margin_box`.
- `header`/`footer` `on: :last`: the paginator checks whether the rest of the content fits above a taller last-page region, adding a page when it only fits a normal one.
- Named anchors and internal links: `anchor:` on `text`, `box`, `group` and `table`, a standalone `anchor` element, and `link: "#name"` / `<a href="#name">` / `box(link: "#name")` written as PDF `/Dest` GoTo links. Unknown targets are dropped with an `UnresolvedLink` warning; duplicate names warn with `DuplicateAnchor`.
- Bookmarks and document outline: `bookmark:` on `text`, `box`, `group` and `table` (a title, or `{ title:, level:, open: }`) and a standalone `bookmark` element write a nested PDF `/Outlines` tree; the document opens with the outline panel. Bookmarks in page templates are ignored.
- `table_of_contents` element: one linked row per bookmark with its title indented by level, a dotted/solid leader and a right-aligned page number filled in after pagination (`levels:`, `leader:`, `indent:`, `gap:`, `number_width:`, text style). Paginates across pages.

### Drawing

- SVG: path (every command, including arcs), rect, circle, ellipse, line, polyline, polygon and g, with fill, stroke, caps, joins, fill-rule, opacity, inline styles, transforms and `currentColor`. `svg` element.
- SVG: elements that cannot be drawn (`text`, `use`, …) are listed in `SVG::Document#unsupported` and reported as an `UnsupportedSvg` warning.
- Canvas: `rounded_rect` and `clip` take per-corner radii (`[top_left, top_right, bottom_right, bottom_left]`, scaled down to fit like CSS); `rounded_rect(dash:)`.
- `to_pdf(debug: true)` outlines every layout rectangle (boxes, padding, columns, flow slots, cells, positioned boxes, images, the page content box), colour-coded by kind; `debug: %i[cell …]` outlines only those kinds.

### Warnings

- An unregistered family name draws with the first registered family (else bundled Inter) and reports an `UnknownFamily` warning once.
- `Stationery::Warnings`: one collector per render, deduplicated, with `#message` on every entry (`Overflow`, `MissingGlyph`, `UnknownFamily`, `UnsupportedSvg`, `SkippedImage`, `UnresolvedLink`, `DuplicateAnchor`). `document.warnings` now includes warnings raised while page templates draw.
- Strict mode: `to_pdf(strict: true)` or class-level `strict` raises `Stationery::WarningsError` when a render produced warnings.

### Rails

- Rails: a Railtie adds `render pdf: document` (`filename:`, `disposition:`) and `config.stationery` (`renderer`, `font_paths`); `Stationery.font_paths`. A `spec:rails` lane tests it against Rails 8 without adding a dependency.
- Rails: PDF previews like ActionMailer previews. `Stationery::Preview` subclasses in `spec/pdfs/previews` or `test/pdfs/previews` render at `/rails/stationery/previews` (`?debug=1` when the document supports it); `config.stationery.preview_paths` and `show_previews` (development by default). `rake spec:rails` no longer overwrites the main suite's coverage report.

### Tooling

- Documentation site at https://stationery.zoolutions.llc, a docs-kit app under `docs/` (not part of the gem): getting started, every element with its options, layout rules, pages and regions, links and bookmarks, fonts, images and SVG, Rails, testing, the CLI, warnings, a cookbook built from `examples/`, performance, limitations and this changelog, rendered from the README and CHANGELOG where they overlap.
- `stationery` executable with a command registry; `stationery render FILE [--out PATH|-] [--class NAME] [--strict] [--debug]` renders the Document a Ruby file defines (through `self.preview` when it needs arguments) and reports pages and bytes.
- `require "stationery/rspec"` matchers (`have_pdf_text`, `have_pdf_text_on_page`, `have_page_count`, `have_pdf_link`, `have_image_count`, `have_bookmark`, `have_no_warnings`) and `require "stationery/minitest"` assertions, built on `Stationery::Testing::Inspector`. Needs `pdf-reader` in the test group.
- Examples: `examples/report.rb` (multi-page annual report: header/footer regions, contents, bookmarks, lists, tables, a split callout, internal links, SVG icons), `examples/letter.rb` (one-page letter with a vector letterhead) and `examples/packing_slip.rb` (landscape, 120-row table with split rows, canvas barcode), each covered by an integration spec and rendered in CI by `rake examples`.
- `rake bench`: reproducible benchmarks against Prawn + prawn-table (one-page invoice, 1,500-row table) and a StackProf profile script under `benchmark/`.

### Performance

- Layout caches: container nodes (box, row, flow, wrap, list item) memoise their height per width; table cells remember their height per width and their natural and minimum widths across the fragments of a split table; tables memoise row heights and column metrics; table row boundaries are found in one pass. Fonts memoise style resolution and advance/kerning totals per string, and runs already split for fallback are not split again. Output is byte-identical. A 1,500-row table renders ~26x faster (17.9 s → 0.68 s, 186M → 4.5M allocations), the invoice example 1.3x faster (77k → 33k allocations).
- `benchmark/profile.rb` profiles in wall mode by default (`MODE=cpu|object`).

### Fixes

- Fixed: table cells restyled through a selection after the table had been measured kept their old style.
- Fixed: fonts without an OS/2 v2 table (including every subset) crashed on a nil cap height.
- `PDF::Writer` raises when a reserved object is never set instead of writing `null`.
- Gemspec ships every file under `lib/` and `exe/` when built without git, not only `.rb`.

## 0.1.0 (2026-09-26)

- PDF writer with Flate streams, per-page resources and link annotations.
- TrueType fonts: cmap 4/12, glyph subsetting, Type0/CIDFontType2 embedding with ToUnicode, synthetic bold and oblique.
- JPEG and PNG images, including alpha soft masks and palette transparency.
- Canvas: rectangles, rounded rectangles, circles, lines, Bézier paths, clipping, opacity, text runs, images, links.
- Text: inline markup, Ruby run builder, wrapping, alignment, leading, truncate and shrink-to-fit.
- Layout: flow, box, row/column, table, image, rule, spacer, page break, group, canvas escape hatch; pagination with header rows, keep-together and keep-with-next.
- Components with Phlex's lifecycle; documents with page settings, font families, default text, metadata and page templates.
- `Stationery::Rails#send_pdf`.
