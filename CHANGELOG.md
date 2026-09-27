# Changelog

## Unreleased

- SVG: path (every command, including arcs), rect, circle, ellipse, line, polyline, polygon and g, with fill, stroke, caps, joins, fill-rule, opacity, inline styles, transforms and `currentColor`. `svg` element.
- `wrap` element: children at their own widths, wrapping onto rows; splits between rows.
- `box(link:)` makes the whole box clickable; `box(outset:)` bleeds its background past its edges.
- `keep_with_next:` accepts a number of points of following content to keep.
- `group(align:)`.
- Fixed-width children of a flow (`box(width:)`) are measured, split and paginated at their own width, not the flow's.
- Layout: `split` takes `fresh:` on every node; a flow passes it on to the child that starts a fresh page.
- `ul` / `ol` / `li` lists: drawn (disc, circle, square) or text bullets (dash, any String), decimal / alpha / roman / Proc numbering, `start:` and `suffix:`, aligned bodies, nested lists with depth-cycled bullets, and items that split across pages keeping the marker with their first line.
||||||| 56fe3ff
- Inter (OFL) is bundled: documents render without any `font_family`; `font_family "Inter"` needs no paths; `Stationery.bundled_fonts`. An unknown family name without paths raises.
- Fixed: fonts without an OS/2 v2 table (including every subset) crashed on a nil cap height.
- `PDF::Writer` raises when a reserved object is never set instead of writing `null`.
- Gemspec ships every file under `lib/` and `exe/` when built without git, not only `.rb`.
- `stationery` executable with a command registry; `stationery render FILE [--out PATH|-] [--class NAME] [--strict] [--debug]` renders the Document a Ruby file defines (through `self.preview` when it needs arguments) and reports pages and bytes.
||||||| parent of c49dfa8 (fix(layout): lay out fixed-width flow children at their own width)
||||||| parent of c49dfa8 (fix(layout): lay out fixed-width flow children at their own width)
||||||| parent of f430413 (refactor(layout): split takes fresh: on every node)

## 0.1.0 (unreleased)

- PDF writer with Flate streams, per-page resources and link annotations.
- TrueType fonts: cmap 4/12, glyph subsetting, Type0/CIDFontType2 embedding with ToUnicode, synthetic bold and oblique.
- JPEG and PNG images, including alpha soft masks and palette transparency.
- Canvas: rectangles, rounded rectangles, circles, lines, Bézier paths, clipping, opacity, text runs, images, links.
- Text: inline markup, Ruby run builder, wrapping, alignment, leading, truncate and shrink-to-fit.
- Layout: flow, box, row/column, table, image, rule, spacer, page break, group, canvas escape hatch; pagination with header rows, keep-together and keep-with-next.
- Components with Phlex's lifecycle; documents with page settings, font families, default text, metadata and page templates.
- `Stationery::Rails#send_pdf`.
