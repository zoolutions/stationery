# frozen_string_literal: true

class Views::Docs::Pages::Pages < DocsUI::Page
  title "Pages, headers and footers"
  eyebrow "Guide"

  def lead = "Page sizes and margins, header and footer regions that reserve space, page templates and debug outlines."

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
        | `:letter` (default) | 612 × 792 |
        | `:legal` | 612 × 1008 |
        | `:tabloid` | 792 × 1224 |
        | `[width, height]` | any size, in points |

        `layout: :landscape` swaps width and height. `margin:` (default 36) takes one value, `[y, x]`,
        `[top, x, bottom]`, `[top, right, bottom, left]` or `{ top:, right:, bottom:, left:, x:, y: }`.
        An unknown size raises `ArgumentError`.
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
