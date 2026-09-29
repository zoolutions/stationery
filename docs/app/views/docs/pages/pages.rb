# frozen_string_literal: true

class Views::Docs::Pages::Pages < DocsUI::Page
  title "Pages, headers and footers"
  eyebrow "Guide"

  def lead = "Page sizes and margins, header and footer regions that reserve space, page templates, print hints, monochrome mode, ZPL for label printers and debug outlines."

  def content
    DocsUI::Section("Page size and margins") do
      md <<~'MD'
        ```ruby
        page size: :a4, margin: [40, 44, 56, 44], layout: :landscape
        ```

        | Size | Points (portrait) |
        | --- | --- |
        | `:a3` | 841.89 × 1190.55 |
        | `:a4` | 595.28 × 841.89 |
        | `:a5` | 419.53 × 595.28 |
        | `:a6` | 297.64 × 419.53 |
        | `:a7` | 209.76 × 297.64 |
        | `:b5` | 498.9 × 708.66 |
        | `:letter` (default) | 612 × 792 |
        | `:legal` | 612 × 1008 |
        | `:tabloid` | 792 × 1224 |
        | `:dl` (envelope, 110 × 220 mm) | 311.81 × 623.62 |
        | `:c5` (envelope, 162 × 229 mm) | 459.21 × 649.13 |
        | `:c6` (envelope, 114 × 162 mm) | 323.15 × 459.21 |
        | `:label_4x6` (4 × 6 in) | 288 × 432 |
        | `:label_4x3` | 288 × 216 |
        | `:label_4x2` | 288 × 144 |
        | `:label_100x150` (100 × 150 mm) | 283.46 × 425.2 |
        | `:label_100x50` | 283.46 × 141.73 |
        | `[width, height]` | any size, in points |
        | `["102mm", "74mm"]`, `"4in x 6in"` | any size, with its units |

        `layout: :landscape` swaps width and height: envelopes are listed short edge first, so it is the
        side the address is on. `margin:` (default 36) takes one value, `[y, x]`, `[top, x, bottom]`,
        `[top, right, bottom, left]` or `{ top:, right:, bottom:, left:, x:, y: }`, each in points or
        as a length with its unit (`"3mm"`).

        A size or a margin that cannot be read raises `ArgumentError` when the class is defined, with
        what `page` takes.
      MD
    end

    DocsUI::Section("One page only: max_pages", description: "For a label, a receipt or a card.") do
      md <<~'MD'
        Content that does not fit a page continues on the next, as a letter or a report should. A label,
        a receipt or a card must not, and `max_pages` says so:

        ```ruby
        class ShippingLabel < Stationery::Document
          page size: :label_4x6, margin: mm(4)
          max_pages 1
        end

        label = ShippingLabel.new(parcel)
        label.to_pdf
        label.warnings.map(&:message)
        # => ["the document may have 1 page and needs 2: page 2 starts with a Code 128 barcode"]

        label.to_pdf(max_pages: nil)   # one render without the limit
        ```

        A render that needs more pages than the limit lays them all out and reports
        `Warnings::TooManyPages` (`limit`, `pages`, `moved`), naming what the first page past the limit
        starts with: text by its first line, quoted and cut at 40 characters, anything else by its kind
        (`a table`, `an image`, `a QR code`, `a box`). Under [`strict`](/docs/warnings#strict-mode) it raises.

        | Render | More pages than `max_pages` |
        | --- | --- |
        | `to_pdf` | every page written, the warning reported (`strict` raises) |
        | `to_png` | a picture of every page, the warning reported (`strict` raises) |
        | `to_zpl` | raises `Stationery::WarningsError`, strict or not: no label is written, since each page is one more label printed |

        `to_pdf(max_pages:)`, `to_png(max_pages:)` and `to_zpl(max_pages:)` replace the limit for one
        render, `nil` takes it away. It is inherited; `max_pages nil` in a subclass takes it away, and a
        subclass's `page` keeps it. The declaration writes nothing: a document that fits is byte for byte
        what it is without it. Anything but a positive Integer or `nil` raises `ArgumentError` where it
        is written.
      MD
    end

    DocsUI::Section("Millimetres and inches", description: "Units for labels, envelopes and pre-printed forms.") do
      md <<~'MD'
        Every size and position is in points (1/72 inch). `mm`, `cm`, `inch` and `pt` convert to them, in
        the class body and in `view_template` of every component and document:

        ```ruby
        class Label < Stationery::Document
          page size: [mm(102), mm(74)], margin: mm(3)

          def view_template
            box(at: [mm(20), mm(45)], width: mm(60)) { text "Fragile" }
          end
        end
        ```

        They are private methods, `Numeric` is not patched, and a method of your own with one of the
        names wins. Any other class gets them with `include Stationery::Units`, or calls
        `Stationery::Units.mm(102)`.

        `page` also reads lengths written with their unit:

        ```ruby
        page size: ["102mm", "74mm"], margin: "3mm"
        page size: "4in x 6in", margin: ["0.25in", "0.5in"]
        page size: "102 x 74 mm"          # the first length takes the unit of the second
        ```

        | Part | Accepted |
        | --- | --- |
        | Number | digits, with a fraction after a point: `102`, `101.6`. No sign, exponent or comma |
        | Unit | `mm`, `cm`, `in`, `pt`, in either case |
        | Between the two lengths of a size | `x` or `×` |
        | Spaces | around numbers, units and the `x`, or none: `"4inx6in"` |

        `Stationery::Units.points("3mm")` reads one length. Unit strings are read by `page` (and
        `Stationery::Page.new`); elements take points, so write `padding: mm(3)` there.
      MD
    end

    DocsUI::Section("header and footer", description: "Regions that reserve space; the body flows between them.") do
      md <<~'MD'
        ```ruby
        header(gap: 8) do |page|
          row do
            text "ACME"
            text "Page #{page.number} of #{page.count}", align: :right
          end
        end
        footer(on: :rest) { text "Confidential", size: 7, align: :center }
        header(on: :first) {} # no header on page 1
        ```

        `header(height: nil, gap: 8, on: :all) { |page| … }` and `footer(…)` take the same options:

        - **`on:`** `:all` (default), `:first`, `:rest`, `:odd`, `:even`, `:last`, a page number, a range or
          `->(number) { … }`. Later declarations win for the pages they match, and an empty block removes the
          region there.
        - **`gap:`** extra space between the region and the body.
        - **`height:`** without it a region is measured once, on the first page that uses it; pass it when the
          content varies per page.

        The footer is bottom-aligned. A region taller than its space is still drawn and listed in
        `document.warnings`; regions that leave no room for the body raise `ArgumentError`.
      MD

      DocsUI::Callout(:tip, title: "on: :last") do
        "A taller last-page footer (say, with totals) is supported: the paginator checks whether the rest fits " \
          "above it; content that fits a normal page but not the last one continues onto an extra page."
      end
    end

    DocsUI::Section("page_template", description: "Runs on every page after pagination.") do
      md <<~'MD'
        ```ruby
        page_template do |page|
          box(at: [page.margin[3], page.height - 34], width: page.content_box.width) do
            text "Page #{page.number} of #{page.count}", size: 7, align: :right
          end
        end

        page_template(layer: :background) do |page|
          canvas(height: page.height, at: [0, 0], width: page.width) do |c, rect|
            c.fill_rect(rect.x, rect.y, rect.width, rect.height, color: "#FFFBEB")
          end
        end
        ```

        The block receives `page.number`, `page.count`, `page.width`, `page.height`, `page.margin`
        (`[top, right, bottom, left]`) and `page.content_box` (`x`, `y`, `width`, `height`). With a header or
        footer, `content_box` excludes their space — it is the body's area.
      MD
    end

    DocsUI::Section("Layers", description: "Foreground and background.") do
      md <<~'MD'
        `page_template` paints on the **foreground** by default, over the body. `layer: :background` paints
        under the content — full-bleed backgrounds, watermarks, letterheads. Use `box(outset:)` to bleed a
        single box's background into the margins instead.

        Anchors drawn by page templates resolve to the first page; bookmarks inside page templates are
        ignored. Warnings raised while templates draw are included in `document.warnings`.
      MD
    end

    DocsUI::Section("Page labels", description: "How viewers name the pages.") do
      md <<~'MD'
        `page_labels` maps a 1-based first page to the range that starts there. Each range takes
        `style:` (`:decimal`, `:roman`, `:roman_lower`, `:alpha`, `:alpha_lower`, or `nil` for a prefix
        only), `start:` (the number the range counts from, default 1) and `prefix:`. Pages before the
        first range keep their physical number in the viewer.

        ```ruby
        class Report < Stationery::Document
          page_labels 1 => { style: :roman_lower },                       # i, ii, iii
                      4 => { style: :decimal },                           # 1, 2, 3, …
                      12 => { style: :alpha, prefix: "Appendix " }        # Appendix A, Appendix B
        end

        Report.new.to_pdf(page_labels: nil) # one render without labels
        ```

        The labels are written as the catalog's `/PageLabels` number tree; `Inspector#page_labels`
        and `have_page_labels` read them back per page.
      MD
    end

    DocsUI::Section("Printing", description: "Scaling, copies, duplex and the print dialog: hints to the viewer.") do
      md SourceMarkdown.readme_section("Printing")
    end

    DocsUI::Section("Monochrome", description: "Black or nothing: thermal label printers and other one-bit devices.") do
      md SourceMarkdown.readme_section("Monochrome")
    end

    DocsUI::Section("Label printers: to_zpl", description: "ZPL II for Zebra and compatible thermal printers.") do
      md SourceMarkdown.readme_section("Label printers: to_zpl")
    end

    DocsUI::Section("Embedded files", description: "Attachments, for Factur-X and friends.") do
      md <<~'MD'
        `attach_file name, data, mime:, description:, relationship:, modified_at:` embeds a file in
        every render; `to_pdf(attachments: [{ name:, data:, … }])` adds more for one render. Each file
        is a `/Filespec` with an `/EmbeddedFile` stream, listed in the catalog's `/EmbeddedFiles`
        name tree and `/AF` array. `relationship:` writes `/AFRelationship`: `:alternative` (the
        machine-readable twin Factur-X and ZUGFeRD require), `:source`, `:data`, `:supplement` or
        `:unspecified` (default). The same name twice raises `ArgumentError`; an encrypted document
        encrypts the embedded streams too.

        ```ruby
        class InvoicePdf < Stationery::Document
          attach_file "factur-x.xml", invoice_xml, mime: "text/xml", description: "Factur-X",
                      relationship: :alternative
        end
        ```

        `Inspector#attachments` reads them back as `{ name:, mime:, bytes:, description:, relationship: }`;
        `have_attachment` and `assert_pdf_attachment` assert one by name, type and relationship.

        For an e-invoice, [`factur_x`](/docs/conformance#factur-x-zugferd-e-invoices) does all of it in one
        line: it embeds the XML, claims PDF/A-3b and writes the Factur-X identification in XMP.
      MD
    end

    DocsUI::Section("Accessibility (tagged PDF)", description: "A structure tree for screen readers.") do
      md SourceMarkdown.readme_section("Accessibility (tagged PDF)")
    end

    DocsUI::Section("Debug outlines", description: "See every layout rectangle.") do
      md SourceMarkdown.readme_section("Debugging")
      md <<~'MD'
        The kinds are `:box`, `:padding`, `:column`, `:flow`, `:cell`, `:cell_padding`, `:positioned`,
        `:image`, `:page` and `:region`. In a Rails [preview](/docs/rails#previews) add `?debug=1`; from the
        [CLI](/docs/cli) pass `--debug`.
      MD
    end
  end
end
