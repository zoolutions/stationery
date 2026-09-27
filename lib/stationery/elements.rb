# frozen_string_literal: true

module Stationery
  # The element DSL available inside every component's view_template.
  module Elements
    PARAGRAPH_DEFAULTS = { align: :left, leading: 0 }.freeze

    # A paragraph. Plain strings are always literal; pass `markup: true` to
    # read inline tags, or a block to build styled runs in Ruby.
    def text(content = nil, markup: false, keep_with_next: nil, break_inside: nil, **options, &)
      settings = PARAGRAPH_DEFAULTS.merge(@_builder.text_defaults.slice(:align, :leading)).merge(options)
      style = @_builder.style(options)
      runs = text_runs(content, style, markup, &)
      node = Layout::Text.new(runs, context: @_builder.context(style), align: settings[:align],
                                    leading: settings[:leading])
      node.keep_with_next = keep_with_next
      node.break_inside = break_inside
      @_builder.add(node)
    end

    # A container with padding, background, border and radius. `at: [x, y]`
    # places it at a fixed page position outside the flow.
    def box(at: nil, align: nil, gap: 0, width: nil, keep_with_next: nil, **, &)
      node = Layout::Box.new(container(align:, gap:, &), width:, **)
      node.keep_with_next = keep_with_next
      @_builder.add(at ? Layout::Positioned.new(node, x: at[0], y: at[1], width:) : node)
    end

    def row(gap: 0, align: :top)
      columns = Builder::Columns.new
      @_builder.within(columns) { yield if block_given? }
      @_builder.add(Layout::Row.new(columns.nodes, gap:, align:))
    end

    # A row column: `width:` in points, as a fraction (0.5), :auto or nil for
    # an equal share. Takes every box option.
    def column(width: nil, align: nil, gap: 0, **, &)
      @_builder.add(Layout::Box.new(container(align:, gap:, &), width:, **))
    end

    # Children kept in one vertical group; `keep_together: true` moves the
    # whole group to the next page rather than splitting it.
    def group(gap: 0, align: nil, keep_together: false, keep_with_next: nil, &)
      flow = container(align:, gap:, &)
      flow.break_inside = :avoid if keep_together
      flow.keep_with_next = keep_with_next
      @_builder.add(flow)
    end

    # Children side by side at their own widths, wrapping onto new rows.
    def wrap(gap: 0, row_gap: nil, align: :left, &)
      flow = container(&)
      @_builder.add(Layout::Wrap.new(flow.children, gap:, row_gap: row_gap || gap, align:))
    end

    # An SVG drawing: markup String, or a path to a .svg file. `currentColor`
    # takes `color:`.
    def svg(source, width: nil, height: nil, color: "#000000", align: nil)
      source = File.read(source.to_s) unless source.to_s.lstrip.start_with?("<")
      node = Layout::Svg.new(SVG::Document.parse(source), width:, height:, color:)
      @_builder.add(align ? Layout::Flow.new([node], align:) : node)
    end

    # Cells are strings, layout nodes, procs built with the DSL (`-> { image … }`)
    # or components.
    def table(rows, widths: nil, width: :auto, header: false, cell: {}, &)
      rows = rows.map { |row| row.map { |content| cell_content(content) } }
      @_builder.add(Layout::Table.new(rows, context: @_builder.context, widths:, width:, header:, cell:, &))
    end

    def image(source, align: nil, **)
      node = Layout::Image.new(source, **)
      @_builder.add(align ? Layout::Flow.new([node], align:) : node)
    end

    def rule(**) = @_builder.add(Layout::Rule.new(**))
    def spacer(height) = @_builder.add(Layout::Spacer.new(height))
    def page_break = @_builder.add(Layout::PageBreak.new)

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

    def container(align: nil, gap: 0, &)
      flow = Layout::Flow.new([], gap:, align: align || :left)
      @_builder.within(flow) do
        align ? @_builder.with_text(align:) { yield_content(&) } : yield_content(&)
      end
    end

    def cell_content(content)
      case content
      when Proc then container(&content)
      when Component then container { render content }
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
