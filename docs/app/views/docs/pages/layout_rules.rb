# frozen_string_literal: true

class Views::Docs::Pages::LayoutRules < DocsUI::Page
  title "Layout rules"
  eyebrow "Guide"

  def lead = "How the box-layout engine measures, splits and paints nodes, and how that decides where each page breaks."

  def content
    DocsUI::Section("Measure, split, paint", description: "The protocol every node implements.") do
      md <<~'MD'
        Every element builds a layout node. Nodes know nothing about pages; they answer four questions:

        | Method | Answers |
        | --- | --- |
        | `measure(width)` | How tall am I at this width? |
        | `split(width, height, fresh:)` | The part that fits in `height`, and the remainder (either may be `nil`). `fresh: true` means nothing is above it on a new page. |
        | `natural_width` / `min_width` | Preferred and narrowest widths — how `:auto` columns and table widths are resolved. |
        | `paint(canvas, x, y, width)` | Draw at a position already decided. |

        The paginator splits the document's root flow at the height of each page's content box, paints the
        head on that page and carries on with the remainder until nothing is left. Page templates, headers
        and footers run afterwards, so they know `page.count`.
      MD
    end

    DocsUI::Section("Pagination", description: "What moves, what splits.") do
      md <<~'MD'
        A flow (the document body, and every box's content) stacks children top to bottom. At a page break:

        - a **splittable** child — text, lists, tables, boxes, rows, groups, wraps — continues on the next page;
        - anything else (an image, a rule, a canvas, a fixed-height box) moves there whole;
        - a `spacer` that lands on the break is dropped;
        - `page_break` forces what follows onto a new page;
        - a [float](/docs/elements#floats) never splits: when it does not fit, or what wraps beside it could
          not start there, it moves to the next page with that content. A paragraph, a list item and a box
          beside it split as they do anywhere, and what they carry over is wrapped again at the full width;
          a box with a background keeps the full width on both pages, the float over it on the first.
          Floats taller than a page together are cut before the first that does not fit, and only a float
          taller than a page by itself is reported as an `Overflow`.

        Text splits between lines. Tables split between rows (never through a rowspan) and repeat their
        header rows. Lists keep each marker with the first line of its item.
      MD
    end

    DocsUI::Section("keep_with_next", description: "Never end a page on a heading.") do
      md <<~'MD'
        On `text`, `box` or `group`, `keep_with_next: true` never ends a page with that node: it moves to the
        next page with its successor. A number keeps at least that many points of what follows with it:

        ```ruby
        text "3. Financial review", size: 16, weight: :bold, keep_with_next: 60
        table(rows, header: true)
        ```

        A kept node also moves when its successor avoids breaking inside and would not start on the page.
      MD
    end

    DocsUI::Section("Page breaks in text", description: "orphans and widows.") do
      md <<~'MD'
        A paragraph splits between lines. `orphans:` is the fewest lines a break may leave at the foot of
        a page and `widows:` the fewest it may carry to the next; both default to 1, so any line may end
        or start a page. With larger values the break moves up until both are met, and a paragraph that
        cannot meet them (it would leave too few lines behind, or is shorter than orphans plus widows)
        moves to the next page whole. A paragraph that already starts a fresh page cannot move, so it
        splits as best it can, keeping the widows if a line can still stay.

        ```ruby
        default_text orphans: 2, widows: 2          # for the whole document
        text long_story, orphans: 3, widows: 3      # or per paragraph
        html body, styles: { p: { orphans: 2, widows: 2 } }
        ```

        `text_style` sets them for a block like any text default.
      MD
    end

    DocsUI::Section("break_inside", description: "Soft avoid, auto, avoid.") do
      md <<~'MD'
        `break_inside:` is accepted by `box`, `row`, `column` and `text`:

        | Value | Behaviour |
        | --- | --- |
        | `nil` (default, "soft avoid") | Moves to the next page whole when it fits there; continues across pages when it does not fit on a page of its own. |
        | `:auto` | Splits at any page break, wherever it starts. |
        | `:avoid` | Never splits. Content taller than a page overflows (and warns). |

        `group(keep_together: true)` is `break_inside: :avoid` for a group.
      MD

      DocsUI::Callout(:note, title: "Behaviour change") do
        "Boxes taller than a page used to overflow; they now continue on the next page. " \
          "Pass break_inside: :avoid for the old behaviour."
      end
    end

    DocsUI::Section("Decoration at a cut", description: "slice or clone.") do
      md <<~'MD'
        When a box splits, each fragment's cut side is open. `decoration: :slice` (default) drops the padding
        and border on that side, like CSS `box-decoration-break: slice`; `:clone` keeps the padding. Borders
        are left open and rounded corners are cut square at the break.

        ```ruby
        box(background: "#F0FDFA", padding: 16, radius: 8, break_inside: :auto, decoration: :clone) do
          text long_callout
        end
        ```

        Rows split every column at the same break; a column that ends early continues as an empty fragment
        so backgrounds stay aligned.
      MD
    end

    DocsUI::Section("Fixed heights and overflow", description: "truncate or shrink_to_fit.") do
      md <<~'MD'
        A box with `height:` never splits, and neither does a row holding one. When its text does not fit,
        `overflow:` decides:

        - `:visible` (default) — draw it anyway;
        - `:truncate` — keep the whole lines that fit and drop the rest;
        - `:shrink_to_fit` — reduce the text size until it fits (when the box holds a single `text`;
          otherwise it truncates).

        ```ruby
        box(height: 40, overflow: :shrink_to_fit, valign: :middle) { text customer.name, size: 18 }
        ```
      MD
    end

    DocsUI::Section("Overflow warnings", description: "Content is placed anyway.") do
      md <<~'MD'
        Content taller than the space a page has for it — an `:avoid` box, an image, a fixed-height box —
        is placed anyway and never raised on. Each case is recorded as a
        `Stationery::Warnings::Overflow` with the page, the height placed and the height available:

        ```ruby
        doc.to_pdf
        doc.warnings.map(&:message)
        # => ["content 912.0pt tall placed on page 3 with 770.0pt available"]
        ```

        Use `strict` to fail instead — see [Warnings and strict mode](/docs/warnings) — and
        `to_pdf(debug: true)` to see the rectangles involved.
      MD
    end
  end
end
