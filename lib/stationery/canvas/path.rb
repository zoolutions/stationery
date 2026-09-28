# frozen_string_literal: true

module Stationery
  class Canvas
    # A path of the PDF canvas: the segments of a Stationery::Path, written
    # in PDF space (#to_s) for the page the canvas draws on.
    class Path < Stationery::Path
      def initialize(canvas, transform: nil)
        super(transform:)
        @canvas = canvas
      end

      # The path's operators, one per line.
      def to_s
        ops = +""
        height = @canvas.page.height
        index = 0
        index = write(ops, index, height) while index < @segments.size
        ops.chomp!
        ops
      end

      private

      def write(ops, index, height)
        s = @segments
        case s[index]
        when :move then pair(ops, s[index + 1], s[index + 2], height) << " m\n"
        when :line then pair(ops, s[index + 1], s[index + 2], height) << " l\n"
        when :curve then curve(ops, index, height)
        when :rect then rectangle(ops, s[index + 1], s[index + 2], s[index + 3], s[index + 4], height)
        else ops << "h\n"
        end
        index + WIDTHS.fetch(s[index])
      end

      def pair(ops, x, y, height)
        ops << @canvas.num(x) << " " << @canvas.num(height - y)
      end

      def curve(ops, index, height)
        s = @segments
        pair(ops, s[index + 1], s[index + 2], height) << " "
        pair(ops, s[index + 3], s[index + 4], height) << " "
        pair(ops, s[index + 5], s[index + 6], height) << " c\n"
      end

      def rectangle(ops, x, y, w, h, height)
        ops << @canvas.num(x) << " " << @canvas.num(height - y - h) << " " << @canvas.num(w) << " " <<
          @canvas.num(h) << " re\n"
      end
    end
  end
end
