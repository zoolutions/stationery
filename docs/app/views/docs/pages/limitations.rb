# frozen_string_literal: true

class Views::Docs::Pages::Limitations < DocsUI::Page
  title "Limitations"
  eyebrow "Reference"

  def lead = "What stationery deliberately does not do (yet)."

  def content
    DocsUI::Section("Known limitations", description: "From the README.") do
      md SourceMarkdown.readme_section("Limitations")
    end

    DocsUI::Section("In detail") do
      md <<~'MD'
        | Area | Not supported | What you see |
        | --- | --- | --- |
        | Fonts | Variable fonts (including CFF2) and WOFF2 | `UnsupportedFont` naming the reason (`variable CFF2 fonts are not supported`, `WOFF2 needs Brotli; convert to .ttf or .woff`) |
        | Shaping | GSUB beyond standard `liga` ligatures: no contextual or discretionary ligatures, no complex-script shaping (Arabic joining, Indic reordering, Thai marks), no vertical text, no right-to-left runs | Glyphs drawn one by one, left to right |
        | Glyphs | Colour glyph layers (COLR draws its monochrome outline) and any character no font in the chain has, emoji included | `.notdef` box plus a `MissingGlyph` warning; Unicode whitespace draws as a blank instead. A bitmap-only emoji font (no `glyf`/`CFF` outlines) is rejected with `UnsupportedFont` |
        | Text | Hyphenation, small caps and other OpenType features, text wrapping around images | Lines break at spaces and after hyphens; `justify` widens spaces only |
        | SVG | `use`, `image`, `clipPath`, `mask`, `pattern`, `filter`, `textPath`, `symbol`; stylesheet selectors with combinators (`g path`, `a > b`) | Skipped and listed in an `UnsupportedSvg` warning |
        | SVG (approximated) | Gradient `reflect`/`repeat` spreads (drawn as `pad`), per-stop opacity (the first stop's), gradient strokes (the middle colour), rotated or skewed text (upright, uniformly scaled), `dominant-baseline` | Reported in `UnsupportedSvg` where it changes the drawing |
        | Images | GIF, WebP, TIFF, BMP, interlaced PNG; remote URLs; resampling (an image is embedded at its source resolution) | `UnsupportedImage` naming the format; `html`/`markdown` skip a remote or unreadable image with a `SkippedImage` warning |
        | HTML / Markdown | CSS beyond `text-align` and inline `font-weight`/`font-style` (no colours, sizes, classes), `script`/`style`/`iframe`/`video`, task lists, footnotes, math; raw HTML inside Markdown | Unknown elements render their text; raw HTML in Markdown stays literal |
        | Layout | A fixed `height:` box, a rotated box and a `stack` never split; a row splits only when every column can; no balanced columns | The node moves to the next page whole; taller than a page it is placed anyway and reported as an `Overflow` warning |
        | Transforms | Annotations inside `rotate`/`transform` | Link and form-widget rectangles stay in untransformed page space |
        | Shadows | Blur | `shadow:` is stacked rounded rectangles at fading opacity, which reads as a soft shadow in print |
        | PDF features | PDF/UA labelling (no XMP `pdfuaid`), PDF/A, PDF/X, digital signing (`signature_field` is an empty `/Sig` field), embedded files, JavaScript and actions, page labels | Not written |
        | Forms | Field appearances in the document's fonts | Widgets draw with Helvetica and ZapfDingbats in Windows-1252, so text outside Latin-1 shows as `?` until the viewer regenerates the appearance |

        Anything the engine skips at render time is reported in `document.warnings` rather than dropped
        silently — see [Warnings and strict mode](/docs/warnings).
      MD
    end

    DocsUI::Section("Sizing images", description: "Embedded at source resolution.") do
      md <<~'MD'
        A JPEG is embedded byte for byte and a PNG is re-encoded losslessly, so a 1600 px photo
        drawn 160 pt wide ships all 1600 px at 720 ppi. Size images before you embed them: for print,
        `width_in_points / 72 * 300` pixels is plenty (a 160 pt photo needs about 670 px), and screen
        PDFs need half that. With ActiveStorage, make a variant per drawn size (`resize_to_limit`,
        JPEG, quality 75) and preprocess it, so a render only downloads. A 10-page flyer with 18
        photos went from 3.3 MB to under 1 MB that way with no visible difference.
      MD
    end
  end
end
