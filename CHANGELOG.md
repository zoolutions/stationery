# Changelog

## Unreleased

- SVG: path (every command, including arcs), rect, circle, ellipse, line, polyline, polygon and g, with fill, stroke, caps, joins, fill-rule, opacity, inline styles, transforms and `currentColor`. `svg` element.
- `wrap` element: children at their own widths, wrapping onto rows; splits between rows.
- `box(link:)` makes the whole box clickable; `box(outset:)` bleeds its background past its edges.
- `keep_with_next:` accepts a number of points of following content to keep.
- `group(align:)`.
- Rails: a Railtie adds `render pdf: document` (`filename:`, `disposition:`) and `config.stationery` (`renderer`, `font_paths`); `Stationery.font_paths`. A `spec:rails` lane tests it against Rails 8 without adding a dependency.
- Rails: PDF previews like ActionMailer previews. `Stationery::Preview` subclasses in `spec/pdfs/previews` or `test/pdfs/previews` render at `/rails/stationery/previews` (`?debug=1` when the document supports it); `config.stationery.preview_paths` and `show_previews` (development by default). `rake spec:rails` no longer overwrites the main suite's coverage report.

## 0.1.0 (unreleased)

- PDF writer with Flate streams, per-page resources and link annotations.
- TrueType fonts: cmap 4/12, glyph subsetting, Type0/CIDFontType2 embedding with ToUnicode, synthetic bold and oblique.
- JPEG and PNG images, including alpha soft masks and palette transparency.
- Canvas: rectangles, rounded rectangles, circles, lines, Bézier paths, clipping, opacity, text runs, images, links.
- Text: inline markup, Ruby run builder, wrapping, alignment, leading, truncate and shrink-to-fit.
- Layout: flow, box, row/column, table, image, rule, spacer, page break, group, canvas escape hatch; pagination with header rows, keep-together and keep-with-next.
- Components with Phlex's lifecycle; documents with page settings, font families, default text, metadata and page templates.
- `Stationery::Rails#send_pdf`.
