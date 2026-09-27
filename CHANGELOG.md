# Changelog

## Unreleased

- SVG: path (every command, including arcs), rect, circle, ellipse, line, polyline, polygon and g, with fill, stroke, caps, joins, fill-rule, opacity, inline styles, transforms and `currentColor`. `svg` element.
- `wrap` element: children at their own widths, wrapping onto rows; splits between rows.
- `box(link:)` makes the whole box clickable; `box(outset:)` bleeds its background past its edges.
- `keep_with_next:` accepts a number of points of following content to keep.
- `group(align:)`.
- Pair kerning from the font's `kern` table, **on by default**: measured widths shift slightly (kerned
  lines only get narrower), so wrapping and right-aligned positions can move by a fraction of a point.
  `kerning: false` on `text`/`text_style` or in `default_text` restores unkerned output. Pairs across a
  style or font change are not kerned.
- GPOS pair kerning: the `kern` feature's PairPos lookups (formats 1 and 2, also behind Extension lookups)
  take precedence over the `kern` table, so GPOS-only fonts such as Inter are kerned too.
- OpenType fonts with CFF outlines (`.otf`), name-keyed and CID-keyed: embedded whole as a CIDFontType0
  (`FontFile3 /OpenType`), CID-keyed text written as CIDs with the font's ROS. Variable CFF2 fonts are rejected
  with a named reason.
- Internal: `Fonts::GlyphRun` carries per-glyph advance adjustments (Tj/TJ emission) for upcoming kerning and justification; output unchanged.

## 0.1.0 (unreleased)

- PDF writer with Flate streams, per-page resources and link annotations.
- TrueType fonts: cmap 4/12, glyph subsetting, Type0/CIDFontType2 embedding with ToUnicode, synthetic bold and oblique.
- JPEG and PNG images, including alpha soft masks and palette transparency.
- Canvas: rectangles, rounded rectangles, circles, lines, Bézier paths, clipping, opacity, text runs, images, links.
- Text: inline markup, Ruby run builder, wrapping, alignment, leading, truncate and shrink-to-fit.
- Layout: flow, box, row/column, table, image, rule, spacer, page break, group, canvas escape hatch; pagination with header rows, keep-together and keep-with-next.
- Components with Phlex's lifecycle; documents with page settings, font families, default text, metadata and page templates.
- `Stationery::Rails#send_pdf`.
