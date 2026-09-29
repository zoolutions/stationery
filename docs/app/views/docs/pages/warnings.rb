# frozen_string_literal: true

class Views::Docs::Pages::Warnings < DocsUI::Page
  title "Warnings and strict mode"
  eyebrow "Reference"

  def lead = "Everything a render noticed but did not raise on, and how to make it fail instead."

  def content
    DocsUI::Section("document.warnings", description: "After to_pdf.") do
      md <<~'MD'
        After `to_pdf`, `document.warnings` is an Enumerable of every problem the render worked around, each
        with a `#message`. There is one collector per render; equal warnings are listed once, missing glyphs
        are counted per character and family, and warnings raised while page templates and regions draw are
        included.

        ```ruby
        document = ReportPdf.new(report)
        document.to_pdf("report.pdf")
        document.warnings.each { |warning| logger.warn("[pdf] #{warning.message}") }
        ```
      MD
    end

    DocsUI::Section("Warning kinds", description: "Stationery::Warnings::*") do
      DocsUI::Table(
        %w[Kind Fields When Example message],
        [
          [ [ :code, "Overflow" ], "page, height, available",
            "Content taller than the space a page had for it was placed anyway (an :avoid box, an image, a region).",
            "content 912.0pt tall placed on page 3 with 770.0pt available" ],
          [ [ :code, "TooManyPages" ], "limit, pages, moved",
            "A document that declares max_pages (or a render given max_pages:) needed more pages. Every page is laid out and kept by to_pdf and to_png; to_zpl raises WarningsError with it whether or not the render is strict, and writes no label. moved is what the first page past the limit starts with: its first line of text, quoted and cut at 40 characters, or the kind of what is there (a Code 128 barcode, a table, an image, a box); nil when nothing there can be named.",
            "the document may have 1 page and needs 2: page 2 starts with a Code 128 barcode" ],
          [ [ :code, "MissingGlyph" ], "char, family, count, stand_in",
            "No font — the family, its fallbacks or Inter — has the character; it is drawn as .notdef, with the character kept as ActualText so the text still extracts. Whitespace is exempt: it draws as a blank of its width. Under a conformance level it raises ConformanceError instead: neither PDF/A nor PDF/UA lets text reference .notdef. With missing_glyphs: :replace the level draws a stand-in the font has (U+FFFD, else U+25A1, else ?) and stand_in is that character; it is nil for .notdef.",
            "missing glyph \"☃\" (U+2603) in Brand, drawn 2 times as .notdef" ],
          [ [ :code, "UnknownFamily" ], "requested, used",
            "A text style named a family that is neither registered, bundled nor an installed pack; it drew with the first registered family (else bundled Inter). Reported once per name.",
            "font family \"Brand\" is not registered, using \"Inter\"" ],
          [ [ :code, "UnsupportedSvg" ], "elements, source",
            "An SVG used elements that cannot be drawn (mask, pattern, …) or a use or clip-path that leads nowhere; the rest is drawn.",
            "SVG \"logo.svg\" uses unsupported elements: mask, use: #icon not found" ],
          [ [ :code, "OversizedImage" ], "source, pixels, ppi, limit",
            "A bitmap drawn at more than twice max_ppi (300 by default; images max_ppi: sets it, nil switches it off); resize it, or downscale: true for a PNG or WebP.",
            "image \"photo.jpg\" 1600px wide is drawn at 720 ppi (limit 300); resize it before embedding" ],
          [ [ :code, "SkippedImage" ], "source, reason",
            "An html/markdown image resolved nowhere, pointed outside base_path or was remote; or to_png drew a lossless, arithmetic-coded or 12-bit JPEG, which is not decoded, as a crossed box.",
            "image \"https://…/a.png\" skipped: remote" ],
          [ [ :code, "DroppedLink" ], "href",
            "An html/markdown href with a scheme outside links: (default http, https, mailto, tel) kept its text but no link.",
            "link \"javascript:alert(1)\" dropped: scheme not allowed" ],
          [ [ :code, "NestingLimit" ], "depth, limit",
            "html, markdown or an SVG nested deeper than its limit (max_depth: 64 elements; 12 indented block quotes or lists; 128 SVG elements) and was flattened there: the text is kept, the structure is not.",
            "content nested 5000 levels deep was flattened below level 64" ],
          [ [ :code, "UnsupportedCss" ], "properties, selectors",
            "html met CSS outside the subset it reads: unknown properties, values a property does not take (listed as property: value) and selectors with combinators. Reported once per html call; the rest of the styles apply.",
            "html styles not read: properties float, margin: 1em; selectors ul li" ],
          [ [ :code, "UnresolvedLink" ], "name, page",
            "A #name link has no matching anchor; the link is dropped.",
            "link to \"totals\" on page 2 has no matching anchor" ],
          [ [ :code, "DuplicateAnchor" ], "name, page",
            "An anchor name was defined twice; the first is kept.",
            "anchor \"intro\" on page 4 is already defined" ],
          [ [ :code, "MissingAlt" ], "kind, page",
            "A tagged render drew an image or an SVG without alt:, or with a blank one (\"\", whitespace alone), an html <img> without an alt attribute or a markdown image without a description. alt: false marks decoration, which needs none, and so does <img alt=\"\"> in html; markdown has no way to. Under PDF/UA-1 it raises ConformanceError instead.",
            "image on page 2 has no alt: text (alt: false marks decoration)" ],
          [ [ :code, "SkippedHeading" ], "level, allowed, page",
            "A tagged render has a heading more than one level below the heading before it, or a first heading that is not heading: 1; allowed is the deepest level it could have had. Headings are read in the order of the structure tree; those of headers, footers and page templates do not count. Under PDF/UA-1 it raises ConformanceError instead.",
            "heading 3 on page 2 skips a level: heading 2 is the deepest that may follow heading 1" ],
          [ [ :code, "UntaggedLink" ], "target, place, page",
            "A tagged render has a link annotation that belongs to no Link element. place is what painted it: :artifact (an artifact of the body, such as the header row a table repeats on its next pages), :canvas (canvas.link without a tag:) or :header, :footer and :page_template (canvas.link on the canvas of one). Every link: is tagged, those of headers, footers and page templates too. Under PDF/UA-1 it raises ConformanceError instead.",
            "link to https://example.com drawn by canvas.link without a tag: on page 1 is outside the structure tree" ],
          [ [ :code, "MissingLanguage" ], "",
            "A tagged render has no metadata lang:.",
            "tagged PDF has no language: set metadata lang:" ],
          [ [ :code, "ConformanceIssue" ], "level, subject",
            "A PDF/A render used CMYK colour or a CMYK JPEG, which the sRGB output intent does not cover.",
            "PDF/A-3b: CMYK colour on page 1 is not covered by the sRGB output intent" ],
          [ [ :code, "NotMonochrome" ], "color, kind, page",
            "A monochrome render (without snap: true) painted a colour that is not black or white, or at an opacity below 1, or drew a lossless, arithmetic-coded or 12-bit JPEG, which is not decoded, so not dithered. color is \"#RRGGBB\" (with \" at opacity 0.5\"), or names the image; kind is :text, :rule, :background, :border, :gradient or :image. Reported once per colour, kind and page.",
            "text in #888888 on page 1 is not black or white" ],
          [ [ :code, "ThinLine" ], "width, kind, page, dpi",
            "A monochrome render (without snap: true) drew a stroke or a rule thinner than one of the printer's dots (72/dpi pt), which prints or not depending on where it lands. snap: true widens it to a dot.",
            "a rule 0.2 pt wide on page 1 is thinner than a dot at 203 dpi (0.355 pt): widen it, or snap: true" ]
        ]
      )
    end

    DocsUI::Section("Strict mode", description: "Fail instead of writing.") do
      md <<~'MD'
        ```ruby
        class InvoicePdf < Stationery::Document
          strict                               # every render of this class
        end

        InvoicePdf.new(invoice).to_pdf(strict: false)   # opt one render out again
        ReportPdf.new(report).to_pdf(strict: true)      # or opt one in

        begin
          InvoicePdf.new(invoice).to_pdf
        rescue Stationery::WarningsError => e
          e.warnings.map(&:message)
        end
        ```

        A strict render raises `Stationery::WarningsError` (with `#warnings`) instead of writing a PDF that
        produced any warning. `stationery render --strict` exits 1, and the `have_no_warnings` matcher /
        `assert_no_pdf_warnings` assertion check the same list in tests.
      MD
    end
  end
end
