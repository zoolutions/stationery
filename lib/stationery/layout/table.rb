# frozen_string_literal: true

module Stationery
  module Layout
    # Rows of cells with column widths, per-cell styling through selections,
    # header rows repeated after a page break, and splitting between rows.
    class Table < Node
      DEFAULT_CELL = { padding: 5, borders: %i[top right bottom left], border_width: 0.5,
                       border_color: "#000000" }.freeze

      def initialize(rows, context:, widths: nil, width: :auto, header: false, cell: {})
        super()
        @context = context
        @widths = widths
        @width = width
        @header = header == true ? 1 : (header || 0).to_i
        defaults = DEFAULT_CELL.merge(cell)
        @cells = rows.map { |row| row.map { |content| content.is_a?(Cell) ? content : Cell.new(content, defaults) } }
        yield self if block_given?
      end

      def row_count = @cells.size
      def column_count = @cells.map(&:size).max || 0
      def cell(row, column) = @cells.dig(row, column)

      def rows(spec) = Selection.new(self, Selection.indexes(spec, row_count), (0...column_count).to_a)
      alias row rows

      def columns(spec) = Selection.new(self, (0...row_count).to_a, Selection.indexes(spec, column_count))
      alias column columns

      def cells = Selection.new(self, (0...row_count).to_a, (0...column_count).to_a)

      def zebra(color:, from: 0, to: nil, every: 2)
        (from..(to || (row_count - 1))).step(every) { |r| rows(r).background = color }
        self
      end

      def splittable? = true

      # Forgets measurements taken before a selection restyled cells.
      def invalidate! = @column_widths = nil

      def natural_width = column_metric(:natural_width).sum
      def min_width = column_metric(:min_width).sum

      def fixed_width(available)
        case @width
        when :full then nil
        when Numeric then [@width, available].min
        else [column_widths(available).sum, available].min
        end
      end

      def column_widths(available)
        @column_widths ||= {}
        @column_widths[available] ||= Widths.resolve(
          spec: Array.new(column_count) { |i| @widths&.[](i) },
          natural: column_metric(:natural_width), min: column_metric(:min_width), target: target(available)
        )
      end

      def measure(width) = row_heights(width).sum

      def paint(canvas, x, y, width, _height = nil, **)
        widths = column_widths(width)
        top = y
        @cells.zip(row_heights(width)).each_with_index do |(row, height), row_index|
          left = x
          row.each_with_index do |cell, index|
            cell.paint(canvas, @context, Rect.new(left, top, widths[index], height),
                       last_column: index == row.size - 1, last_row: row_index == @cells.size - 1)
            left += widths[index]
          end
          top += height
        end
      end

      def split(width, height)
        heights = row_heights(width)
        used = heights.first(@header).sum
        count = @header
        count += 1 while count < row_count && used + heights[count] <= height + EPSILON && (used += heights[count])
        return [self, nil] if count == row_count
        return [nil, self] if count == @header

        [with_rows(@cells.first(count)), with_rows(@cells.first(@header) + @cells.drop(count))]
      end

      private

      def target(available)
        case @width
        when :full then available
        when Numeric then [@width, available].min
        else [natural_total, available].min
        end
      end

      def natural_total
        natural = column_metric(:natural_width)
        Array.new(column_count) { |i| @widths&.[](i) || natural[i] }.sum
      end

      def column_metric(metric)
        Array.new(column_count) do |c|
          @cells.filter_map { |row| row[c]&.public_send(metric, @context) }.max || 0
        end
      end

      def row_heights(width)
        widths = column_widths(width)
        @cells.map { |row| row.each_with_index.map { |cell, i| cell.measure(@context, widths[i]) }.max || 0 }
      end

      def with_rows(rows)
        self.class.new(rows, context: @context, widths: @widths, width: @width, header: @header)
      end
    end
  end
end
