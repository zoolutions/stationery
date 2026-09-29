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
        | Shaping | GSUB beyond single and ligature substitutions: no contextual alternates (`calt`, `clig`, `frac`), no complex-script shaping (Arabic joining, Indic reordering, Thai marks), no vertical text, no right-to-left runs, unless the application brings a [`shaper`](/docs/fonts#complex-scripts) | Glyphs drawn one by one, left to right; a contextual feature in `features:` does nothing. With a shaper, nothing reorders stretches or lines, and poppler and MuPDF extract right-to-left text reversed |
        | Glyphs | Colour glyph layers (COLR draws its monochrome outline) and any character no font in the chain has, emoji included | `.notdef` box plus a `MissingGlyph` warning; Unicode whitespace draws as a blank instead. Under a conformance level it raises `ConformanceError`, or with `missing_glyphs: :replace` draws U+FFFD, U+25A1 or `?` as a stand-in. A bitmap-only emoji font (no `glyf`/`CFF` outlines) is rejected with `UnsupportedFont` |
        | Text | Hyphenation patterns for languages other than English, German and Swedish (a soft hyphen works everywhere), text wrapping along a shape (it wraps around the rectangle of a [float](/docs/elements#floats)), vertical text | Lines break at spaces, after hyphens, at hyphenation points, at zero-width spaces and between CJK characters (kinsoku respected); `justify` widens spaces only |
        | SVG | `image`, `mask`, `pattern`, `filter`, `textPath`; text inside a `clipPath`; stylesheet selectors with combinators (`g path`, `a > b`) | Skipped and listed in an `UnsupportedSvg` warning, as are a `use` or a `clip-path` whose target is missing |
        | SVG (approximated) | Gradient `reflect`/`repeat` spreads (drawn as `pad`), per-stop opacity (the first stop's), gradient strokes (the middle colour), rotated or skewed text (upright, uniformly scaled), `dominant-baseline` | Reported in `UnsupportedSvg` where it changes the drawing |
        | SVG (clip paths) | The union of a clip path's shapes as separate regions | The shapes join into one clipping path, so overlapping shapes wound in opposite directions cancel where they overlap |
        | Images | GIF, lossy and animated WebP, TIFF, BMP, interlaced PNG; remote URLs; JPEG resampling (a JPEG is embedded at its source resolution, only a PNG or a lossless WebP can be downscaled) | `UnsupportedImage` naming the format; an image drawn at more than twice `max_ppi` is reported as `OversizedImage`; `html`/`markdown` skip a remote or unreadable image with a `SkippedImage` warning |
        | Images (decoded) | Lossless, arithmetic-coded, hierarchical and 12-bit JPEGs, and JPEGs of more than 33 megapixels, for `to_png`, `to_zpl` and `monochrome`; the EXIF orientation | A PDF embeds them as it does every JPEG; `to_png` draws a crossed box with a `SkippedImage`, a monochrome PDF embeds it as it is with a `NotMonochrome` |
        | Pictures and labels | Form fields in `to_png` and `to_zpl`; ZPL rules, boxes and printer fonts | Fields draw nothing (their widget is the viewer's); a ZPL label is one graphic field per page, with only barcodes written as the printer's own `^BC`, `^BE`, `^BQ` and `^BX`. Labels are checked against `to_png` and a ZPL viewer, not printed by the specs |
        | HTML / Markdown | CSS outside the [subset `html` reads](/docs/elements#html-and-markdown): `display`, `float` on anything but `img`, positioning, `font-family`, `line-height`, `auto` and negative margins, inline backgrounds, selectors with combinators or pseudo-classes; `script`/`iframe`/`video`, task lists, footnotes, math; raw HTML inside Markdown | Unread styles are named in an `UnsupportedCss` warning; unknown elements render their text; raw HTML in Markdown stays literal |
        | Nesting | HTML elements or Markdown block quotes and lists nested deeper than `max_depth:` (64), more than 12 levels of indented block quotes and lists, SVG elements nested deeper than 128, a chain of more than 32 `use`s | Flattened into the deepest level kept, text and shapes included, and reported as a `NestingLimit` warning (the `use` chain in `UnsupportedSvg`) |
        | Layout | A fixed `height:` box, a rotated box and a `stack` never split; a row splits only when every column can; `columns` has columns of one width, nothing spanning them and no column break of its own, and fills balanced columns evenly from the first one on, so a column that ends above a block that cannot split may stay shorter than the one after it | The node moves to the next page whole; taller than a page it is placed anyway and reported as an `Overflow` warning |
        | Tables | Reading rows as pages reach them from an Array, or from an Enumerator with a column without a width; a row counted from the end (`t.row(-1)`) or a cell spanning rows in a streamed table | Such a table reads every row when it is built. In a [streamed table](/docs/performance#large-documents) a selection from the end, a cell spanning rows and a row with more columns than widths raise `ArgumentError`; in a `row`, a box with `break_inside: :avoid` or beside a float it is read whole |
        | Floats | Text beside the floats a page break left behind | Floats taller than a page together are cut before the first that does not fit, and the text after them goes to the next page with it |
        | Floats | Content that widens below a [float](/docs/elements#floats) in a `table`, a `row`, `columns` or a box with a size of its own | They are blocks of the width the float leaves, all the way down: a table resolves its column widths from its width, a row shares its width between its columns and `columns` divides it, and none can be laid out again at another width from some row on. Text, list items and boxes, with a background or without, wrap |
        | Transforms | Annotations inside `rotate`/`transform` | Link and form-widget rectangles stay in untransformed page space |
        | Shadows | Blur | `shadow:` is stacked rounded rectangles at fading opacity, which reads as a soft shadow in print |
        | PDF features | PDF/X, JavaScript and actions other than links and the print dialog | Not written |
        | Signatures | Long-term validation data (LTV, PAdES B-LT and B-LTA), a second signature, signing a file that already exists; keys other than RSA and EC | A render carries one [signature](/docs/conformance#digital-signatures) over the whole file; the rest needs incremental updates, which are not written. Another key type raises `ArgumentError` |
        | Conformance | PDF/A-1, PDF/A levels A and U, PDF/UA-2; CMYK colour and CMYK JPEGs in a conforming document | Only [PDF/A-2b, PDF/A-3b and PDF/UA-1](/docs/conformance) are claimed; CMYK is a `ConformanceIssue` warning |
        | PDF/UA-1 links | A link in the header row a table repeats on its next pages, and `canvas.link` without a `tag:` | Outside the structure tree: `ConformanceError` under PDF/UA-1, an `UntaggedLink` warning in a tagged render. Links of the body, headers, footers and page templates are tagged |
        | Forms | Glyphs for text typed into a field beyond printable ASCII and Latin-1 (and a select's options) | The value a field is rendered with is drawn in the document's fonts, whatever its script; what a reader types outside the kept glyphs is drawn by the viewer in a font of its own |

        Anything the engine skips at render time is reported in `document.warnings` rather than dropped
        silently — see [Warnings and strict mode](/docs/warnings).
      MD
    end

    DocsUI::Section("Sizing images", description: "JPEGs are embedded as they are.") do
      md <<~'MD'
        A JPEG is embedded byte for byte (a `monochrome` render dithers it instead), so size it before
        you embed it: for print,
        `width_in_points / 72 * 300` pixels is plenty (a 160 pt photo needs about 670 px), and screen
        PDFs need half that. An image drawn at more than twice `max_ppi` is reported as an
        `OversizedImage`, and a PNG or a lossless WebP can be resampled with `downscale: true` — see
        [Resolution](/docs/images-and-svg#resolution).
      MD
    end
  end
end
