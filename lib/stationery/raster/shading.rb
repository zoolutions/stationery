# frozen_string_literal: true

module Stationery
  module Raster
    # The colour of a gradient (an SVG::Gradient::Fill) at each pixel, as a
    # PDF axial (type 2) or radial (type 3) shading with both ends extended
    # paints it: `inverse` takes a pixel back into the gradient's space,
    # where a linear gradient runs from (x1, y1) to (x2, y2) and a radial one
    # from the circle (fx, fy, 0) to (cx, cy, r). Colours come from a table
    # of STEPS along the stops, turned into samples by `convert`.
    class Shading
      STEPS = 256

      def initialize(fill, inverse, convert)
        @kind = fill.kind
        @coords = fill.coords.map(&:to_f)
        @inverse = inverse
        @table = table(fill.stops, convert)
      end

      # [sample, …, 1.0] at pixel (x, y), nil where the gradient paints nothing.
      def color_at(x, y)
        a, b, c, d, e, f = @inverse
        px = x + 0.5
        py = y + 0.5
        t = at((a * px) + (c * py) + e, (b * px) + (d * py) + f)
        t && @table[(t.clamp(0.0, 1.0) * (STEPS - 1)).round]
      end

      private

      def at(x, y) = @kind == :radial ? radial(x, y) : linear(x, y)

      def linear(x, y)
        x1, y1, x2, y2 = @coords
        dx = x2 - x1
        dy = y2 - y1
        length = (dx * dx) + (dy * dy)
        return 0.0 if length.zero?

        (((x - x1) * dx) + ((y - y1) * dy)) / length
      end

      # The largest s whose circle, between the two, passes through the point.
      def radial(x, y)
        x0, y0, r0, x1, y1, r1 = @coords
        cx = x1 - x0
        cy = y1 - y0
        dr = r1 - r0
        px = x - x0
        py = y - y0
        a = (cx * cx) + (cy * cy) - (dr * dr)
        b = (px * cx) + (py * cy) + (r0 * dr)
        c = (px * px) + (py * py) - (r0 * r0)
        return c / (2 * b) if a.abs < 1e-9 && b.abs > 1e-12
        return if a.abs < 1e-9

        root = (b * b) - (a * c)
        return if root.negative?

        [(b + Math.sqrt(root)) / a, (b - Math.sqrt(root)) / a].select { |s| r0 + (s * dr) >= 0 }.max
      end

      def table(stops, convert)
        Array.new(STEPS) do |i|
          t = i.fdiv(STEPS - 1)
          after = stops.index { |offset, _| offset >= t } || (stops.size - 1)
          before = [after - 1, 0].max
          span = stops[after][0] - stops[before][0]
          share = span.positive? ? (t - stops[before][0]) / span : 1.0
          rgb = stops[before][1].zip(stops[after][1]).map { |from, to| from + ((to - from) * share) }
          [*convert.call(rgb), 1.0]
        end
      end
    end
  end
end
