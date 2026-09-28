# frozen_string_literal: true

module Stationery
  module Raster
    # The outline of a stroke as polygons, as PDF strokes a path: a
    # rectangle along each line `width` wide, a join where two meet (a
    # miter, cut to a bevel when it is longer than `miter_limit` times the
    # width; a round; a bevel), a cap at each end of an open polyline (butt,
    # square or round) and the dashes of `dash` (lengths on and off in turn,
    # repeated; an odd count is repeated twice). Every polygon runs the same
    # way round, so under the nonzero rule their union is the stroke.
    #
    # Polylines are `[[x, y, x, y, …], closed]` as Flattener answers them,
    # in the space the width is in; `tolerance` is how far a round may
    # stray, in that space.
    class Stroker
      EPSILON = 1e-9

      def initialize(width:, cap: :butt, join: :miter, dash: nil, miter_limit: 10, tolerance: 0.1)
        @half = width / 2.0
        @cap = cap || :butt
        @join = join || :miter
        @dash = dash_pattern(dash)
        @limit = miter_limit
        @tolerance = tolerance
      end

      def polygons(polylines)
        out = []
        polylines.each do |points, closed|
          points = distinct(points, closed)
          pieces = @dash ? dashes(points, closed) : [[points, closed]]
          pieces.each { |piece, shut| stroke(piece, shut, out) }
        end
        out.each { |polygon| clockwise(polygon) }
      end

      private

      def stroke(points, closed, out)
        closed = false if points.size < 6
        return dot(points[0], points[1], out) if points.size == 2

        count = points.size / 2
        last = closed ? count : count - 1
        (0...last).each do |i|
          j = (i + 1) % count
          segment(points[i * 2], points[(i * 2) + 1], points[j * 2], points[(j * 2) + 1], out)
        end
        (closed ? (0...count) : (1...(count - 1))).each { |i| join(points, i, count, out) }
        caps(points, out) unless closed
      end

      def segment(x0, y0, x1, y1, out)
        nx, ny = normal(x0, y0, x1, y1)
        out << [x0 + nx, y0 + ny, x1 + nx, y1 + ny, x1 - nx, y1 - ny, x0 - nx, y0 - ny]
      end

      # The join at point `i` between the line into it and the line out.
      def join(points, i, count, out)
        x = points[i * 2]
        y = points[(i * 2) + 1]
        before = (i - 1) % count
        after = (i + 1) % count
        ux0, uy0 = unit(points[before * 2], points[(before * 2) + 1], x, y)
        ux1, uy1 = unit(x, y, points[after * 2], points[(after * 2) + 1])
        cross = (ux0 * uy1) - (uy0 * ux1)
        dot = (ux0 * ux1) + (uy0 * uy1)
        return if cross.abs < EPSILON && dot.positive?
        return out << circle(x, y) if @join == :round

        side = cross.positive? ? -@half : @half
        ax = x - (uy0 * side)
        ay = y + (ux0 * side)
        bx = x - (uy1 * side)
        by = y + (ux1 * side)
        ratio = 1 / Math.sqrt([(1 + dot) / 2, EPSILON].max)
        if @join == :miter && ratio <= @limit
          mx = -(uy0 + uy1)
          my = ux0 + ux1
          length = Math.sqrt((mx * mx) + (my * my))
          reach = side * ratio / length
          out << [x, y, ax, ay, x + (mx * reach), y + (my * reach), bx, by]
        else
          out << [x, y, ax, ay, bx, by]
        end
      end

      def caps(points, out)
        return if @cap == :butt

        n = points.size
        cap(points[0], points[1], points[2], points[3], out)
        cap(points[n - 2], points[n - 1], points[n - 4], points[n - 3], out)
      end

      # The cap at (x, y), the end of the line from (ox, oy)'s side.
      def cap(x, y, ox, oy, out)
        return out << circle(x, y) if @cap == :round

        ux, uy = unit(ox, oy, x, y)
        nx = -uy * @half
        ny = ux * @half
        ex = ux * @half
        ey = uy * @half
        out << [x + nx, y + ny, x + nx + ex, y + ny + ey, x - nx + ex, y - ny + ey, x - nx, y - ny]
      end

      # A line of no length: a round dot with round caps, else nothing.
      def dot(x, y, out)
        out << circle(x, y) if @cap == :round
      end

      # A polygon of as many sides as keep it within the tolerance of the
      # circle, a little wider than it so that it covers the circle's area.
      def circle(x, y)
        steps = (Math::PI / Math.acos((1 - (@tolerance / @half)).clamp(-1.0, 1.0))).ceil.clamp(8, 96)
        radius = @half * Math.sqrt(Math::PI / (steps / 2.0 * Math.sin(2 * Math::PI / steps)))
        Array.new(steps) do |i|
          angle = 2 * Math::PI * i / steps
          [x + (radius * Math.cos(angle)), y + (radius * Math.sin(angle))]
        end.flatten
      end

      def normal(x0, y0, x1, y1)
        ux, uy = unit(x0, y0, x1, y1)
        [-uy * @half, ux * @half]
      end

      def unit(x0, y0, x1, y1)
        dx = x1 - x0
        dy = y1 - y0
        length = Math.sqrt((dx * dx) + (dy * dy))
        length < EPSILON ? [1.0, 0.0] : [dx / length, dy / length]
      end

      # The points without one that repeats the point before it (or, closed,
      # a last one that repeats the first).
      def distinct(points, closed)
        out = [points[0], points[1]]
        (2...points.size).step(2) do |i|
          x = points[i]
          y = points[i + 1]
          out.push(x, y) unless (x - out[-2]).abs < EPSILON && (y - out[-1]).abs < EPSILON
        end
        out.pop(2) if closed && out.size > 2 && (out[-2] - out[0]).abs < EPSILON && (out[-1] - out[1]).abs < EPSILON
        out
      end

      def dash_pattern(dash)
        return unless dash&.any?(&:positive?)

        dash.size.odd? ? dash * 2 : dash
      end

      # The dashes of a polyline, open polylines each.
      def dashes(points, closed)
        points += points.first(2) if closed
        pieces = []
        index = 0
        left = @dash[0]
        on = true
        current = [points[0], points[1]]
        (2...points.size).step(2) do |i|
          x0 = points[i - 2]
          y0 = points[i - 1]
          x1 = points[i]
          y1 = points[i + 1]
          length = Math.sqrt(((x1 - x0)**2) + ((y1 - y0)**2))
          travelled = 0.0
          while length - travelled > left
            travelled += left
            t = travelled / length
            x = x0 + ((x1 - x0) * t)
            y = y0 + ((y1 - y0) * t)
            if on
              current.push(x, y)
              pieces << [current, false]
            else
              current = [x, y]
            end
            on = !on
            index = (index + 1) % @dash.size
            left = @dash[index]
          end
          left -= length - travelled
          current.push(x1, y1) if on
        end
        pieces << [current, false] if on
        pieces
      end

      # Turns the polygon to run clockwise on a page (y down), in place.
      def clockwise(polygon)
        area = 0.0
        n = polygon.size
        (0...n).step(2) do |i|
          j = (i + 2) % n
          area += (polygon[i] * polygon[j + 1]) - (polygon[j] * polygon[i + 1])
        end
        return polygon unless area.negative?

        reversed = polygon.each_slice(2).to_a.reverse.flatten
        polygon.replace(reversed)
      end
    end
  end
end
