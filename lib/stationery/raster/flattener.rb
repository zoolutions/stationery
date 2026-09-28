# frozen_string_literal: true

module Stationery
  module Raster
    # A path (anything answering #each_segment as Stationery::Path does) as
    # polylines, `[[x, y, x, y, …], closed], …` one per subpath, with every
    # point put through `matrix` (none for as they are). A cubic curve is cut
    # into as many lines as keep it within `tolerance` of the true curve,
    # measured after the matrix: the bound on how far a Bézier strays from
    # its chord that the second differences of its points give.
    module Flattener
      MAX_PIECES = 256

      module_function

      def polylines(path, matrix, tolerance)
        a, b, c, d, e, f = matrix || [1, 0, 0, 1, 0, 0]
        lines = []
        points = nil
        start_x = start_y = x = y = 0.0
        path.each_segment do |kind, *numbers|
          case kind
          when :move
            lines << [points, false] if points && points.size > 2
            x = start_x = (a * numbers[0]) + (c * numbers[1]) + e
            y = start_y = (b * numbers[0]) + (d * numbers[1]) + f
            points = [x, y]
          when :line
            points ||= [x, y]
            x = (a * numbers[0]) + (c * numbers[1]) + e
            y = (b * numbers[0]) + (d * numbers[1]) + f
            points.push(x, y)
          when :curve
            points ||= [x, y]
            x1 = (a * numbers[0]) + (c * numbers[1]) + e
            y1 = (b * numbers[0]) + (d * numbers[1]) + f
            x2 = (a * numbers[2]) + (c * numbers[3]) + e
            y2 = (b * numbers[2]) + (d * numbers[3]) + f
            x3 = (a * numbers[4]) + (c * numbers[5]) + e
            y3 = (b * numbers[4]) + (d * numbers[5]) + f
            curve(points, x, y, x1, y1, x2, y2, x3, y3, tolerance)
            x = x3
            y = y3
          when :close
            if points
              lines << [points, true]
              points = nil
            end
            x = start_x
            y = start_y
          end
        end
        lines << [points, false] if points && points.size > 2
        lines
      end

      # Adds the lines of the curve from (x0, y0) to (x3, y3), not its start.
      def curve(points, x0, y0, x1, y1, x2, y2, x3, y3, tolerance) # rubocop:disable Metrics/ParameterLists
        ddx = [(x0 - (2 * x1) + x2).abs, (x1 - (2 * x2) + x3).abs].max
        ddy = [(y0 - (2 * y1) + y2).abs, (y1 - (2 * y2) + y3).abs].max
        pieces = Math.sqrt(0.75 * Math.sqrt((ddx * ddx) + (ddy * ddy)) / tolerance).ceil.clamp(1, MAX_PIECES)
        (1...pieces).each do |i|
          t = i.fdiv(pieces)
          u = 1 - t
          a = u * u * u
          b = 3 * u * u * t
          c = 3 * u * t * t
          d = t * t * t
          points.push((a * x0) + (b * x1) + (c * x2) + (d * x3), (a * y0) + (b * y1) + (c * y2) + (d * y3))
        end
        points.push(x3, y3)
      end
    end
  end
end
