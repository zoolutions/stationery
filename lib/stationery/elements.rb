# frozen_string_literal: true

module Stationery
  # The element DSL available inside every component's view_template.
  module Elements
    PARAGRAPH_DEFAULTS = { align: :left, leading: 0, orphans: 1, widows: 1 }.freeze

    # A paragraph. Plain strings are always literal; pass `markup: true` to
    # read inline tags, or a block to build styled runs in Ruby. `heading: 1..6`
    # tags it as a heading in a tagged PDF. `orphans:` and `widows:` are the
    # fewest lines a page break may leave behind and carry over (default 1).
    def text(content = nil, markup: false, keep_with_next: nil, break_inside: nil, anchor: nil, bookmark: nil,
             heading: nil, **options, &)
      settings = PARAGRAPH_DEFAULTS.merge(@_builder.text_defaults.slice(:align, :leading, :orphans, :widows))
                                   .merge(options)
      style = @_builder.style(options)
      runs = text_runs(content, style, markup, &)
      node = Layout::Text.new(runs, context: @_builder.context(style), align: settings[:align],
                                    leading: settings[:leading], orphans: settings[:orphans], widows: settings[:widows],
                                    tag: @_builder.element(Tagging.heading(heading)))
      node.keep_with_next = keep_with_next
      node.break_inside = break_inside
      @_builder.add(mark(node, anchor, bookmark))
    end

    # A container with padding, background, border and radius. `at: [x, y]`
    # places it at a fixed page position outside the flow. `role:` (:section,
    # :blockquote, :note, :caption, …) groups its content in a tagged PDF.
    # `break_inside: :auto` splits it at any page break, `:avoid` never; by
    # default it splits only when it does not fit on a page of its own.
    # `float: :left` or `:right` takes it to that side of the flow it is in,
    # `margin:` away from the text that wraps beside it; it needs a `width:`.
    def box(at: nil, align: nil, gap: 0, width: nil, keep_with_next: nil, break_inside: nil, anchor: nil, bookmark: nil,
            float: nil, margin: nil, **, &)
      node = Layout::Box.new(container(align:, gap:, &), width:, tagged: @_builder.tagged?, **)
      node.keep_with_next = keep_with_next
      node.break_inside = break_inside
      node = mark(node, anchor, bookmark)
      return @_builder.add(floated(node, float, margin, at:, width:)) if float || margin

      @_builder.add(at ? Layout::Positioned.new(node, x: at[0], y: at[1], width:) : node)
    end

    # Columns side by side; splits across pages like a box (`break_inside:`).
    def row(gap: 0, align: :top, break_inside: nil)
      columns = Builder::Columns.new
      @_builder.within(columns) { yield if block_given? }
      node = Layout::Row.new(columns.nodes, gap:, align:)
      node.break_inside = break_inside
      @_builder.add(node)
    end

    # A row column: `width:` in points, as a fraction (0.5), :auto or nil for
    # an equal share. Takes every box option.
    def column(width: nil, align: nil, gap: 0, break_inside: nil, **, &)
      node = Layout::Box.new(container(align:, gap:, &), width:, tagged: @_builder.tagged?, **)
      node.break_inside = break_inside
      @_builder.add(node)
    end

    # One flow poured through `count` columns, newspaper style (a `row` is
    # columns side by side with content of their own). `gap:` is the space
    # between columns; `balance: true` ends them at nearly the same height
    # where the content ends, `false` fills each before the next starts;
    # `rule: true | { color:, width: }` draws a line between them. Continues
    # across pages; may hold another `columns`.
    def columns(count: 2, gap: 12, balance: true, rule: nil, align: nil, &)
      @_builder.add(Layout::Columns.new(container(align:, &), count:, gap:, balance:, rule:))
    end

    # A base with layers painted over it: every ordinary child is part of the
    # base (which sets the height), every `layer` floats over it relative to
    # the stack's rectangle, taking no space. The stack moves to the next
    # page whole. Layers may overhang; wrap the stack in `box(padding:)` to
    # keep them inside the page.
    def stack(gap: 0, align: nil, &)
      flow = Layout::Flow.new([], gap:, align: align || :left)
      @_builder.stack(flow) { align ? @_builder.with_text(align:) { yield_content(&) } : yield_content(&) }
      layers, base = flow.children.partition { |child| child.is_a?(Layout::Layer) }
      @_builder.add(Layout::Stack.new(flow.with_children(base), layers))
    end

    # A box placed over the enclosing `stack` by insets from its edges:
    # points, or a fraction (`0.4`, `1/3r`) of the stack's width or height;
    # negative values overhang. Takes every box option (`rotate:`, `shadow:`,
    # `padding:`, `background:`, `radius:`, `height:`, …).
    def layer(top: nil, right: nil, bottom: nil, left: nil, width: nil, height: nil, align: nil, gap: 0, **, &)
      raise ArgumentError, "layer must be inside a stack" unless @_builder.in_stack?

      box = Layout::Box.new(container(align:, gap:, &), tagged: @_builder.tagged?, **)
      @_builder.add(Layout::Layer.new(box, top:, right:, bottom:, left:, width:, height:))
    end

    # Children kept in one vertical group; `keep_together: true` moves the
    # whole group to the next page rather than splitting it.
    def group(gap: 0, align: nil, keep_together: false, keep_with_next: nil, anchor: nil, bookmark: nil, &)
      flow = container(align:, gap:, &)
      flow.break_inside = :avoid if keep_together
      flow.keep_with_next = keep_with_next
      @_builder.add(mark(flow, anchor, bookmark))
    end

    # Children side by side at their own widths, wrapping onto new rows.
    def wrap(gap: 0, row_gap: nil, align: :left, &)
      flow = container(&)
      @_builder.add(Layout::Wrap.new(flow.children, gap:, row_gap: row_gap || gap, align:))
    end

    # An SVG drawing: markup String, or a path to a .svg file. `currentColor`
    # takes `color:`. `alt:` describes it in a tagged PDF (false: decorative).
    def svg(source, width: nil, height: nil, color: "#000000", align: nil, alt: nil)
      name = source.to_s.lstrip.start_with?("<") ? "inline" : File.basename(source.to_s)
      source = File.read(source.to_s) unless name == "inline"
      document = SVG::Document.parse(source)
      svg_warnings(document, name)
      node = Layout::Svg.new(document, width:, height:, color:, context: @_builder.context, alt:)
      @_builder.add(align ? Layout::Flow.new([node], align:) : node)
    end

    # A barcode of `data`: `type:` :code128 (the default), :ean13 or :qr
    # (`level:` :l, :m, :q or :h), drawn as vector bars `module_size:` points a
    # module (1 for a linear one, 2 for a QR code) or as many as fit
    # `width:`, `height:` tall (a linear one; 36 by default), in `color:`,
    # with its quiet zone unless `quiet_zone: false`. `native: true` asks
    # to_zpl to have the printer draw it (see Document#to_zpl). `alt:` as
    # for an image, by default the kind of barcode and its data.
    def barcode(data, type: :code128, level: nil, module_size: nil, width: nil, height: nil, color: "#000000",
                quiet_zone: true, native: nil, align: nil, alt: nil)
      symbol = Barcode.build(type, data, level:)
      node = Layout::Barcode.new(symbol, type:, module_size:, width:, height:,
                                         color:, quiet_zone:, native:, context: @_builder.context, alt:)
      @_builder.add(align ? Layout::Flow.new([node], align:) : node)
    end

    # Cells are strings, layout nodes, procs built with the DSL (`-> { image … }`)
    # or components.
    def table(rows, widths: nil, width: :auto, header: false, split_rows: false, cell: {}, anchor: nil, bookmark: nil,
              &)
      rows = rows.map { |row| row.map { |content| cell_content(content) } }
      node = Layout::Table.new(rows, context: @_builder.context, widths:, width:, header:, split_rows:, cell:, &)
      @_builder.add(mark(node, anchor, bookmark))
    end

    # The document's bookmarks with their page numbers, one linked row each.
    # `levels:` is a Range (or an Integer maximum depth); `leader:` is :dots,
    # :line or nil; text options style the rows.
    def table_of_contents(levels: 1.., leader: :dots, indent: 12, number_width: nil, gap: 4, **options)
      node = Layout::TableOfContents.new(@_builder.outline, context: @_builder.context(@_builder.style(options)),
                                                            levels:, leader:, indent:, number_width:, gap:)
      @_builder.add(node)
    end

    # `alt:` describes the image in a tagged PDF (false: decorative). Sizing,
    # `fit: :cover`, `radius:` and `rotate:` as for Layout::Image. `float:
    # :left` or `:right` takes it to that side of the flow it is in, `margin:`
    # away from the text that wraps beside it (`align:` is then not read).
    def image(source, align: nil, float: nil, margin: nil, **)
      node = Layout::Image.new(source, tagged: @_builder.tagged?, **@_builder.images, **)
      return @_builder.add(floated(node, float, margin)) if float || margin

      @_builder.add(align ? Layout::Flow.new([node], align:) : node)
    end

    def rule(**) = @_builder.add(Layout::Rule.new(**))
    def spacer(height) = @_builder.add(Layout::Spacer.new(height))
    def page_break = @_builder.add(Layout::PageBreak.new)

    # A named link target (`link: "#name"`) at this point; it moves to the
    # next page with whatever follows it.
    def anchor(name) = @_builder.add(Layout::Mark.standalone(name))

    # An outline entry (PDF bookmark) at this point; like a standalone anchor
    # it moves to the next page with whatever follows it.
    def bookmark(title, level: 1, open: false)
      @_builder.add(Layout::Mark.standalone(@_builder.outline.add(title, level:, open:).anchor))
    end

    # Draw directly: the block receives the canvas and the reserved rectangle.
    def canvas(height:, at: nil, width: nil, &)
      node = Layout::CanvasNode.new(height:, &)
      @_builder.add(at ? Layout::Positioned.new(node, x: at[0], y: at[1], width:) : node)
    end

    # Text defaults (font, size, colour, weight, align, leading, …) for a block.
    def text_style(**, &)
      @_builder.with_text(**, &)
    end

    private

    # `margin:` is a number (kept on the sides that face the text) or names
    # the sides as `padding:` does.
    def floated(node, side, margin, at: nil, width: true)
      raise ArgumentError, "margin: is the space around a float: pass float: :left or :right" unless side
      raise ArgumentError, "a box is placed by float: or by at:, not both" if at
      raise ArgumentError, "a floated box needs a width: points, a fraction or :auto" unless width

      Layout::Floated.new(node, side:, margin: margin || 0)
    end

    # What the drawing uses that is not drawn, and nesting that was flattened.
    def svg_warnings(document, name)
      if document.unsupported.any?
        @_builder.warnings << Warnings::UnsupportedSvg.new(elements: document.unsupported, source: name)
      end
      return unless document.nesting

      @_builder.warnings << Warnings::NestingLimit.new(depth: document.nesting, limit: SVG::Parser::MAX_DEPTH)
    end

    # `bookmark:` is a title, or { title:, level:, open: }.
    def mark(node, anchor, bookmark)
      names = [anchor&.to_s]
      names << outline_entry(bookmark).anchor if bookmark
      names.compact!
      names.empty? ? node : Layout::Mark.new(node, names)
    end

    def outline_entry(bookmark)
      return @_builder.outline.add(bookmark) unless bookmark.is_a?(Hash)

      @_builder.outline.add(bookmark.fetch(:title), **bookmark.slice(:level, :open))
    end

    def container(align: nil, gap: 0, &)
      flow = Layout::Flow.new([], gap:, align: align || :left)
      @_builder.within(flow) do
        align ? @_builder.with_text(align:) { yield_content(&) } : yield_content(&)
      end
    end

    # A Hash is a cell with options: `{ content:, background:, borders:, padding:, … }`.
    def cell_content(content)
      case content
      when Proc then container(&content)
      when Component then container { render content }
      when Hash then content.merge(content: cell_content(content[:content]))
      else content
      end
    end

    def text_runs(content, style, markup, &)
      return Text::RunsBuilder.build(style, &) if block_given?
      return Text::Markup.parse(content, style) if markup

      [Text::Run.new(content.to_s, style)]
    end
  end
end
