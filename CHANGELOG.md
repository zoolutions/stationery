# Changelog

## 0.1.0 (unreleased)

- PDF writer with Flate streams, per-page resources and link annotations.
- TrueType fonts: cmap 4/12, glyph subsetting, Type0/CIDFontType2 embedding with ToUnicode, synthetic bold and oblique.
- JPEG and PNG images, including alpha soft masks and palette transparency.
- Canvas: rectangles, rounded rectangles, circles, lines, Bézier paths, clipping, opacity, text runs, images, links.
- Text: inline markup, Ruby run builder, wrapping, alignment, leading, truncate and shrink-to-fit.
- Layout: flow, box, row/column, table, image, rule, spacer, page break, group, canvas escape hatch; pagination with header rows, keep-together and keep-with-next.
- Components with Phlex's lifecycle; documents with page settings, font families, default text, metadata and page templates.
- `Stationery::Rails#send_pdf`.
