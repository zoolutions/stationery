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
          [ [ :code, "MissingGlyph" ], "char, family, count",
            "No font — the family, its fallbacks or Inter — has the character; it is drawn as .notdef. Whitespace is exempt: it draws as a blank of its width.",
            "missing glyph \"☃\" (U+2603) in Brand, drawn 2 times as .notdef" ],
          [ [ :code, "UnknownFamily" ], "requested, used",
            "A text style named a family that is neither registered, bundled nor an installed pack; it drew with the first registered family (else bundled Inter). Reported once per name.",
            "font family \"Brand\" is not registered, using \"Inter\"" ],
          [ [ :code, "UnsupportedSvg" ], "elements, source",
            "An SVG used elements that cannot be drawn (mask, pattern, …) or a use or clip-path that leads nowhere; the rest is drawn.",
            "SVG \"logo.svg\" uses unsupported elements: mask, use: #icon not found" ],
          [ [ :code, "OversizedImage" ], "source, pixels, ppi, limit",
            "A bitmap drawn at more than twice max_ppi (300 by default; images max_ppi: sets it, nil switches it off); resize it, or downscale: true for a PNG.",
            "image \"photo.jpg\" 1600px wide is drawn at 720 ppi (limit 300); resize it before embedding" ],
          [ [ :code, "SkippedImage" ], "source, reason",
            "An html/markdown image resolved nowhere, pointed outside base_path or was remote.",
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
          [ [ :code, "ConformanceIssue" ], "level, subject",
            "A PDF/A render used CMYK colour or a CMYK JPEG, which the sRGB output intent does not cover.",
            "PDF/A-3b: CMYK colour on page 1 is not covered by the sRGB output intent" ]
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
