# frozen_string_literal: true

module Stationery
  module Layout
    # A container with padding, background, border and corner radius. Boxes
    # move to the next page whole. A fixed-height box can truncate or shrink
    # text that does not fit (`overflow:`).
    class Box < Node
      BORDER = { width: 1, color: "#000000", sides: %i[top right bottom left] }.freeze

      attr_reader :content, :width_spec

      def initialize(content = Flow.new, padding: 0, background: nil, border: nil, radius: 0, width: nil,
                     height: nil, overflow: :visible, valign: :top, opacity: nil, link: nil, outset: 0)
        super()
        @link = link
        @outset = Geometry.box(outset)
        @content = content
        @padding = Geometry.box(padding)
        @background = background
        @border = border && BORDER.merge(border)
        @radius = radius
        @width_spec = width
        @height = height
        @overflow = overflow
        @valign = valign
        @opacity = opacity
      end

      def natural_width
        @width_spec.is_a?(Numeric) && @width_spec > 1 ? @width_spec : @content.natural_width + horizontal
      end

      def min_width = @content.min_width + horizontal

      def fixed_width(available)
        case @width_spec
        when :auto then [natural_width, available].min
        when Float then @width_spec <= 1 ? available * @width_spec : @width_spec
        when Numeric then @width_spec
        end
      end

      def measure(width)
        @height || (@content.measure(inner_width(width)) + vertical)
      end

      def paint(canvas, x, y, width, height = nil, valign: nil, debug_kind: :box, **)
        height ||= measure(width)
        paint_background(canvas, x, y, width, height)
        paint_border(canvas, x, y, width, height)
        paint_content(canvas, x, y, width, height, valign || @valign)
        canvas.link(x, y, width, height, @link) if @link
        paint_debug(canvas, Rect.new(x, y, width, height), debug_kind) if canvas.debug?
      end

      private

      def insets
        border = @border ? @border[:width] : 0
        top, right, bottom, left = @padding
        sides = @border ? @border[:sides] : []
        [top + (sides.include?(:top) ? border : 0), right + (sides.include?(:right) ? border : 0),
         bottom + (sides.include?(:bottom) ? border : 0), left + (sides.include?(:left) ? border : 0)]
      end

      def horizontal = insets[1] + insets[3]
      def vertical = insets[0] + insets[2]
      def inner_width(width) = [width - horizontal, 0].max

      # The outset paints the background past the box's own edges (a band that
      # bleeds into the page margins) without moving the content.
      def paint_background(canvas, x, y, width, height)
        return unless @background

        top, right, bottom, left = @outset
        canvas.rounded_rect(x - left, y - top, width + left + right, height + top + bottom,
                            radius: @radius, fill: @background, opacity: @opacity)
      end

      def paint_border(canvas, x, y, width, height)
        return unless @border

        stroke = @border[:width]
        if @border[:sides].size == 4 && @radius.positive?
          half = stroke / 2.0
          canvas.rounded_rect(x + half, y + half, width - stroke, height - stroke,
                              radius: @radius, stroke: @border[:color], line_width: stroke)
        else
          @border[:sides].each { |side| border_side(canvas, side, Rect.new(x, y, width, height), stroke) }
        end
      end

      def border_side(canvas, side, rect, stroke)
        half = stroke / 2.0
        x1, y1, x2, y2 = case side
                         when :top then [rect.x, rect.y + half, rect.right, rect.y + half]
                         when :bottom then [rect.x, rect.bottom - half, rect.right, rect.bottom - half]
                         when :left then [rect.x + half, rect.y, rect.x + half, rect.bottom]
                         else [rect.right - half, rect.y, rect.right - half, rect.bottom]
                         end
        canvas.line(x1, y1, x2, y2, color: @border[:color], width: stroke)
      end

      def paint_content(canvas, x, y, width, height, valign)
        top, _right, _bottom, left = insets
        inner = Rect.new(x, y, width, height).inset(*insets)
        content = fitted(inner)
        used = content.measure(inner.width)
        offset = Geometry.align_offset(if valign == :middle
                                         :center
                                       else
                                         (valign == :bottom ? :right : :left)
                                       end,
                                       inner.height, used)
        paint_inner = -> { content.paint(canvas, x + left, y + top + [offset, 0].max, inner.width) }
        if @overflow == :visible
          paint_inner.call
        else
          canvas.clip(inner.x, inner.y, inner.width, inner.height) do
            paint_inner.call
          end
        end
      end

      def paint_debug(canvas, rect, kind)
        canvas.debug_rect(rect.x, rect.y, rect.width, rect.height, kind)
        return if insets.all?(&:zero?)

        inner = rect.inset(*insets)
        canvas.debug_rect(inner.x, inner.y, inner.width, inner.height, :padding)
      end

      def fitted(inner)
        return @content if @overflow == :visible || @height.nil? || @content.measure(inner.width) <= inner.height
        return shrunk(inner) if @overflow == :shrink_to_fit && shrinkable?

        @content.split(inner.width, inner.height).first || Flow.new
      end

      def shrinkable?
        @content.is_a?(Flow) && @content.children.size == 1 && @content.children.first.respond_to?(:fit)
      end

      def shrunk(inner)
        @content.with_children([@content.children.first.fit(inner.width, inner.height, overflow: :shrink_to_fit)])
      end
    end
  end
end
