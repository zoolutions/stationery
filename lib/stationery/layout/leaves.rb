# frozen_string_literal: true

module Stationery
  module Layout
    # A filled horizontal bar: dividers and accent bands.
    class Rule < Node
      def initialize(height: 1, color: "#000000", width: nil, radius: 0)
        super()
        @height = height
        @color = color
        @width = width
        @radius = radius
      end

      def measure(_width) = @height
      def fixed_width(available) = @width && [@width, available].min

      def paint(canvas, x, y, width, _height = nil, **)
        canvas.rounded_rect(x, y, @width || width, @height, radius: @radius, fill: @color)
      end
    end

    # Vertical space. Dropped when it lands on a page break.
    class Spacer < Node
      def initialize(height)
        super()
        @height = height
      end

      def measure(_width) = @height
      def paint(*, **) = nil
    end

    # Forces the content after it onto a new page.
    class PageBreak < Node
      def measure(_width) = 0
      def paint(*, **) = nil
      def page_break? = true
    end

    # Reserves `height` and hands a block the canvas, clipped to the reserved
    # rectangle, and that rectangle in page coordinates.
    class CanvasNode < Node
      def initialize(height:, &block)
        super()
        @height = height
        @block = block
      end

      def measure(_width) = @height

      def paint(canvas, x, y, width, _height = nil, **)
        rect = Rect.new(x, y, width, @height)
        canvas.clip(x, y, width, @height) { @block.call(canvas, rect) }
      end
    end
  end
end
