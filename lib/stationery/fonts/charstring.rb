# frozen_string_literal: true

module Stationery
  module Fonts
    # Runs a Type 2 charstring, the glyph program of a CFF font, into an
    # Outline: every path operator, flex included, with a contour closed at
    # the next moveto and at endchar. Hints are skipped: the stems are only
    # counted, to know how many bytes each hintmask and cntrmask carries (the
    # operands in front of the first hintmask count as vstems). The advance
    # width in front of the first stack-clearing operator is dropped.
    # Subroutines are called through the bias the count of their INDEX sets.
    #
    # Refused with UnsupportedFont: the deprecated seac form of endchar (an
    # accent built from two standard-encoded glyphs), the arithmetic and
    # storage operators, which no OpenType CFF font is known to need, and
    # subroutines nested more than MAX_DEPTH deep.
    class Charstring
      MAX_DEPTH = 10
      STEMS = [1, 3, 18, 23].freeze
      OPERATORS = {
        4 => :vmoveto, 5 => :rlineto, 6 => :hlineto, 7 => :vlineto, 8 => :rrcurveto, 14 => :endchar,
        21 => :rmoveto, 22 => :hmoveto, 24 => :rcurveline, 25 => :rlinecurve, 26 => :vvcurveto,
        27 => :hhcurveto, 30 => :vhcurveto, 31 => :hvcurveto,
        1200 => :dotsection, 1234 => :hflex, 1235 => :flex, 1236 => :hflex1, 1237 => :flex1
      }.freeze

      # `global_subrs` and `local_subrs` are CFF::Index structures over
      # `data` (local ones nil when the Private DICT has none).
      def initialize(data, global_subrs, local_subrs)
        @data = data
        @global_subrs = global_subrs
        @local_subrs = local_subrs
      end

      def outline(offset, length)
        @outline = Outline.new
        @stack = []
        @stems = 0
        @x = @y = 0
        @width = @open = @done = false
        run(offset, offset + length, 0)
        close_contour
        @outline
      end

      private

      def run(pos, stop, depth)
        raise UnsupportedFont, "charstring subroutines nest more than #{MAX_DEPTH} deep" if depth > MAX_DEPTH

        while pos < stop && !@done
          b0 = @data.getbyte(pos)
          if b0 >= 32 || b0 == 28
            pos = number(b0, pos)
            next
          end

          op = b0 == 12 ? 1200 + @data.getbyte(pos + 1) : b0
          pos += b0 == 12 ? 2 : 1
          case op
          when 11 then return
          when 10 then call(@local_subrs, depth)
          when 29 then call(@global_subrs, depth)
          when 19, 20 then pos = mask(pos)
          else operator(op)
          end
        end
      end

      # Pushes the number at `pos` and answers the position after it.
      def number(byte, pos)
        if byte == 28
          @stack << @data.unpack1("s>", offset: pos + 1)
          pos + 3
        elsif byte <= 246
          @stack << (byte - 139)
          pos + 1
        elsif byte == 255 # 16.16 fixed
          @stack << (@data.unpack1("l>", offset: pos + 1) / 65_536.0)
          pos + 5
        else
          low = @data.getbyte(pos + 1)
          @stack << (byte <= 250 ? ((byte - 247) * 256) + low + 108 : -((byte - 251) * 256) - low - 108)
          pos + 2
        end
      end

      def operator(op)
        if STEMS.include?(op)
          @stems += operands.size / 2
        else
          send(OPERATORS.fetch(op) { unsupported(op) })
        end
        @stack.clear
      end

      def unsupported(op)
        name = op >= 1200 ? "12 #{op - 1200}" : op.to_s
        raise UnsupportedFont, "charstring operator #{name} is not supported"
      end

      # hintmask and cntrmask: operands in front are vstems; one mask bit per stem.
      def mask(pos)
        @stems += operands.size / 2
        @stack.clear
        pos + ((@stems + 7) / 8)
      end

      def call(subrs, depth)
        count = subrs ? subrs.items.size : 0
        bias = if count < 1240 then 107
               elsif count < 33_900 then 1131
               else 32_768
               end
        number = @stack.pop + bias
        unless number.between?(0, count - 1)
          raise UnsupportedFont, "charstring calls subroutine #{number}, which the font does not have"
        end

        offset, length = subrs.items[number]
        run(offset, offset + length, depth + 1)
      end

      # The operands of a stack-clearing operator, less the advance width
      # the first of them may carry: one operand more than the operator
      # takes (`odd` for the moveto that take one).
      def operands(odd: false)
        unless @width
          @width = true
          @stack.shift if (odd ? @stack.size - 1 : @stack.size).odd?
        end
        @stack
      end

      def rmoveto
        dx, dy = operands
        move(dx, dy)
      end

      def hmoveto = move(operands(odd: true).first, 0)
      def vmoveto = move(0, operands(odd: true).first)

      def endchar
        if operands.size == 4
          raise UnsupportedFont, "seac accented glyphs (the deprecated endchar form) are not supported"
        end

        close_contour
        @done = true
      end

      def rlineto
        s = @stack
        (s.size / 2).times { |i| line(s[2 * i], s[(2 * i) + 1]) }
      end

      def hlineto = alternating_lines(true)
      def vlineto = alternating_lines(false)

      def alternating_lines(horizontal)
        @stack.each do |d|
          horizontal ? line(d, 0) : line(0, d)
          horizontal = !horizontal
        end
      end

      def rrcurveto
        s = @stack
        (s.size / 6).times { |i| curve_at(s, 6 * i) }
      end

      def rcurveline
        s = @stack
        i = 0
        while s.size - i >= 8
          curve_at(s, i)
          i += 6
        end
        line(s[i], s[i + 1])
      end

      def rlinecurve
        s = @stack
        i = 0
        while s.size - i > 6
          line(s[i], s[i + 1])
          i += 2
        end
        curve_at(s, i)
      end

      # dx1? {dya dxb dyb dyc}+
      def vvcurveto
        s = @stack
        dx = s.size.odd? ? s.first : 0
        (s.size.odd? ? 1 : 0).step(s.size - 4, 4) do |i|
          curve(dx, s[i], s[i + 1], s[i + 2], 0, s[i + 3])
          dx = 0
        end
      end

      # dy1? {dxa dxb dyb dxc}+
      def hhcurveto
        s = @stack
        dy = s.size.odd? ? s.first : 0
        (s.size.odd? ? 1 : 0).step(s.size - 4, 4) do |i|
          curve(s[i], dy, s[i + 1], s[i + 2], s[i + 3], 0)
          dy = 0
        end
      end

      def hvcurveto = alternating_curves(true)
      def vhcurveto = alternating_curves(false)

      # Curves that start horizontal and end vertical, then the other way
      # round, the last with a fifth operand for its final other direction.
      def alternating_curves(horizontal)
        s = @stack
        i = 0
        while s.size - i >= 4
          last = s.size - i == 5 ? s[i + 4] : 0
          if horizontal then curve(s[i], 0, s[i + 1], s[i + 2], last, s[i + 3])
          else curve(0, s[i], s[i + 1], s[i + 2], s[i + 3], last)
          end
          i += 4
          horizontal = !horizontal
        end
      end

      # Deprecated and meaningless in Type 2; ignored as the spec says.
      def dotsection; end

      def flex
        s = @stack
        curve_at(s, 0)
        curve_at(s, 6)
      end

      # dx1 dx2 dy2 dx3 dx4 dx5 dx6
      def hflex
        s = @stack
        curve(s[0], 0, s[1], s[2], s[3], 0)
        curve(s[4], 0, s[5], -s[2], s[6], 0)
      end

      # dx1 dy1 dx2 dy2 dx3 dx4 dx5 dy5 dx6
      def hflex1
        s = @stack
        curve(s[0], s[1], s[2], s[3], s[4], 0)
        curve(s[5], 0, s[6], s[7], s[8], -(s[1] + s[3] + s[7]))
      end

      # dx1 dy1 … dx5 dy5 d6: d6 runs along the way the curves went further.
      def flex1
        s = @stack
        dx = s[0] + s[2] + s[4] + s[6] + s[8]
        dy = s[1] + s[3] + s[5] + s[7] + s[9]
        curve_at(s, 0)
        if dx.abs > dy.abs then curve(s[6], s[7], s[8], s[9], s[10], -dy)
        else curve(s[6], s[7], s[8], s[9], -dx, s[10])
        end
      end

      def move(dx, dy)
        close_contour
        @outline.move_to(@x += dx, @y += dy)
        @open = true
      end

      def line(dx, dy)
        move(0, 0) unless @open
        @outline.line_to(@x += dx, @y += dy)
      end

      # The curve of the six operands from `i`.
      def curve_at(stack, at)
        curve(stack[at], stack[at + 1], stack[at + 2], stack[at + 3], stack[at + 4], stack[at + 5])
      end

      def curve(dxa, dya, dxb, dyb, dxc, dyc)
        move(0, 0) unless @open
        x1 = @x + dxa
        y1 = @y + dya
        x2 = x1 + dxb
        y2 = y1 + dyb
        @outline.curve_to(x1, y1, x2, y2, @x = x2 + dxc, @y = y2 + dyc)
      end

      def close_contour
        return unless @open

        @outline.close
        @open = false
      end
    end
  end
end
