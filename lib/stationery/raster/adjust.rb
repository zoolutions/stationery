# frozen_string_literal: true

module Stationery
  module Raster
    # Stroke adjustment, as poppler (and Acrobat) does it: the parts of a
    # stroke that are rectangles on the pixel grid (a horizontal or vertical
    # line, a square corner) have their edges moved to the nearest pixel
    # edges, a pixel wide at least, so a thin rule is one crisp line rather
    # than two faint ones and is as wide wherever it lands.
    module Adjust
      EPSILON = 1e-6

      module_function

      # Whether `matrix` keeps horizontal lines horizontal.
      def upright?(matrix) = matrix[1].abs < EPSILON && matrix[2].abs < EPSILON

      # The polygons (in pixels) with every rectangle among them adjusted.
      def polygons(polygons)
        polygons.map { |polygon| rectangle?(polygon) ? snap(polygon) : polygon }
      end

      IDENTITY = [1, 0, 0, 1, 0, 0].freeze

      # An upright bitmap's [matrix, box] with the box in pixels, its edges
      # on the nearest pixel edges (a pixel at least), as poppler places
      # one: a one-bit bitmap made at the printer's dots lands dot for dot.
      def picture(matrix, box)
        a, _, _, d, e, f = matrix
        x, y, w, h = box
        return [matrix, box] unless a.positive? && d.positive?

        x0, x1 = edges([(a * x) + e, (a * (x + w)) + e])
        y0, y1 = edges([(d * y) + f, (d * (y + h)) + f])
        [IDENTITY, [x0, y0, x1 - x0, y1 - y0]]
      end

      def rectangle?(polygon)
        return false unless polygon.size == 8

        (0...8).step(2).all? do |i|
          j = (i + 2) % 8
          (polygon[i] - polygon[j]).abs < EPSILON || (polygon[i + 1] - polygon[j + 1]).abs < EPSILON
        end
      end

      def snap(polygon)
        x0, x1 = edges(polygon.values_at(0, 2, 4, 6))
        y0, y1 = edges(polygon.values_at(1, 3, 5, 7))
        [x0, y0, x1, y0, x1, y1, x0, y1]
      end

      def edges(values)
        low = (values.min + 0.5).floor
        high = (values.max + 0.5).floor
        [low, high > low ? high : low + 1]
      end
    end
  end
end
