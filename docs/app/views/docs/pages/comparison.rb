# frozen_string_literal: true

# Zeitwerk resolves this compact reference through the directory-implied
# namespaces (app/views/docs/pages/ → Views::Docs::Pages), so there's no need
# for the 4-level nested-module ceremony.
class Views::Docs::Pages::Comparison < DocsUI::Page
  title "Comparison"
  eyebrow "Reference"

  def lead = "Stationery next to Prawn and sghtmltopdf: what each one does, what only one does, and when to pick which."

  def content
    DocsUI::Section("The three", description: "Different shapes of the same job.") do
      md <<~'MD'
        | | Stationery 0.10 | Prawn 2.5 + prawn-table 0.2 | sghtmltopdf 0.5 |
        | --- | --- | --- | --- |
        | What it is | A layout engine with a Phlex-style component DSL | A cursor API over a PDF writer | An HTML and CSS renderer written in Rust |
        | Input | Ruby components; `html` and `markdown` elements for user content | Ruby calls: `text`, `bounding_box`, `table` | An HTML document with CSS |
        | Runtime | Pure Ruby, no runtime dependencies | Pure Ruby (`pdf-core`, `ttfunk`, `matrix`) | Native extension, precompiled for Linux and macOS; Windows delegates to a server process |
        | Licence | MIT | Ruby / GPL-2 / GPL-3 | MIT |
        | First release | September 2026 | 2008 | July 2026 |

        Every claim below was checked against the code of these versions. "Partial" means the
        feature exists with a documented limit; the [Limitations](/docs/limitations) page has
        Stationery's.
      MD
    end

    DocsUI::Section("Layout and pages") do
      md <<~'MD'
        | | Stationery | Prawn | sghtmltopdf |
        | --- | --- | --- | --- |
        | Layout model | Rows, columns, boxes, `stack`/`layer`, `wrap`; the engine measures and places | You compute positions; `bounding_box`, `move_down`, `cursor` | CSS block, inline, flexbox, grid, floats, absolute positioning |
        | Page breaks | `page_break`, `break_inside: :avoid`/`:auto`, `keep_with_next`, `keep_together`, `min_height` | `start_new_page`; `group` raises `NotImplementedError` | `break-before`/`after`/`inside`, `page-break-*` |
        | Orphans and widows | `orphans:` and `widows:` on text, default 1 | No | Yes, default 2 |
        | Headers, footers, page n of N | Page templates with any content, `header`/`footer`, regions | `repeat(:all)` blocks with `number_pages` | `@page` margin boxes and header/footer HTML with placeholders |
        | Tables across pages | Split rows, repeated header, `colspan`/`rowspan`, `split_rows:` | prawn-table: header repeat, spans, splitting | Yes, `thead` repeats |
        | Balanced columns | `columns(count:, gap:, balance:, rule:)`, across pages | No | No |
        | Text wrap around images | No | No | Floats yes |
        | Page labels | Yes | No | No |
      MD
    end

    DocsUI::Section("Text and fonts") do
      md <<~'MD'
        | | Stationery | Prawn | sghtmltopdf |
        | --- | --- | --- | --- |
        | Kerning | GPOS pairs and `kern` table, on by default | `kern` table, on by default | HarfBuzz-class shaping (harfrust) |
        | Ligatures and OpenType features | `liga` by default; `smcp`, `onum`, `tnum`, `ss01`… on request; no contextual lookups | No | Full shaping through harfrust |
        | Hyphenation | Soft hyphens; patterns for English, German and Swedish | Soft hyphens only | Soft hyphens only (`hyphens: auto` has no dictionary) |
        | Justification | Yes, widens spaces | Yes | Yes |
        | Fallback fonts | Per character, then bundled Inter | `fallback_fonts` per box | Font stack per element |
        | CJK line breaking | Between ideographs, kana and Hangul with kinsoku for closing and opening marks; zero-width space and `<wbr>` | Partial: zero-width spaces | Yes, UAX #14, `word-break` |
        | Right-to-left, Arabic, Indic | No: drawn glyph by glyph, left to right | `direction: :rtl` reverses runs; no shaping | Shaping yes; `direction: rtl` and vertical writing no |
        | Colour emoji | No, draws `.notdef` | No | CBDT, sbix, COLR v0 |
        | Font formats | TTF, OTF/CFF, TTC, WOFF | TTF, OTF/CFF, TTC, DFont | TTF, OTF |
        | WOFF2, variable fonts | No | No | No |
        | Subsetting | Yes, TrueType and CFF | Yes | Yes |
        | Bundled fonts | Inter; font packs by CLI | None (standard 14 unembedded) | None; system fonts optional |
      MD
    end

    DocsUI::Section("Images and drawing") do
      md <<~'MD'
        | | Stationery | Prawn | sghtmltopdf |
        | --- | --- | --- | --- |
        | JPEG, PNG | Yes | Yes | Yes |
        | WebP, GIF | Lossless WebP; lossy WebP and GIF no | No | WebP yes, GIF no |
        | SVG | Inline and file: shapes, paths, gradients, text, stylesheets, `use`, `symbol`, `clipPath`; no `mask`, `pattern`, `filter` | No (prawn-svg is a separate gem) | By reference through `<img>` (usvg); inline `<svg>` no |
        | Oversized-image warning, downscaling | Yes; PNG and WebP resampling | No | No |
        | Rotation, shadows, overlays | `rotate:` on images and boxes, `shadow:`, `stack`/`layer` | `rotate` blocks; `transparent`; no shadows | CSS `transform`, `box-shadow`, positioning |
        | Direct drawing | `canvas` with paths, clips, transforms | Full graphics API | No |
      MD
    end

    DocsUI::Section("PDF features") do
      md <<~'MD'
        | | Stationery | Prawn | sghtmltopdf |
        | --- | --- | --- | --- |
        | Links, outline, table of contents | Yes, yes, `table_of_contents` element | Links yes, outline yes, no TOC element | Links yes; outline no; `--toc` |
        | Forms (AcroForm) | Text, checkbox, radio, select, signature fields; appearances in the document's fonts | No | No (`<input>` is drawn, not interactive) |
        | Tagged PDF, PDF/UA-1 | Yes, veraPDF-verified | No | No |
        | PDF/A | 2b and 3b, veraPDF-verified | No | No |
        | XMP metadata | Yes | No | No |
        | Embedded files, Factur-X / ZUGFeRD | Yes; profiles MINIMUM to XRECHNUNG, Mustang-validated | No | No |
        | Encryption | AES-256, AES-128, RC4-128 | RC4 40 and 128 bit | No |
        | Digital signatures | CAdES detached, PAdES baseline B-B and B-T (RFC 3161 timestamp), RSA or ECDSA; no LTV, one signature | No | No |
        | Page labels | Yes | No | No |
      MD
    end

    DocsUI::Section("Working with it") do
      md <<~'MD'
        | | Stationery | Prawn | sghtmltopdf |
        | --- | --- | --- | --- |
        | HTML or Markdown input | `html` and `markdown` elements: structure and inline marks | No (third-party gems) | Its whole input |
        | CSS | Partial: a property subset on the `html` element (colours, font size, weight and style, decoration, alignment, backgrounds, padding, margins, table borders and widths, page breaks) with element, class and id selectors. No `display`, flexbox, grid, floats, positioning, `font-family` or selectors with combinators | No | A cascade with custom properties, `calc()`, `:has()`; flexbox, grid, floats, positioning |
        | Untrusted content | Link scheme allow-list, no remote fetches, image `base_path:` sandbox, bounded nesting | Not applicable | Node, depth and image size caps, file sandbox |
        | Testing helpers | Inspector, RSpec matchers, Minitest assertions | pdf-inspector (separate gem) | None |
        | Instrumentation | ActiveSupport::Notifications events | No | No |
        | Warnings instead of silent drops | `document.warnings`, `strict` | No | Warnings on stderr |
        | Rails | `render pdf:`, `send_pdf`, previews | Community gems | `render pdf:` in the wicked_pdf style |
        | Streaming output | Partial: `to_pdf { \|chunk\| }` streams the write phase; layout runs first, so peak memory does not drop | `render_file` only | Yes: page-by-page streaming to a block or a sink, bounded memory |
        | Performance regression gate | `rake metrics` in CI | No | `cargo bench` metrics in CI |
      MD
    end

    DocsUI::Section("Speed", description: "Same documents, same fonts; see Performance for the method.") do
      md <<~'MD'
        sghtmltopdf is native code and is faster by a clear margin; Stationery renders faster than
        Prawn and writes smaller files than both. The numbers, the machine and the way they were
        taken are on the [Performance](/docs/performance) page, and `bundle exec rake bench` runs
        all three engines on yours.
      MD
    end

    DocsUI::Section("When to pick which") do
      md <<~'MD'
        **Pick Stationery** when the PDF is the product: invoices, contracts, reports, flyers and
        forms that need bookmarks, accessibility, PDF/A, e-invoicing, encryption or a signature,
        built from the same Ruby components as the rest of the app, with tests that read the PDF
        back. It stays pure Ruby, so there is nothing to compile, no browser and no server process.

        **Pick sghtmltopdf** when you already have HTML templates and CSS, need CSS layout
        (flexbox, grid, floats), complex-script text or colour emoji, or must render very large documents
        with bounded memory, and can live without outlines, forms, tagged PDF, PDF/A and encryption.
        It is much faster, at the price of a native extension.

        **Pick Prawn** when you have a Prawn codebase, want the lowest-level control over every
        coordinate, or need its long track record. New documents that want layout done for them
        are less work in either of the other two.
      MD
    end
  end
end
