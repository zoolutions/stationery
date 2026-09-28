# frozen_string_literal: true

module Stationery
  module Monochrome
    # A printer's dot grid at `dpi`, from the top left corner of the page, in
    # points. A printer prints a dot or none: a line whose edges fall between
    # dots prints one dot wide here and two there, so rules and borders are
    # given edges on the grid and widths of whole dots. That is done for
    # what rules and borders are, axis-aligned rectangles and horizontal and
    # vertical lines; a curve or a slanted line is left where it is.
    #
    # Paths are read and written as Path#each_segment gives them:
    # `[:move, x, y]`, `[:line, x, y]`, `:close`.
    class Grid
      EPSILON = 1e-6

      attr_reader :dot

      def initialize(dpi)
        @dot = 72.0 / dpi
      end

      # How many whole dots `length` comes to.
      def dots(length) = (length / @dot).round

      # `value` on the nearest line of the grid.
      def edge(value) = (value / @dot).round * @dot

      # Where the centre of a stroke `count` dots wide goes, near `value`, for
      # both its edges to be on the grid.
      def centre(value, count)
        half = count / 2.0
        (((value / @dot) - half).round + half) * @dot
      end

      # [x, y, w, h] on the grid: the corner on the nearest dot and each side
      # a whole number of dots, one at least, so a rule is as wide wherever
      # it lands.
      def rect(x, y, w, h)
        [edge(x), edge(y), [dots(w), 1].max * @dot, [dots(h), 1].max * @dot]
      end

      # [x, y, w, h] of `segments` when they are one axis-aligned rectangle,
      # else nil.
      def rectangle(segments)
        points = polygon(segments)
        return unless points&.size == 4 && rectilinear?(points, closed: true)

        xs = points.map(&:first)
        ys = points.map(&:last)
        [xs.min, ys.min, xs.max - xs.min, ys.max - ys.min]
      end

      # `segments` stroked `count` dots wide with their edges on the grid: a
      # coordinate a horizontal or vertical line runs along is the centre of
      # the stroke, any other (the end of a line) is an edge. Nil when a
      # segment is not a horizontal or vertical line.
      def stroke(segments, count)
        return unless segments.all? { |segment| segment == :close || segment[0] != :curve }

        runs = runs(segments)
        return unless runs

        segments.map do |segment|
          next segment if segment == :close

          kind, x, y = segment
          along_x, along_y = runs.shift
          [kind, along_x ? centre(x, count) : edge(x), along_y ? centre(y, count) : edge(y)]
        end
      end

      private

      # The corners of a single closed subpath of lines, else nil.
      def polygon(segments)
        return unless segments.first.is_a?(Array) && segments.first[0] == :move && segments.last == :close
        return unless segments[1...-1].all? { |segment| segment.is_a?(Array) && segment[0] == :line }

        points = segments[0...-1].map { |_, x, y| [x, y] }
        points.pop if points.size > 1 && same?(points.first, points.last)
        points
      end

      # For each point of `segments`, whether a vertical line runs through it
      # (its x is a stroke's centre) and whether a horizontal one does; nil
      # when a line is neither.
      def runs(segments)
        flags = []
        start = previous = nil
        joined = segments.all? do |segment|
          if segment == :close
            closed = start && join(flags, previous, start)
            previous = start
            next closed
          end

          kind, x, y = segment
          flags << [false, false]
          point = [x, y, flags.size - 1]
          start = point if kind == :move
          straight = kind == :move || join(flags, previous, point)
          previous = point
          straight
        end
        flags if joined
      end

      # Marks the line from `from` to `to`; false when it is slanted.
      def join(flags, from, to)
        return false unless from

        dx = (to[0] - from[0]).abs
        dy = (to[1] - from[1]).abs
        return true if dx < EPSILON && dy < EPSILON
        return false if dx >= EPSILON && dy >= EPSILON

        axis = dx < EPSILON ? 0 : 1
        flags[from[2]][axis] = flags[to[2]][axis] = true
      end

      def rectilinear?(points, closed:)
        edges = points.each_cons(2).to_a
        edges << [points.last, points.first] if closed
        edges.all? { |a, b| (a[0] - b[0]).abs < EPSILON || (a[1] - b[1]).abs < EPSILON }
      end

      def same?(a, b) = (a[0] - b[0]).abs < EPSILON && (a[1] - b[1]).abs < EPSILON
    end
  end
end
