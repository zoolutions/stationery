# frozen_string_literal: true

module Stationery
  module SVG
    # A path sink that measures a shape's bounding box in its own user space,
    # curves by their extrema. Takes the calls Shapes.trace makes on a path.
    class Bounds
      def initialize
        @xs = []
        @ys = []
      end

      def move_to(x, y) = add(x, y)
      def line_to(x, y) = add(x, y)
      def close = self

      def curve_to(x1, y1, x2, y2, x, y)
        x0 = @xs.last || 0
        y0 = @ys.last || 0
        (extrema(x0, x1, x2, x) + extrema(y0, y1, y2, y)).each do |at|
          add(cubic(at, x0, x1, x2, x), cubic(at, y0, y1, y2, y))
        end
        add(x, y)
      end

      def rounded_rect(x, y, w, h, _radius)
        add(x, y)
        add(x + w, y + h)
      end

      def ellipse(cx, cy, rx, ry)
        add(cx - rx, cy - ry)
        add(cx + rx, cy + ry)
      end

      # [x, y, width, height], or nil when the shape has no area.
      def box
        return nil if @xs.empty?

        width = @xs.max - @xs.min
        height = @ys.max - @ys.min
        [@xs.min, @ys.min, width, height] if width.positive? && height.positive?
      end

      private

      def add(x, y)
        @xs << x
        @ys << y
        self
      end

      # Parameters in (0, 1) where the cubic's derivative is zero.
      def extrema(from, first, second, to)
        a = -from + (3 * first) - (3 * second) + to
        b = 2 * (from - (2 * first) + second)
        c = first - from
        roots(a, b, c).select { |t| t.positive? && t < 1 }
      end

      def roots(a, b, c)
        return b.zero? ? [] : [-c.fdiv(b)] if a.zero?

        discriminant = (b**2) - (4 * a * c)
        return [] if discriminant.negative?

        [1, -1].map { |sign| (-b + (sign * Math.sqrt(discriminant))) / (2.0 * a) }
      end

      def cubic(at, from, first, second, to)
        rest = 1 - at
        ((rest**3) * from) + (3 * (rest**2) * at * first) + (3 * rest * (at**2) * second) + ((at**3) * to)
      end
    end
  end
end
