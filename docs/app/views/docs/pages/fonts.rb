# frozen_string_literal: true

class Views::Docs::Pages::Fonts < DocsUI::Page
  title "Fonts"
  eyebrow "Guide"

  def lead = "Bundled Inter, your own TrueType and OpenType files, kerning, justification, per-character fallback and installable font packs."

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
        nothing.
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
        drawn occurrence (so `strict` raises on it). Fallback covers every text element, table cell, list
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
