# frozen_string_literal: true

class Views::Docs::Pages::DocumentsAndComponents < DocsUI::Page
  title "Documents and components"
  eyebrow "Getting started"

  def lead = "A Document is configured at class level and described in view_template; a Component is a reusable piece of one."

  def content
    DocsUI::Section("Document configuration", description: "Class-level macros, inherited by subclasses.") do
      md <<~'MD'
        Everything about the PDF as a whole is declared on the class. Subclasses inherit a copy of the
        parent's configuration, so a base `ApplicationPdf` can hold the house style.

        ```ruby
        class ApplicationPdf < Stationery::Document
          page size: :a4, margin: [40, 44, 56, 44]
          font_family "Brand", regular: "fonts/Brand-Regular.ttf", bold: "fonts/Brand-Bold.ttf"
          font_fallbacks "Noto Sans Symbols"
          default_text font: "Brand", size: 9, color: "#1F2937"
          metadata author: "Acme Studio AB", creator: "stationery"
        end

        class InvoicePdf < ApplicationPdf
          metadata title: "Invoice"
          strict
        end
        ```
      MD

      DocsUI::PropTable(
        [
          [ "page", "size:, margin:, layout:", "size: :letter, margin: 36, layout: :portrait",
            [ :md, "Page size (a name such as `:a4`, `:letter`, `:dl` or `:label_4x6`, `[width, height]` in points, or with units: `[\"102mm\", \"74mm\"]`, `\"4in x 6in\"`), margins (one value or CSS-style 2/4 values, in points or as `\"3mm\"`) and `:landscape`. Checked when the class is defined. See [Pages](/docs/pages)." ] ],
          [ "font_family", "name, regular:, bold:, italic:, bold_italic:", "—",
            [ :md, "Registers a family from `.ttf`/`.otf` files. With no paths it selects bundled Inter or an installed [font pack](/docs/fonts)." ] ],
          [ "font_fallbacks", "*names", "[]",
            [ :md, "Families tried, in order, for characters the text's own family has no glyph for; bundled Inter is tried last." ] ],
          [ "shaper", "shaper", "nil",
            [ :md, "An object answering `call(text, font, **options)` that places the glyphs of every text, for complex scripts; also `to_pdf(shaper:)`. See [Fonts](/docs/fonts)." ] ],
          [ "default_text", "**style", "{}",
            [ :md, "Base text style for the whole document: `font`, `size`, `color`, `align`, `leading`, `kerning`, …" ] ],
          [ "metadata", "title:, author:, subject:, keywords:, creator:, producer:", "{}",
            [ :md, "The PDF Info dictionary, mirrored in an XMP packet (`/Metadata`: `dc:title`, `dc:creator`, `dc:subject`, the `xmp:` dates, `pdf:Producer`). An Array value is joined with `\", \"`; other keys pass through; `xmp: false` leaves the packet out." ] ],
          [ "strict", "value = true", "false",
            [ :md, "Raise `Stationery::WarningsError` instead of writing a PDF that produced warnings." ] ],
          [ "incremental", "value = true", "false",
            [ :md, "Write each page as soon as it is painted, so a long document with headers or footers holds far less; also `to_pdf(incremental:)`. See [Rendering](#rendering)." ] ],
          [ "object_streams", "value = true", "on when tagged",
            [ :md, "Pack every object that is not a stream into deflated object streams with a cross-reference stream (PDF 1.5); a tagged render does unless `object_streams false`; also `to_pdf(object_streams:)`. See [Accessibility](/docs/pages#accessibility-tagged-pdf)." ] ],
          [ "page_template", "layer: :foreground", "—",
            [ :md, "A block run on every page after pagination; `layer: :background` paints under the content." ] ],
          [ "header / footer", "height:, gap:, on:", "gap: 8, on: :all",
            [ :md, "Regions that reserve space at the top/bottom of the pages `on:` matches." ] ]
        ],
        headers: %w[Macro Arguments Default Description]
      )
    end

    DocsUI::Section("Rendering", description: "to_pdf and what it leaves behind.") do
      md <<~'MD'
        `to_pdf(target = nil, strict: <class setting>, debug: false)` builds the element tree, paginates it,
        runs page templates, resolves links and bookmarks and returns the PDF as a binary String. With a
        `target` it also writes to that path or IO.

        ```ruby
        document = InvoicePdf.new(invoice)
        document.to_pdf("invoice.pdf")
        document.warnings.each { |warning| Rails.logger.warn(warning.message) }
        ```

        With a block, `to_pdf { |chunk| … }` streams the file in pieces as it is written and answers the
        number of bytes: the first bytes leave sooner and no output buffer is built. Every page is laid
        out and painted before the first byte. A signed document cannot go to a block.

        `incremental: true` (or `incremental` at class level) writes each page's content as soon as the
        page is painted and lets go of it, to a block before the next page is painted. It is for long
        documents with headers, footers, page templates or a table of contents, which are painted once
        every page is known and become content streams of their own; the file lists its page contents
        first and is a little larger. A render with `conformance:` or `sign:`, and a `strict` one that
        goes to a block, take the usual path, since they must be checked before a byte is written. To
        a block, an error on a late page leaves the start of a file. The figures are on the
        [Performance](/docs/performance#large-documents) page.

        `strict: false` opts one render out of a class-level `strict`; `debug:` outlines layout rectangles
        (see [Pages](/docs/pages#debug-outlines)).
      MD
    end

    DocsUI::Section("Components", description: "Phlex's lifecycle, the same element DSL.") do
      md <<~'MD'
        A `Stationery::Component` is a reusable piece of a document with Phlex's lifecycle —
        `around_template`, `before_template`, `view_template`, `after_template` — and every element.
        Content passed as a block is yielded from `view_template`:

        ```ruby
        class Callout < Stationery::Component
          def initialize(color:) = (super(); @color = color)
          def view_template(&) = box(background: @color, padding: 12, radius: 6, &)
        end

        class Report < Stationery::Document
          def view_template
            render Callout.new(color: "#F3F4F6") { text "Amount due" }
          end
        end
        ```

        A `Document` is itself a component, so documents can render other components, and components can
        render components.
      MD
    end

    DocsUI::Section("render", description: "What it accepts.") do
      DocsUI::Table(
        %w[Argument Renders],
        [
          [ "A component instance", [ :md, "`render Callout.new(color: \"#EEE\") { … }` — calls it with the block." ] ],
          [ "A component class", [ :md, "`render Divider` — instantiated with no arguments." ] ],
          [ "A String", [ :md, "A `text` paragraph." ] ],
          [ "A Proc or Method", [ :md, "Yielded as content, like a block." ] ],
          [ "A list (any Enumerable)", [ :md, "Each item rendered in turn." ] ]
        ]
      )

      md <<~'MD'
        Anything else raises `ArgumentError`. Blocks that take an argument receive the component, so
        `{ |c| c.text @title }` keeps your own `self` inside the block.
      MD
    end
  end
end
