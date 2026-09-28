# frozen_string_literal: true

module Stationery
  module Layout
    class Table < Node
      # One table cell: content (a String, markup String or layout node) and its
      # options, which selections change until the table is laid out.
      class Cell
        SIDES = %i[top right bottom left].freeze
        TEXT_OPTIONS = { size: :size, color: :color, weight: :weight, style: :style, font: :family,
                         letter_spacing: :letter_spacing }.freeze
        BOXES = {} # rubocop:disable Style/MutableConstant

        attr_reader :content, :options, :colspan, :rowspan, :tag, :row_tag

        # `options` is shared with the other cells of a table, which is why a
        # cell copies it before it changes an option of its own.
        def initialize(content, options, colspan: 1, rowspan: 1)
          @content = content
          @options = options
          @colspan = colspan
          @rowspan = rowspan
        end

        def node(context)
          @node ||= @content.is_a?(Node) ? @content : text_node(context)
        end

        # The same cell holding another node, as a row split into two parts needs.
        def with_content(node) = Cell.new(node, @options, colspan:, rowspan:).tagged(@tag, @row_tag)

        # Its TH or TD and its row's TR in a tagged PDF; set once, by the
        # table that first paints or cuts its row.
        def tagged(tag, row_tag)
          @tag ||= tag
          @row_tag ||= row_tag
          self
        end

        # Changes an option and forgets the node built from the old ones.
        def []=(name, value)
          @options = @options.dup unless @own_options
          @own_options = true
          @options[name] = value
          @node = nil
          @padding = nil
          @natural_width = @min_width = @heights = nil
        end

        # A padding of one number is a box every cell with that number shares:
        # a long table holds one Array of it, not one per cell.
        def padding
          @padding ||= if (value = @options[:padding]).is_a?(Numeric)
                         BOXES[value] ||= Geometry.box(value).freeze
                       else
                         Geometry.box(value)
                       end
        end

        def horizontal = padding[1] + padding[3]
        def vertical = padding[0] + padding[2]

        # Heights per width and the natural and minimum widths are remembered:
        # every fragment of a table split across pages measures the same cells.
        def measure(context, width)
          @heights ||= {}
          @heights.fetch(width) { @heights[width] = node(context).measure([width - horizontal, 0].max) + vertical }
        end

        def natural_width(context)
          measure_widths(context) unless @natural_width
          @natural_width
        end

        def min_width(context)
          measure_widths(context) unless @min_width
          @min_width
        end

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

        # Both widths from one node, which the cell lets go of unless it is
        # the cell's content: a long table resolves its columns from every
        # cell, and keeps the text node of none until a page reaches its row.
        def measure_widths(context)
          content = @node || (@content.is_a?(Node) ? @content : text_node(context))
          @natural_width = content.natural_width + horizontal
          @min_width = content.min_width + horizontal
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

        # One path for the cell's border, centred on its edges: the rectangle
        # when all four sides are drawn, else a line per side.
        def paint_borders(canvas, rect)
          width = @options[:border_width]
          return if width.nil? || width.zero?

          sides = Array(@options[:borders]).uniq
          return if sides.empty?

          canvas.path(stroke: @options[:border_color], line_width: width) do |path|
            next path.rect(rect.x, rect.y, rect.width, rect.height) if (SIDES - sides).empty?

            sides.each do |side|
              x1, y1, x2, y2 = edge(side, rect)
              path.move_to(x1, y1)
              path.line_to(x2, y2)
            end
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
