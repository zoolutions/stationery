# frozen_string_literal: true

module Stationery
  module Layout
    # A node painted at a fixed page position instead of in the flow; it takes
    # up no flow height. Used for page-template headers, footers and
    # backgrounds, and for content that floats over the page.
    class Positioned < Node
      def initialize(node, x:, y:, width: nil)
        super()
        @node = node
        @x = x
        @y = y
        @width = width
      end

      def measure(_width) = 0

      def paint(canvas, _x, _y, width, _height = nil, **)
        width = @width || @node.fixed_width(width) || width
        @node.paint(canvas, @x, @y, width)
        canvas.debug_rect(@x, @y, width, @node.measure(width), :positioned) if canvas.debug?
      end
    end
  end
end
