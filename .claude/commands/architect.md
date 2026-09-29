---
description: "Coordinates a change across Stationery's layers. Use when a feature spans the DSL, layout, text and the outputs, to order the work and find the integration points."
model: opus
argument-hint: "feature or task to coordinate"
---

# Architect: work across the layers

A feature in Stationery usually reaches from the DSL a document class writes down to the bytes of every output. Done in the wrong order, the lower layer is designed around the upper one's guess.

## The layers (bottom up)

```
0  Measurement     lib/stationery/fonts/, text/, hyphenation, shaper.rb, units.rb
1  Canvas          lib/stationery/canvas/interface.rb: the only surface a node draws on
2  Outputs         lib/stationery/pdf/ (writer, conformance, signature, Factur-X), raster/ (to_png), svg/, zpl/
3  Layout          lib/stationery/layout/ (nodes, paginator, table, columns), page/, regions, page_templates
4  Structure       lib/stationery/tagging/, structure.rb, outline.rb
5  DSL             document.rb, elements/, component.rb, builder.rb, rich/, markdown/, html/, css/, forms/
6  Around it       cli/, rails/, testing/ (matchers, inspector), skill/, examples/, README, docs/
```

## Order

1. Measurement and the canvas first, if they change; `Canvas::Interface` grows only when every output can honour it.
2. Outputs: PDF, then the raster, SVG and ZPL canvases, since `spec/stationery/document_paint_on_spec.rb` paints every example on a canvas that is not the PDF one.
3. Layout, then structure (tags follow what layout placed), then the DSL.
4. Then the example, the testing matchers a user needs to assert on it, the README and the docs page, the `## Unreleased` bullet.

Specs first at every layer.

## Integration points

| When touching | Also check |
|---|---|
| A layout node | That it draws only through `Canvas::Interface`; pagination and `break_inside`; `to_pdf(debug: true)` |
| Text or fonts | Wrapping and hyphenation; missing glyphs under PDF/A (`missing_glyphs: :replace`); the metrics gate |
| Tagging | PDF/UA and PDF/A with `rake verify:conformance`; the new tagged example joins its `renders` |
| The PDF writer | Bytes of documents that do not use the feature; signatures (`rake verify:signature`); Factur-X |
| The DSL | Class-level vs render-level options, inheritance into subclasses, `Warnings` rather than exceptions |
| `html` / `css` | What is unsupported is reported as `Warnings::UnsupportedCss`, not laid out approximately |

## Never

A runtime dependency or native code; a CSS layout engine; shaping or bidi in the gem (the `shaper` hook exists); a node reaching for PDF internals; a feature that costs anything where it is not used.

## Before the pull request

Run the `fable-validator` agent on the combined diff first; do not open or merge on BLOCK.

The checks are `AGENTS.md`'s: `bundle exec rspec`, `bundle exec rubocop lib spec examples Rakefile`, `bundle exec rake metrics`, `rake verify:conformance` for tagging, and the changed renders looked at as PNGs.

## Handoff

The plan in layer order, the files per layer, the integration points found, and the decisions made (consult the advisor on any public API).
