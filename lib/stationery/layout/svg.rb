# frozen_string_literal: true

module Stationery
  module Layout
    # A vector drawing at a fixed size: `width:` and/or `height:` (the other
    # follows the viewBox's aspect ratio), never wider than the space given.
    class Svg < Node
      # `context` gives SVG text its font book and default family.
      def initialize(document, width: nil, height: nil, color: "#000000", context: nil)
        super()
        @document = document
        @context = context
        @width = width
        @height = height
        @color = color
      end

      def size(available)
        width, height = requested
        return [width, height] if width <= available

        [available, height * available / width]
      end

      def measure(width) = size(width)[1]
      def fixed_width(available) = size(available)[0]
      def natural_width = requested[0]

      def paint(canvas, x, y, width, _height = nil, **)
        w, h = size(width)
        @document.draw(canvas, x:, y:, width: w, height: h, color: @color, book: @context&.book,
                               family: @context&.style&.family)
        canvas.debug_rect(x, y, w, h, :image)
      end

      private

      def requested
        aspect = @document.aspect
        if @width && @height then [@width, @height]
        elsif @width then [@width, @width / aspect]
        elsif @height then [@height * aspect, @height]
        else @document.view_box.last(2)
        end
      end
    end
  end
end
