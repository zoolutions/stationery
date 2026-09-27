# frozen_string_literal: true

module Stationery
  module Layout
    class Table < Node
      # One table cell: content (a String, markup String or layout node) and its
      # options, which selections change until the table is laid out.
      class Cell
        TEXT_OPTIONS = { size: :size, color: :color, weight: :weight, style: :style, font: :family,
                         letter_spacing: :letter_spacing }.freeze

        attr_reader :content, :options, :colspan, :rowspan, :tag, :row_tag

        def initialize(content, options, colspan: 1, rowspan: 1)
          @content = content
          @options = options.dup
          @colspan = colspan
          @rowspan = rowspan
        end

        def node(context)
          @node ||= @content.is_a?(Node) ? @content : text_node(context)
        end

        # The same cell holding another node, as a row split into two parts needs.
        def with_content(node) = Cell.new(node, @options, colspan:, rowspan:).tagged(@tag, @row_tag)

        # Its TH or TD and its row's TR in a tagged PDF; set once, by the
        # table the cell is first laid out in.
        def tagged(tag, row_tag)
          @tag ||= tag
          @row_tag ||= row_tag
          self
        end

        # Changes an option and forgets the node built from the old ones.
        def []=(name, value)
          @options[name] = value
          @node = nil
          @padding = nil
          @metrics = nil
        end

        def padding = @padding ||= Geometry.box(@options[:padding])
        def horizontal = padding[1] + padding[3]
        def vertical = padding[0] + padding[2]

        # Heights per width and the natural and minimum widths are remembered:
        # every fragment of a table split across pages measures the same cells.
        def measure(context, width) = metric(width) { node(context).measure([width - horizontal, 0].max) + vertical }
        def natural_width(context) = metric(:natural) { node(context).natural_width + horizontal }
        def min_width(context) = metric(:min) { node(context).min_width + horizontal }

        # Backgrounds overlap the next cell by SEAM so viewers do not show
        # hairline gaps between neighbouring fills.
        SEAM = 0.5

        def paint(canvas, context, rect, last_column: true, last_row: true)
          if @options[:background]
            canvas.fill_rect(rect.x, rect.y, rect.width + (last_column ? 0 : SEAM),
                             rect.height + (last_row ? 0 : SEAM), color: @options[:background])
          end
          paint_content(canvas, context, rect)
          paint_borders(canvas, rect)
          paint_debug(canvas, rect) if canvas.debug?
        end

        private

        def metric(key)
          @metrics ||= {}
          @metrics.fetch(key) { @metrics[key] = yield }
        end

        def text_node(context)
          style = context.style.with(**TEXT_OPTIONS.filter_map do |key, attr|
            [attr, @options[key]] if @options.key?(key)
          end.to_h)
          source = @content.to_s
          runs = if @options[:markup]
                   ::Stationery::Text::Markup.parse(source, style)
                 else
                   [::Stationery::Text::Run.new(source, style)]
                 end
          Text.new(runs, context: context.with(style:), align: @options[:align] || :left,
                         leading: @options[:leading] || 0)
        end

        def paint_content(canvas, context, rect)
          inner = rect.inset(*padding)
          content = node(context)
          used = content.measure(inner.width)
          valign = { middle: :center, bottom: :right }.fetch(@options[:valign], :left)
          offset = [Geometry.align_offset(valign, inner.height, used), 0].max
          own = content.fixed_width(inner.width)
          left = own ? inner.x + Geometry.align_offset(@options[:align] || :left, inner.width, own) : inner.x
          content.paint(canvas, left, inner.y + offset, own || inner.width)
        end

        def paint_debug(canvas, rect)
          canvas.debug_rect(rect.x, rect.y, rect.width, rect.height, :cell)
          inner = rect.inset(*padding)
          canvas.debug_rect(inner.x, inner.y, inner.width, inner.height, :cell_padding)
        end

        def paint_borders(canvas, rect)
          width = @options[:border_width]
          return if width.nil? || width.zero?

          color = @options[:border_color]
          Array(@options[:borders]).each do |side|
            x1, y1, x2, y2 = edge(side, rect)
            canvas.line(x1, y1, x2, y2, color:, width:)
          end
        end

        def edge(side, rect)
          case side
          when :top then [rect.x, rect.y, rect.right, rect.y]
          when :bottom then [rect.x, rect.bottom, rect.right, rect.bottom]
          when :left then [rect.x, rect.y, rect.x, rect.bottom]
          else [rect.right, rect.y, rect.right, rect.bottom]
          end
        end
      end
    end
  end
end
