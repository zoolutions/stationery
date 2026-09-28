# frozen_string_literal: true

module Stationery
  module Raster
    # The colour of a bitmap (Images::Pixels) drawn into the rectangle `x`,
    # `y`, `width`, `height` of user space, at each pixel of the surface:
    # `inverse` takes a pixel back into user space, where the bitmap is read
    # as poppler reads it: between its four nearest pixels (`smooth:`, for a
    # bitmap enlarged less than four times) or at the nearest one. A bitmap
    # bigger than the pixels it covers is first scaled down by averaging
    # (see Painter).
    class Picture
      def initialize(pixels, inverse, rect, channels, smooth: false)
        @pixels = pixels
        @inverse = inverse
        @x, @y, @width, @height = rect
        @channels = channels
        @smooth = smooth
      end

      # [sample, …, alpha] at pixel (x, y), nil outside the bitmap.
      def color_at(x, y)
        a, b, c, d, e, f = @inverse
        px = x + 0.5
        py = y + 0.5
        u = ((a * px) + (c * py) + e - @x) / @width * @pixels.width
        v = ((b * px) + (d * py) + f - @y) / @height * @pixels.height
        return if u.negative? || v.negative? || u >= @pixels.width || v >= @pixels.height

        @smooth ? between(u - 0.5, v - 0.5) : sample(u.floor, v.floor)
      end

      private

      # The four pixels around (u, v), each weighed by how near it is.
      def between(u, v)
        u0 = u.floor
        v0 = v.floor
        fu = u - u0
        fv = v - v0
        last_u = @pixels.width - 1
        last_v = @pixels.height - 1
        u0c = u0.clamp(0, last_u)
        u1c = (u0 + 1).clamp(0, last_u)
        v0c = v0.clamp(0, last_v)
        v1c = (v0 + 1).clamp(0, last_v)
        top = mix(sample(u0c, v0c), sample(u1c, v0c), fu)
        mix(top, mix(sample(u0c, v1c), sample(u1c, v1c), fu), fv)
      end

      def mix(left, right, share) = left.each_index.map { |i| left[i] + ((right[i] - left[i]) * share) }

      def sample(u, v) = color(u, v) << (@pixels.alpha ? @pixels.alpha[v][u] / 255.0 : 1.0)

      def color(u, v)
        row = @pixels.color[v]
        if @pixels.channels == 1
          grey = row[u]
          @channels == 1 ? [grey] : [grey, grey, grey]
        else
          r = row[u * 3]
          g = row[(u * 3) + 1]
          b = row[(u * 3) + 2]
          @channels == 1 ? [((299 * r) + (587 * g) + (114 * b)) / 1000] : [r, g, b]
        end
      end
    end
  end
end
