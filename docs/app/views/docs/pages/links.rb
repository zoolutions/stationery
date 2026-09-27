# frozen_string_literal: true

class Views::Docs::Pages::Links < DocsUI::Page
  title "Links, bookmarks and contents"
  eyebrow "Guide"

  def lead = "External and internal links, named anchors, the PDF outline, and a table of contents with real page numbers."

  def content
    DocsUI::Section("Links", description: "URLs, mailto and #anchors.") do
      md <<~'MD'
        A link target starting with `#` jumps to a named anchor in the same PDF (written as a PDF `/Dest`
        GoTo link); anything else is a URL.

        ```ruby
        text "Docs", link: "https://stationery.zoolutions.llc"
        text "Write to <link href='mailto:hi@acme.test'>hi@acme.test</link>", markup: true
        text { plain "See "; link "#totals", "the totals" }
        box(link: "#appendix", padding: 8, background: "#EEF2FF") { text "Appendix" }
        ```

        `box(link:)` makes the whole box clickable. Link areas widen with justified text.
      MD
    end

    DocsUI::Section("Anchors", description: "Named link targets.") do
      md <<~'MD'
        ```ruby
        text "Introduction", anchor: "intro"      # also box(anchor:), group(anchor:), table(rows, anchor:)
        box(anchor: "totals") { text "Totals" }
        anchor "appendix"                         # standalone; moves to the next page with what follows it
        text "Appendix", size: 16
        ```

        An anchor on content that splits across pages points at its first page. A link to an unknown anchor
        is dropped and reported as an `UnresolvedLink` warning; a name defined twice keeps the first and
        reports a `DuplicateAnchor`. Anchors drawn by page templates resolve to the first page.
      MD
    end

    DocsUI::Section("Bookmarks", description: "The PDF outline.") do
      md <<~'MD'
        `bookmark:` adds an entry to the PDF outline (the viewer's bookmarks sidebar) pointing at where the
        content paints. Levels nest under the nearest shallower entry above them; `open: true` shows an
        entry's children expanded.

        ```ruby
        text "Introduction", size: 18, bookmark: "Introduction"            # level 1
        box(bookmark: { title: "Scope", level: 2, open: true }) { … }      # also group(bookmark:), table(rows, bookmark:)
        bookmark "Appendix", level: 1                                       # standalone
        text "Appendix", size: 16
        ```

        A document with bookmarks opens with the outline shown. A bookmark whose content never paints (cut
        off by a fixed-height box) is left out; bookmarks inside page templates are ignored. `html` and
        `markdown` add h1–h3 with `bookmarks: true`.
      MD
    end

    DocsUI::Section("Table of contents", description: "Filled in after pagination.") do
      md <<~'MD'
        `table_of_contents` lists the bookmarks with the page each one landed on, one clickable row per
        entry. It reads the outline when layout starts, so bookmarks declared after it are included.

        ```ruby
        text "Contents", size: 18
        table_of_contents                     # every level, dotted leaders
        table_of_contents(levels: 1..2, leader: :line, indent: 16, size: 9, color: "#374151")
        ```
      MD

      DocsUI::PropTable(
        [
          [ "levels", "Range or Integer", "1..", "Which outline levels to list; an Integer is the maximum depth." ],
          [ "leader", ":dots, :line, nil", ":dots", "What fills the space between title and number." ],
          [ "indent", "Numeric", "12", "Points of indent per level." ],
          [ "gap", "Numeric", "4", "Space between rows and before the number." ],
          [ "number_width", "Numeric", "width of \"0000\"", "The fixed, right-aligned slot for page numbers." ],
          [ "**style", "text options", "—", [ :md, "Any text style: `size`, `color`, `font`, …" ] ]
        ]
      )

      md <<~'MD'
        Numbers are right-aligned in a fixed slot and filled in after pagination, so a long contents list
        paginates without reflowing. An entry whose target never paints keeps its title, with no number and
        no link.
      MD
    end
  end
end
