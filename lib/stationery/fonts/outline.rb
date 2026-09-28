# frozen_string_literal: true

module Stationery
  module Fonts
    # The contours of one glyph in font units, y up as the font has them:
    # moves, lines and cubic curves, every contour closed (a close draws the
    # line back to its move). A TrueType quadratic curve is raised to the
    # cubic it is exactly, with its control points two thirds of the way to
    # the quadratic's, so a reader sees one kind of curve, as a
    # Stationery::Path has. Kept flat like a Path: a kind, then its numbers.
    #
    # #append_to puts a glyph on a page: `outline.append_to(path, x,
    # baseline, size / units_per_em.to_f)`.
    class Outline
      TWO_THIRDS = 2.0 / 3
      WIDTHS = { move: 3, line: 3, curve: 7, close: 1 }.freeze
      private_constant :WIDTHS

      def initialize
        @segments = []
        @x = @y = @start_x = @start_y = 0
      end

      def empty? = @segments.empty?

      # How many kinds and numbers it holds, for the memo that keeps it.
      def size = @segments.size

      def freeze
        @segments.freeze
        super
      end

      def move_to(x, y)
        @segments.push(:move, @start_x = @x = x, @start_y = @y = y)
        self
      end

      def line_to(x, y)
        @segments.push(:line, @x = x, @y = y)
        self
      end

      def curve_to(x1, y1, x2, y2, x, y)
        @segments.push(:curve, x1, y1, x2, y2, @x = x, @y = y)
        self
      end

      # A quadratic Bézier from the current point through the control point
      # (cx, cy) to (x, y), kept as its cubic.
      def quad_to(cx, cy, x, y)
        curve_to(@x + (TWO_THIRDS * (cx - @x)), @y + (TWO_THIRDS * (cy - @y)),
                 x + (TWO_THIRDS * (cx - x)), y + (TWO_THIRDS * (cy - y)), x, y)
      end

      def close
        @segments << :close
        @x = @start_x
        @y = @start_y
        self
      end

      # Yields `:move, x, y`, `:line, x, y`, `:curve, x1, y1, x2, y2, x, y`
      # and `:close`, in font units.
      def each_segment
        return enum_for(:each_segment) unless block_given?

        s = @segments
        i = 0
        while i < s.size
          case s[i]
          when :curve then yield :curve, s[i + 1], s[i + 2], s[i + 3], s[i + 4], s[i + 5], s[i + 6]
          when :close then yield :close
          else yield s[i], s[i + 1], s[i + 2]
          end
          i += WIDTHS.fetch(s[i])
        end
        self
      end

      # Adds the contours to a Stationery::Path with the glyph origin at
      # (x, y) in top-left space and `scale` points per font unit, y flipped.
      # The path's own transform (an oblique shear, a rotation) still applies.
      def append_to(path, x, y, scale)
        s = @segments
        i = 0
        while i < s.size
          case s[i]
          when :move then path.move_to(x + (s[i + 1] * scale), y - (s[i + 2] * scale))
          when :line then path.line_to(x + (s[i + 1] * scale), y - (s[i + 2] * scale))
          when :curve
            path.curve_to(x + (s[i + 1] * scale), y - (s[i + 2] * scale), x + (s[i + 3] * scale),
                          y - (s[i + 4] * scale), x + (s[i + 5] * scale), y - (s[i + 6] * scale))
          else path.close
          end
          i += WIDTHS.fetch(s[i])
        end
        path
      end
    end
  end
end
