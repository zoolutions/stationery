# Changelog

## Unreleased

- SVG: path (every command, including arcs), rect, circle, ellipse, line, polyline, polygon and g, with fill, stroke, caps, joins, fill-rule, opacity, inline styles, transforms and `currentColor`. `svg` element.
- `wrap` element: children at their own widths, wrapping onto rows; splits between rows.
- `box(link:)` makes the whole box clickable; `box(outset:)` bleeds its background past its edges.
- `keep_with_next:` accepts a number of points of following content to keep.
- `group(align:)`.
- `Stationery::Warnings`: one collector per render, deduplicated, with `#message` on every entry (`Overflow`, `MissingGlyph`, `UnknownFamily`, `UnsupportedSvg`, `SkippedImage`, `UnresolvedLink`, `DuplicateAnchor`). `document.warnings` now includes warnings raised while page templates draw.
- Strict mode: `to_pdf(strict: true)` or class-level `strict` raises `Stationery::WarningsError` when a render produced warnings.
- Named anchors and internal links: `anchor:` on `text`, `box`, `group` and `table`, a standalone `anchor` element, and `link: "#name"` / `<a href="#name">` / `box(link: "#name")` written as PDF `/Dest` GoTo links. Unknown targets are dropped with an `UnresolvedLink` warning; duplicate names warn with `DuplicateAnchor`.
- Bookmarks and document outline: `bookmark:` on `text`, `box`, `group` and `table` (a title, or `{ title:, level:, open: }`) and a standalone `bookmark` element write a nested PDF `/Outlines` tree; the document opens with the outline panel. Bookmarks in page templates are ignored.
- SVG: elements that cannot be drawn (`text`, `use`, …) are listed in `SVG::Document#unsupported` and reported as an `UnsupportedSvg` warning.

## 0.1.0 (unreleased)

- PDF writer with Flate streams, per-page resources and link annotations.
- TrueType fonts: cmap 4/12, glyph subsetting, Type0/CIDFontType2 embedding with ToUnicode, synthetic bold and oblique.
- JPEG and PNG images, including alpha soft masks and palette transparency.
- Canvas: rectangles, rounded rectangles, circles, lines, Bézier paths, clipping, opacity, text runs, images, links.
- Text: inline markup, Ruby run builder, wrapping, alignment, leading, truncate and shrink-to-fit.
- Layout: flow, box, row/column, table, image, rule, spacer, page break, group, canvas escape hatch; pagination with header rows, keep-together and keep-with-next.
- Components with Phlex's lifecycle; documents with page settings, font families, default text, metadata and page templates.
- `Stationery::Rails#send_pdf`.
