# frozen_string_literal: true

module Stationery
  module Raster
    # What a shape covers on a surface, row by row: each row a flat Array of
    # runs, `x0, x1, coverage` in turn, x0 the first pixel and x1 the one
    # after the last, sorted and apart, coverage from above 0 to 1 (the
    # share of each pixel of the run inside the shape). What the Scanner
    # answers and a Surface paints; a clip is Spans too.
    class Spans
      EMPTY = [].freeze

      # `rows` by row number from `top`.
      attr_reader :top, :rows

      def initialize(top, rows)
        @top = top
        @rows = rows
      end

      def empty? = @rows.all?(&:empty?)

      # The runs of row `y`, empty outside.
      def row(y)
        index = y - @top
        index.negative? ? EMPTY : @rows[index] || EMPTY
      end

      # Yields `y, row` for every row with a run.
      def each_row
        @rows.each_with_index { |row, index| yield @top + index, row unless row.empty? }
      end

      # [[y, x0, x1, coverage], …], for specs and for reading.
      def to_a
        list = []
        each_row { |y, row| row.each_slice(3) { |x0, x1, coverage| list << [y, x0, x1, coverage] } }
        list
      end

      # What both cover, each pixel covered by the product of the two.
      def intersect(other)
        top = [@top, other.top].max
        bottom = [@top + @rows.size, other.top + other.rows.size].min
        rows = (top...bottom).map { |y| Spans.overlap(row(y), other.row(y)) }
        Spans.new(top, rows)
      end

      # The runs two rows share.
      def self.overlap(a, b)
        return EMPTY if a.empty? || b.empty?

        out = []
        i = j = 0
        while i < a.size && j < b.size
          # Compared by hand: an Array for #max would be made per run.
          x0 = a[i] > b[j] ? a[i] : b[j] # rubocop:disable Style/MinMaxComparison
          x1 = a[i + 1] < b[j + 1] ? a[i + 1] : b[j + 1] # rubocop:disable Style/MinMaxComparison
          out.push(x0, x1, a[i + 2] * b[j + 2]) if x1 > x0
          a[i + 1] < b[j + 1] ? i += 3 : j += 3
        end
        out
      end
    end
  end
end
