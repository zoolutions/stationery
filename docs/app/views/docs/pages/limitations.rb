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
        | Shaping | GSUB beyond single and ligature substitutions: no contextual alternates (`calt`, `clig`, `frac`), no complex-script shaping (Arabic joining, Indic reordering, Thai marks), no vertical text, no right-to-left runs | Glyphs drawn one by one, left to right; a contextual feature in `features:` does nothing |
        | Glyphs | Colour glyph layers (COLR draws its monochrome outline) and any character no font in the chain has, emoji included | `.notdef` box plus a `MissingGlyph` warning; Unicode whitespace draws as a blank instead. A bitmap-only emoji font (no `glyf`/`CFF` outlines) is rejected with `UnsupportedFont` |
        | Text | Hyphenation patterns for languages other than English, German and Swedish (a soft hyphen works everywhere), text wrapping along a shape (it wraps around the rectangle of a [float](/docs/elements#floats)), vertical text | Lines break at spaces, after hyphens, at hyphenation points, at zero-width spaces and between CJK characters (kinsoku respected); `justify` widens spaces only |
        | SVG | `image`, `mask`, `pattern`, `filter`, `textPath`; text inside a `clipPath`; stylesheet selectors with combinators (`g path`, `a > b`) | Skipped and listed in an `UnsupportedSvg` warning, as are a `use` or a `clip-path` whose target is missing |
        | SVG (approximated) | Gradient `reflect`/`repeat` spreads (drawn as `pad`), per-stop opacity (the first stop's), gradient strokes (the middle colour), rotated or skewed text (upright, uniformly scaled), `dominant-baseline` | Reported in `UnsupportedSvg` where it changes the drawing |
        | SVG (clip paths) | The union of a clip path's shapes as separate regions | The shapes join into one clipping path, so overlapping shapes wound in opposite directions cancel where they overlap |
        | Images | GIF, lossy and animated WebP, TIFF, BMP, interlaced PNG; remote URLs; JPEG resampling (a JPEG is embedded at its source resolution, only a PNG or a lossless WebP can be downscaled) | `UnsupportedImage` naming the format; an image drawn at more than twice `max_ppi` is reported as `OversizedImage`; `html`/`markdown` skip a remote or unreadable image with a `SkippedImage` warning |
        | HTML / Markdown | CSS outside the [subset `html` reads](/docs/elements#html-and-markdown): `display`, `float` on anything but `img`, positioning, `font-family`, `line-height`, `auto` and negative margins, inline backgrounds, selectors with combinators or pseudo-classes; `script`/`iframe`/`video`, task lists, footnotes, math; raw HTML inside Markdown | Unread styles are named in an `UnsupportedCss` warning; unknown elements render their text; raw HTML in Markdown stays literal |
        | Nesting | HTML elements or Markdown block quotes and lists nested deeper than `max_depth:` (64), more than 12 levels of indented block quotes and lists, SVG elements nested deeper than 128, a chain of more than 32 `use`s | Flattened into the deepest level kept, text and shapes included, and reported as a `NestingLimit` warning (the `use` chain in `UnsupportedSvg`) |
        | Layout | A fixed `height:` box, a rotated box and a `stack` never split; a row splits only when every column can; `columns` has columns of one width, nothing spanning them and no column break of its own, and fills balanced columns evenly from the first one on, so a column that ends above a block that cannot split may stay shorter than the one after it | The node moves to the next page whole; taller than a page it is placed anyway and reported as an `Overflow` warning |
        | Floats | Text beside the floats a page break left behind | Floats taller than a page together are cut before the first that does not fit, and the text after them goes to the next page with it |
        | Floats | Content that widens below a [float](/docs/elements#floats) in a `table`, a `row`, `columns` or a box with a background, a border, a shadow, a link or a size of its own | They are blocks of the width the float leaves, all the way down; text, list items and boxes that paint nothing of their own wrap |
        | Transforms | Annotations inside `rotate`/`transform` | Link and form-widget rectangles stay in untransformed page space |
        | Shadows | Blur | `shadow:` is stacked rounded rectangles at fading opacity, which reads as a soft shadow in print |
        | PDF features | PDF/X, JavaScript and actions | Not written |
        | Signatures | Long-term validation data (LTV, PAdES B-LT and B-LTA), a second signature, signing a file that already exists; keys other than RSA and EC | A render carries one [signature](/docs/conformance#digital-signatures) over the whole file; the rest needs incremental updates, which are not written. Another key type raises `ArgumentError` |
        | Conformance | PDF/A-1, PDF/A levels A and U, PDF/UA-2; CMYK colour and CMYK JPEGs in a conforming document | Only [PDF/A-2b, PDF/A-3b and PDF/UA-1](/docs/conformance) are claimed; CMYK is a `ConformanceIssue` warning |
        | Forms | Glyphs for text typed into a field beyond printable ASCII and Latin-1 (and a select's options) | The value a field is rendered with is drawn in the document's fonts, whatever its script; what a reader types outside the kept glyphs is drawn by the viewer in a font of its own |

        Anything the engine skips at render time is reported in `document.warnings` rather than dropped
        silently — see [Warnings and strict mode](/docs/warnings).
      MD
    end

    DocsUI::Section("Sizing images", description: "JPEGs are embedded as they are.") do
      md <<~'MD'
        A JPEG is embedded byte for byte, so size it before you embed it: for print,
        `width_in_points / 72 * 300` pixels is plenty (a 160 pt photo needs about 670 px), and screen
        PDFs need half that. An image drawn at more than twice `max_ppi` is reported as an
        `OversizedImage`, and a PNG or a lossless WebP can be resampled with `downscale: true` — see
        [Resolution](/docs/images-and-svg#resolution).
      MD
    end
  end
end
