# frozen_string_literal: true

module Stationery
  module Fonts
    # Reads the contours of a glyph from the `glyf` table into an Outline.
    #
    # A simple glyph's points are on or off the curve; between two
    # consecutive off-curve points lies an implied on-curve point halfway.
    # A contour starts at its first on-curve point, or, with none, halfway
    # between its last and first points, and runs back to it.
    #
    # A composite glyph places other glyphs, each moved by an offset or by
    # matching one of its points to a point already placed (both read), and
    # scaled by one scale, x and y scales or a 2x2 matrix. The offset is
    # added after the matrix unless SCALED_COMPONENT_OFFSET asks for it to be
    # scaled too. Components nest up to MAX_DEPTH deep; deeper (a glyph that
    # contains itself) raises UnsupportedFont.
    module GlyfOutline
      ON_CURVE = 0x01
      X_SHORT = 0x02
      Y_SHORT = 0x04
      REPEAT = 0x08
      X_SAME = 0x10
      Y_SAME = 0x20

      ARG_1_AND_2_ARE_WORDS = 0x0001
      ARGS_ARE_XY_VALUES = 0x0002
      WE_HAVE_A_SCALE = 0x0008
      MORE_COMPONENTS = 0x0020
      WE_HAVE_AN_X_AND_Y_SCALE = 0x0040
      WE_HAVE_A_TWO_BY_TWO = 0x0080
      SCALED_COMPONENT_OFFSET = 0x0800
      MAX_DEPTH = 8

      # The points of a glyph: x and y by point, whether each is on the
      # curve, and the index of the last point of each contour.
      Points = Data.define(:xs, :ys, :on, :ends)

      module_function

      def read(ttf, gid)
        points = points(ttf, gid, 0)
        outline = Outline.new
        first = 0
        points.ends.each do |last|
          contour(outline, points, first, last)
          first = last + 1
        end
        outline
      end

      def points(ttf, gid, depth)
        data = ttf.glyph_data(gid)
        return Points.new([], [], [], []) if data.bytesize < 10

        contours = data.unpack1("s>")
        contours.negative? ? composite(ttf, gid, data, depth) : simple(data, contours)
      end

      def simple(data, contours)
        ends = data.unpack("n#{contours}", offset: 10)
        count = ends.empty? ? 0 : ends.last + 1
        pos = 10 + (contours * 2)
        pos += 2 + data.unpack1("n", offset: pos)
        flags, pos = flags(data, pos, count)
        xs, pos = coordinates(data, pos, flags, X_SHORT, X_SAME)
        ys, = coordinates(data, pos, flags, Y_SHORT, Y_SAME)
        Points.new(xs, ys, flags.map { |flag| flag.allbits?(ON_CURVE) }, ends)
      end

      def flags(data, pos, count)
        flags = []
        while flags.size < count
          flag = data.getbyte(pos)
          flags << flag
          pos += 1
          next unless flag.allbits?(REPEAT)

          [data.getbyte(pos), count - flags.size].min.times { flags << flag }
          pos += 1
        end
        [flags, pos]
      end

      # A short coordinate is one unsigned byte, its sign in the SAME bit;
      # a long one two signed bytes, or none when SAME repeats the last.
      def coordinates(data, pos, flags, short, same)
        value = 0
        values = flags.map do |flag|
          if flag.allbits?(short)
            delta = data.getbyte(pos)
            value += flag.allbits?(same) ? delta : -delta
            pos += 1
          elsif flag.nobits?(same)
            value += data.unpack1("s>", offset: pos)
            pos += 2
          end
          value
        end
        [values, pos]
      end

      def composite(ttf, gid, data, depth)
        raise UnsupportedFont, "glyph #{gid} nests its components more than #{MAX_DEPTH} deep" if depth >= MAX_DEPTH

        placed = Points.new([], [], [], [])
        pos = 10
        loop do
          flags, component = data.unpack("nn", offset: pos)
          arg1, arg2, matrix, pos = arguments(data, pos + 4, flags)
          points = transform(points(ttf, component, depth + 1), matrix)
          dx, dy = if flags.nobits?(ARGS_ARE_XY_VALUES) then anchor(gid, placed, points, arg1, arg2)
                   elsif matrix && flags.allbits?(SCALED_COMPONENT_OFFSET) then apply(matrix, arg1, arg2)
                   else [arg1, arg2]
                   end
          place(placed, points, dx, dy)
          break if flags.nobits?(MORE_COMPONENTS)
        end
        placed
      end

      # [argument 1, argument 2, the 2x2 matrix or nil, the next position].
      # Arguments are signed offsets, or unsigned point numbers to match.
      def arguments(data, pos, flags)
        xy = flags.allbits?(ARGS_ARE_XY_VALUES)
        if flags.allbits?(ARG_1_AND_2_ARE_WORDS)
          arg1, arg2 = data.unpack(xy ? "s>s>" : "nn", offset: pos)
          pos += 4
        else
          arg1, arg2 = data.unpack(xy ? "cc" : "CC", offset: pos)
          pos += 2
        end
        matrix, pos = matrix(data, pos, flags)
        [arg1, arg2, matrix, pos]
      end

      # [xscale, scale01, scale10, yscale] in F2Dot14, or nil for none.
      def matrix(data, pos, flags)
        if flags.allbits?(WE_HAVE_A_SCALE)
          scale = data.unpack1("s>", offset: pos) / 16_384.0
          [[scale, 0, 0, scale], pos + 2]
        elsif flags.allbits?(WE_HAVE_AN_X_AND_Y_SCALE)
          x, y = data.unpack("s>s>", offset: pos)
          [[x / 16_384.0, 0, 0, y / 16_384.0], pos + 4]
        elsif flags.allbits?(WE_HAVE_A_TWO_BY_TWO)
          [data.unpack("s>4", offset: pos).map { |value| value / 16_384.0 }, pos + 8]
        else
          [nil, pos]
        end
      end

      def transform(points, matrix)
        return points unless matrix

        # x' = xscale*x + scale10*y, y' = scale01*x + yscale*y
        a, b, c, d = matrix
        xs = points.xs.each_index.map { |i| (a * points.xs[i]) + (c * points.ys[i]) }
        ys = points.xs.each_index.map { |i| (b * points.xs[i]) + (d * points.ys[i]) }
        points.with(xs:, ys:)
      end

      # The offset that puts point `theirs` of the component (transformed
      # already) on point `ours` of the glyph so far.
      def anchor(gid, placed, points, ours, theirs)
        unless placed.xs[ours] && points.xs[theirs]
          raise UnsupportedFont, "glyph #{gid} matches point #{ours} to point #{theirs}, which it does not have"
        end

        [placed.xs[ours] - points.xs[theirs], placed.ys[ours] - points.ys[theirs]]
      end

      def apply(matrix, x, y)
        a, b, c, d = matrix
        [(a * x) + (c * y), (b * x) + (d * y)]
      end

      def place(placed, points, dx, dy)
        base = placed.xs.size
        points.ends.each { |last| placed.ends << (base + last) }
        points.xs.each { |x| placed.xs << (x + dx) }
        points.ys.each { |y| placed.ys << (y + dy) }
        placed.on.concat(points.on)
      end

      # One contour, from its first on-curve point round to it again; the
      # line back to the start is left to the close.
      def contour(outline, points, first, last)
        xs = points.xs
        ys = points.ys
        lead = first
        lead += 1 while lead <= last && !points.on[lead]
        if lead > last
          lead = last
          x = 0.5 * (xs[last] + xs[first])
          y = 0.5 * (ys[last] + ys[first])
        else
          x = xs[lead]
          y = ys[lead]
        end
        outline.move_to(x, y)
        off = walk(outline, points, first, last, lead)
        outline.quad_to(xs[off], ys[off], x, y) if off
        outline.close
      end

      # Draws the points after `lead` round to it; answers the off-curve
      # point left pending at the end (only when the contour has no on-curve
      # point). Two off-curve points in a row meet halfway.
      def walk(outline, points, first, last, lead)
        xs = points.xs
        ys = points.ys
        count = last - first + 1
        off = nil
        count.times do |k|
          i = first + ((lead - first + 1 + k) % count)
          if points.on[i]
            if off then outline.quad_to(xs[off], ys[off], xs[i], ys[i])
            elsif k < count - 1 then outline.line_to(xs[i], ys[i])
            end
            off = nil
          else
            outline.quad_to(xs[off], ys[off], 0.5 * (xs[off] + xs[i]), 0.5 * (ys[off] + ys[i])) if off
            off = i
          end
        end
        off
      end
    end
  end
end
