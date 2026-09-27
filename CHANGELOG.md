# Changelog

## Unreleased

- SVG: path (every command, including arcs), rect, circle, ellipse, line, polyline, polygon and g, with fill, stroke, caps, joins, fill-rule, opacity, inline styles, transforms and `currentColor`. `svg` element.
- `wrap` element: children at their own widths, wrapping onto rows; splits between rows.
- `box(link:)` makes the whole box clickable; `box(outset:)` bleeds its background past its edges.
- `keep_with_next:` accepts a number of points of following content to keep.
- `group(align:)`.
- Fixed-width children of a flow (`box(width:)`) are measured, split and paginated at their own width, not the flow's.
- Layout: `split` takes `fresh:` on every node; a flow passes it on to the child that starts a fresh page.
- **Behaviour change:** boxes taller than a page now continue on the next page instead of overflowing; pass `break_inside: :avoid` for the old behaviour. A box that fits on a page still moves there whole; `break_inside: :auto` splits it at any page break. `box(decoration: :slice | :clone)` chooses whether padding repeats at a cut; borders are left open and rounded corners cut square.
- `box(break_inside:)` and `column(break_inside:)`.
- Rows split across pages like boxes, every column at the same break; a column that ends early continues as an empty fragment so backgrounds stay aligned. `row(break_inside:)`.
- `keep_with_next` now moves with a following node that avoids breaking inside and would not start on the page.

## 0.1.0 (unreleased)

- PDF writer with Flate streams, per-page resources and link annotations.
- TrueType fonts: cmap 4/12, glyph subsetting, Type0/CIDFontType2 embedding with ToUnicode, synthetic bold and oblique.
- JPEG and PNG images, including alpha soft masks and palette transparency.
- Canvas: rectangles, rounded rectangles, circles, lines, Bézier paths, clipping, opacity, text runs, images, links.
- Text: inline markup, Ruby run builder, wrapping, alignment, leading, truncate and shrink-to-fit.
- Layout: flow, box, row/column, table, image, rule, spacer, page break, group, canvas escape hatch; pagination with header rows, keep-together and keep-with-next.
- Components with Phlex's lifecycle; documents with page settings, font families, default text, metadata and page templates.
- `Stationery::Rails#send_pdf`.
