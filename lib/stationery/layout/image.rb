# frozen_string_literal: true

module Stationery
  module Layout
    # An image sized by width, height, both, or a box to fit into (aspect
    # preserved), never wider than the space it is given. One pixel is one
    # point when no size is given. `fit: :cover` fills `width:` × `height:`
    # instead, scaling up and clipping the excess around the centre.
    # `radius:` clips to rounded corners and `rotate:` (degrees, clockwise)
    # turns the painted image around the centre of its rectangle; neither
    # changes the space the image takes up.
    class Image < Node
      # `alt:` describes the image in a tagged PDF; `alt: false` marks it decorative.
      def initialize(source, width: nil, height: nil, fit: nil, opacity: nil, alt: nil, radius: 0, rotate: 0)
        raise ArgumentError, "fit: :cover needs width: and height:" if fit == :cover && !(width && height)

        super()
        @tag = alt == false ? nil : Tagging::Element.new(:Figure, alt:, kind: :image)
        @image = source.respond_to?(:build) ? source : Images.load(source)
        @width = width
        @height = height
        @fit = fit
        @opacity = opacity
        @radius = radius
        @rotate = rotate
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
        canvas.tag(@tag, bbox: [x, y, w, h]) do
          canvas.rotate(@rotate, around: [x + (w / 2.0), y + (h / 2.0)]) { paint_clipped(canvas, x, y, w, h) }
        end
        canvas.debug_rect(x, y, w, h, :image)
      end

      private

      def paint_clipped(canvas, x, y, w, h)
        return paint_image(canvas, x, y, w, h) unless @fit == :cover || @radius.positive?

        canvas.clip(x, y, w, h, radius: @radius) { paint_image(canvas, x, y, w, h) }
      end

      def paint_image(canvas, x, y, w, h)
        if @fit == :cover
          scale = [w / @image.width.to_f, h / @image.height.to_f].max
          cw = tidy(@image.width * scale)
          ch = tidy(@image.height * scale)
          x = tidy(x - ((cw - w) / 2.0))
          y = tidy(y - ((ch - h) / 2.0))
          w = cw
          h = ch
        end
        canvas.image(@image, x:, y:, width: w, height: h, opacity: @opacity)
      end

      def requested
        iw = @image.width.to_f
        ih = @image.height.to_f
        if @fit.is_a?(Array)
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
