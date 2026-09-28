# frozen_string_literal: true

class Views::Docs::Pages::Fonts < DocsUI::Page
  title "Fonts"
  eyebrow "Guide"

  def lead = "Bundled Inter, your own TrueType and OpenType files, kerning, justification, a hook for a shaper, per-character fallback and installable font packs."

  def content
    DocsUI::Section("Bundled Inter", description: "Zero configuration.") do
      md <<~'MD'
        Inter (regular, bold, italic, bold italic; SIL Open Font License) is bundled and used when a document
        declares no family. `font_family "Inter"` with no paths selects it explicitly, and
        `Stationery.bundled_fonts` lists what ships. Font files are read lazily, on first use, never when the
        gem is required.
      MD
    end

    DocsUI::Section("Your own families", description: "TTF and OTF.") do
      md <<~'MD'
        ```ruby
        class InvoicePdf < Stationery::Document
          font_family "Open Sans",
                      regular: "fonts/OpenSans-Regular.ttf", bold: "fonts/OpenSans-Bold.ttf",
                      italic: "fonts/OpenSans-Italic.ttf", bold_italic: "fonts/OpenSans-BoldItalic.ttf"
          default_text font: "Open Sans", size: 9
        end
        ```

        Fonts are TrueType (`.ttf`) or OpenType/CFF (`.otf`, name-keyed or CID-keyed) files. Only the glyphs a
        document uses are embedded (a CFF font keeps its glyph numbering and subroutines; unused glyphs are
        blanked), with a ToUnicode map so text copies and searches correctly. A style without its own file
        (bold, italic) is synthesised.

        A family name used at render time is resolved in order: registered families, bundled families,
        installed packs in `Stationery.font_paths`, then the first registered family, then bundled Inter.
        `font_family "Name"` with no paths raises `ArgumentError` when the name is neither bundled nor
        installed.
      MD
    end

    DocsUI::Section("Kerning and justification") do
      md <<~'MD'
        Text is pair-kerned from the font's GPOS `kern` feature (PairPos lookups, including class-based pairs
        and Extension lookups), falling back to the legacy `kern` table. `kerning: false` on an element or in
        `default_text` turns it off. Pairs that straddle a style or font change are not kerned. Kerning only
        tightens in practice, so a kerned line is never wider than the same line unkerned.

        Standard ligatures (fi, fl, ffi, …) come from the font's GSUB `liga` feature and are on by default;
        `ligatures: false` on an element or in `default_text` turns them off, and any `letter_spacing` does too.
        A ligature glyph maps back to all of its characters, so extracted and copied text is unchanged. Fonts
        without `liga` ligatures, such as bundled Inter, are unaffected.

        ### Hyphenation

        Off unless asked for. `hyphenate: "de"` on `text`, `text_style`, `default_text` or an `html`/`markdown`
        style (`styles: { p: { hyphenate: "de" } }`) breaks a word that does not fit at the longest point
        Liang's algorithm allows over the bundled TeX `hyph-utf8` patterns — `true` or `"en"` for American
        English, `"de"` for German (2006 orthography), `"sv"` for Swedish — and draws a hyphen at the break.
        Two letters stay together at the start of a word and two (three in English) at its end. A soft hyphen
        (U+00AD, `&shy;` in HTML) names the break points of a word yourself and, as in TeX, exempts that word
        from the patterns; it is never measured or drawn and never reaches the PDF, so an unbroken word
        copies out whole. A hyphenated line is justifiable like any other wrapped line.

        ### Line breaking

        Lines break at spaces, after hyphens and at hyphenation points, and also at a zero-width space
        (U+200B, `<wbr>` in HTML), which is never drawn and never reaches the PDF, and between ideographic
        characters — CJK ideographs, kana, Hangul, fullwidth forms — so Japanese, Chinese and Korean text
        wraps without spaces. A closing mark (。、」）ー and the small kana) stays on the line before it and
        an opening bracket (「（) with what follows, the usual kinsoku rules. Justification still widens
        spaces only, so a line of CJK text is set flush left.

        ```ruby
        default_text hyphenate: "de"
        text "Die Silbentrennung der Donaudampfschifffahrt"   # Silben- / trennung … at a narrow width
        text "Zei\u00ADtungsleser"                             # breaks only after "Zei"
        Stationery::Hyphenation.hyphenate("Silbentrennung", "de") # => ["Sil", "ben", "tren", "nung"]
        ```

        The pattern sets ship with the gem under `lib/stationery/hyphenation/patterns/` with their authors'
        notices (`LICENSES.md`: the American English patterns' own permissive notice, MIT for German, LPPL
        for Swedish). Another language raises `ArgumentError` naming the bundled ones.

        `align: :justify` (on `text`, `text_style` and table cells) stretches the spaces of wrapped lines to
        the full width, keeping kerning. The last line, lines ending in a newline and lines without spaces stay
        left-aligned; tabs are never stretched.
      MD
    end

    DocsUI::Section("OpenType features", description: "Small caps, figure styles, stylistic sets.") do
      md <<~'MD'
        `features:` on `text`, `text_style` and `default_text` applies the font's other GSUB features on top of
        `liga`: `smcp` small caps, `onum`/`lnum` oldstyle or lining figures, `tnum`/`pnum` tabular or
        proportional figures (tabular for the number columns of a table), `zero` a slashed zero, `dlig`
        discretionary ligatures, `ss01`… stylistic sets, `case` case-sensitive punctuation. Tags are Symbols
        or Strings.

        ```ruby
        default_text font: "Open Sans", features: %i[onum]
        text "Total 2,026.00", features: %i[tnum lnum], align: :right
        text "Chapter One", features: [:smcp], letter_spacing: 0.5
        ```

        The reader applies single (SingleSubst formats 1 and 2) and ligature (LigatureSubst) lookups, also
        behind Extension lookups, in the font's own lookup order; a feature the font does not have is ignored
        without a warning, and `Stationery::Fonts::Font#features` lists the tags a font offers (bundled Inter:
        `tnum`, `zero`, `dlig`, `case` and stylistic sets; Open Sans: `onum`, `lnum`, `pnum`, `tnum`, `salt`).
        A substituted glyph keeps its source characters in the ToUnicode map, so extracted text is unchanged.
        Contextual features (`calt`, `clig`, `frac`) need lookup types the reader does not implement and do
        nothing, unless a shaper places the glyphs (below).
      MD
    end

    DocsUI::Section("Complex scripts", description: "The shaper hook: bring HarfBuzz, stationery draws what it places.") do
      md <<~'MD'
        Stationery places glyphs itself: one per character, the font's ligatures and single substitutions,
        pair kerning. Arabic, Hebrew, Indic and Thai text need a shaper, and the gem does not have one. An
        application that does (HarfBuzz) plugs it in, for a document class or for one render:

        ```ruby
        class Invoice < Stationery::Document
          shaper HarfBuzzShaper.new            # inherited; `shaper nil` takes an inherited one away
        end

        Invoice.new.to_pdf(shaper: my_shaper)  # this render only
        ```

        A shaper is anything that answers `call`:

        ```ruby
        def call(text, font, size:, features:, language:, **)
          # => [Stationery::Shaper::Glyph.new(gid:, advance:, cluster:, x_offset: 0, y_offset: 0), …] or nil
        end
        ```

        | Argument | What it is |
        |---|---|
        | `text` | One stretch of a line in one font and style |
        | `font` | A `Stationery::Shaper::Face`: `path` (the font file, nil when there is none), `index` (the face of a collection), `data` (the sfnt bytes; a WOFF is already unpacked), `units_per_em`, `postscript_name`, `glyph_count` |
        | `size:` | The size drawn at, in points |
        | `features:` | A frozen Hash of OpenType tags to switches: `"kern"` and `"liga"` always, following `kerning:` and `ligatures:` (letter spacing switches `liga` off), and the style's `features:` as `true` |
        | `language:` | The document's `metadata lang:`, or nil |

        The answer is the glyphs in **visual order**, left to right. `gid` is the glyph id in the font,
        `advance` and the offsets are in font units, and `cluster` is the index, in characters, of the first
        character of `text` the glyph stands for; glyphs of the same cluster stand together for the
        characters up to the next cluster. A Hash of the same fields does for a `Glyph`. Answering `nil`
        declines a text, which is then drawn as without a shaper. Anything else (a glyph id the font does
        not have, a cluster outside the text, an advance that is not a number) raises
        `Stationery::ShaperError`. Direction and script are not passed, because stationery knows neither:
        the shaper works them out from the text.

        What is shaped, and when:

        - Line breaking works on the text as written and measures each word and each stretch of spaces on
          its own. Each line is then cut where the font or the style changes, and every such stretch is
          shaped whole. That one answer is the stretch's width (alignment, underline, link rectangle) and
          what is drawn, so the two always agree. The width a break was decided on is the sum of the words',
          which can differ a little from the shaped line's, as kerning across a space already does.
        - The shaper is asked once per text, size and set of features in a render, and must answer the
          same for the same.
        - Every text a document draws goes through it: `text`, table cells, lists, `html`, `markdown`,
          headers and footers, the table of contents, text in `svg`. Form fields do not: a viewer that
          redraws a field after an edit would not shape it either.

        In the PDF the glyph ids are written as the shaper gave them. The font's widths stay its own, so an
        advance the shaper changed is a `TJ` adjustment, an x offset moves the pen before the glyph and back
        after it, and a y offset is a text rise (`Ts`) around it, which keeps marks in place under a
        synthetic oblique, a superscript or letter spacing. Glyphs the shaper placed are embedded whether or
        not a character maps to them. Where the ToUnicode map cannot give the text (glyphs out of logical
        order, several glyphs for one cluster, a glyph that already stands for another text, glyph 0) the
        glyphs are shown in a `Span` whose `ActualText` is the characters in logical order. Glyph 0 is
        reported as a `Warnings::MissingGlyph`, like any other.

        The limits of a hook:

        - The shaper reorders within the stretch it is given and nowhere else. Stretches on a line are placed
          left to right in the order written and lines break in that order, so there is no bidirectional
          reordering across a change of font or style; a right-to-left paragraph is set with `align: :right`,
          and the last line of a justified one is set left.
        - Fallback fonts are chosen per character from the fonts' cmaps before anything is shaped. Give the
          text the family that covers its script, or digits and punctuation the first family has are drawn
          from it, as stretches of their own.
        - Justification widens U+0020 spaces only (no kashida). Letter spacing is added after each cluster,
          so a mark stays on its base, but it pulls cursive letters apart.
        - Hyphenation and the breaking of a word wider than the line cut the text as written; the pieces are
          shaped as separate words.
        - Vertical advances are not read: text runs horizontally.
        - A reader that takes `ActualText` for the text (the gem's `Inspector`) gets it as written. poppler
          (`pdftotext` 26.09) and MuPDF (1.28) run their own reordering over it and return a right-to-left
          stretch reversed. pdf-reader's own `Page#text` drops a `Span` whose first glyph has no advance (a
          mark drawn first); the `Inspector` does not.

        [`examples/shaping/harfbuzz_shaper.rb`](https://github.com/zoolutions/stationery/blob/main/examples/shaping/harfbuzz_shaper.rb)
        is an adapter for HarfBuzz through the [`harfbuzz-ruby`](https://github.com/ydah/harfbuzz) gem
        (`gem "harfbuzz-ruby"`, `require "harfbuzz"`; not the older `harfbuzz` gem, which answers to the same
        `require`), about a hundred lines to copy into an application; stationery does not depend on it. It
        was run with harfbuzz-ruby 1.1.0 and HarfBuzz 14.5.0 against Noto Sans Arabic and draws joined,
        right-to-left Arabic with its marks and with left-to-right digits inside it. It cuts a stretch into
        runs of one direction by its letters alone, not by the Unicode bidirectional algorithm.
      MD
    end

    DocsUI::Section("Fallbacks", description: "Per-character, in the same weight and style.") do
      md <<~'MD'
        A character the text's family has no glyph for is drawn from the first family in `font_fallbacks`
        that has it, then from bundled Inter, in the same weight and style (synthesised when the family lacks
        the face):

        ```ruby
        class Report < Stationery::Document
          font_family "Brand", regular: "Brand-Regular.ttf"
          font_family "Noto Sans Symbols", regular: "NotoSansSymbols-Regular.ttf"
          font_fallbacks "Noto Sans Symbols"

          def view_template = text("Next → ☃")
        end
        ```

        Spaces, joiners, variation selectors and combining marks stay with the character before them.
        Whitespace no font has (an ideographic space U+3000, a figure space, a narrow no-break space, …) is
        drawn as a blank of the character's conventional width, never as `.notdef`. Any other glyph no font
        has is drawn as the family's `.notdef` and reported as a `Warnings::MissingGlyph` counting each
        drawn occurrence (so `strict` raises on it, and a [conformance](/docs/conformance) level raises
        `ConformanceError`). The characters themselves travel as the `ActualText` of a `Span` around the
        glyphs, so the text still extracts, copies and reads aloud as written.
        Fallback covers every text element, table cell, list
        marker, table of contents entry and page template text; direct `canvas.text` calls draw with the font
        they are given.
      MD
    end

    DocsUI::Section("Font packs", description: "Installed at development time, committed, never downloaded at runtime.") do
      md <<~'MD'
        | Pack | Family | License |
        |---|---|---|
        | `inter` | Inter (copied from the gem) | OFL 1.1 |
        | `noto_sans`, `noto_serif`, `noto_sans_mono` | Noto Sans, Noto Serif, Noto Sans Mono | OFL 1.1 |
        | `liberation_sans`, `liberation_serif`, `liberation_mono` | Liberation Sans, Serif, Mono (metric-compatible with Arial, Times New Roman, Courier New) | OFL 1.1, Reserved Font Name "Liberation" |

        ```shell
        stationery fonts list                                    # packs, licenses, what is in vendor/fonts
        stationery fonts install noto_sans liberation_serif      # into vendor/fonts/<pack>/
        stationery fonts install noto_sans --into app/fonts --force
        stationery fonts install liberation_sans --from ~/Downloads/liberation-fonts-ttf-2.1.5.tar.gz  # offline
        bin/rails generate stationery:fonts noto_sans            # the same, in Rails
        ```

        `fonts install` downloads pinned files over HTTPS, checks every SHA-256 before writing anything, and
        writes the license next to the fonts. Files already present are kept unless `--force`. `--from` takes a
        directory or a `.tar.gz` holding the same files (still SHA-checked).

        From Ruby: `Stationery::Fonts.install(:noto_sans, into: "vendor/fonts")` returns
        `{ regular: path, bold: path, … }`; `Stationery::Fonts.catalog` lists the packs. `rake fonts:verify`
        (development of the gem only) downloads every pack and checks its SHA-256s.
      MD
    end

    DocsUI::Section("Stationery.font_paths", description: "Where installed packs are found.") do
      md <<~'MD'
        `Stationery.font_paths` lists the directories searched for installed packs; the Railtie adds
        `vendor/fonts` (and `config.stationery.font_paths`) when it exists. With the pack's directory there,
        the family name is enough:

        ```ruby
        font_family "Noto Sans"                                                             # found in Stationery.font_paths
        font_family "Noto Sans", **Stationery::Fonts.paths(:noto_sans, dir: "vendor/fonts") # outside Rails
        Stationery.font_paths << File.expand_path("vendor/fonts")                           # or append it yourself
        ```
      MD
    end
  end
end
