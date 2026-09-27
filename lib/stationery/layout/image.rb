# frozen_string_literal: true

module Stationery
  module Layout
    # An image sized by width, height, both, or a box to fit into (aspect
    # preserved), never wider than the space it is given. One pixel is one
    # point when no size is given.
    class Image < Node
      def initialize(source, width: nil, height: nil, fit: nil, opacity: nil)
        super()
        @image = source.respond_to?(:build) ? source : Images.load(source)
        @width = width
        @height = height
        @fit = fit
        @opacity = opacity
      end

      def size(available)
        width, height = requested
        return [width, height] if width <= available

        [available, height * available / width]
      end

      def measure(width) = size(width)[1]
      def fixed_width(available) = size(available)[0]
      def natural_width = requested[0]
      def min_width = 0

      def paint(canvas, x, y, width, _height = nil, **)
        w, h = size(width)
        canvas.image(@image, x:, y:, width: w, height: h, opacity: @opacity)
        canvas.debug_rect(x, y, w, h, :image)
      end

      private

      def requested
        iw = @image.width.to_f
        ih = @image.height.to_f
        if @fit
          scale = [@fit[0] / iw, @fit[1] / ih].min
          [iw * scale, ih * scale].map { |v| tidy(v) }
        elsif @width && @height then [@width, @height]
        elsif @width then [@width, tidy(ih * @width / iw)]
        elsif @height then [tidy(iw * @height / ih), @height]
        else [@image.width, @image.height]
        end
      end

      def tidy(value) = value.round(6)
    end
  end
end
