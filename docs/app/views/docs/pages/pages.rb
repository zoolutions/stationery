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
