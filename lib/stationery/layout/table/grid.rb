# frozen_string_literal: true

module Stationery
  module Layout
    class Table < Node
      # Places cells that span columns and rows the way HTML does: each row
      # lists only the cells it starts, and a cell skips slots a rowspan from
      # above already covers. Rowspans running past the last row are clamped.
      class Grid
        Placement = Data.define(:cell, :row, :column, :colspan, :rowspan) do
          def columns = column...(column + colspan)
          def rows = row...(row + rowspan)
        end

        attr_reader :placements, :row_count, :column_count

        def initialize(rows)
          @row_count = rows.size
          @slots = {}
          @placements = rows.each_with_index.flat_map { |row, r| place(row, r) }
          @column_count = @placements.map { |p| p.columns.end }.max || 0
        end

        def at(row, column) = @slots[[row, column]]&.cell

        # Row indexes a horizontal cut can fall before without splitting a rowspan.
        def boundaries
          @boundaries ||= begin
            inside = Array.new(row_count + 1, false)
            @placements.each { |p| ((p.row + 1)...p.rows.end).each { |r| inside[r] = true } }
            (0..row_count).reject { |r| inside[r] }.freeze
          end
        end

        # A metric per column: the largest single-column value, then the excess
        # of a spanning cell over its columns spread evenly across them.
        def column_metric
          values = Array.new(column_count, 0)
          single, spanning = @placements.partition { |p| p.colspan == 1 }
          single.each { |p| values[p.column] = [values[p.column], yield(p)].max }
          spanning.each do |p|
            excess = yield(p) - values[p.columns].sum
            p.columns.each { |c| values[c] += excess.fdiv(p.colspan) } if excess.positive?
          end
          values
        end

        # Each row's height from its cells measured at their spanned width; a
        # rowspan taller than its rows adds the excess to its last row.
        def row_heights(widths)
          heights = Array.new(row_count, 0)
          single, spanning = @placements.partition { |p| p.rowspan == 1 }
          single.each { |p| heights[p.row] = [heights[p.row], yield(p, widths[p.columns].sum)].max }
          spanning.each do |p|
            excess = yield(p, widths[p.columns].sum) - heights[p.rows].sum
            heights[p.rows.end - 1] += excess if excess.positive?
          end
          heights
        end

        private

        def place(row, r)
          column = 0
          row.map do |cell|
            column += 1 while @slots.key?([r, column])
            placement = Placement.new(cell:, row: r, column:, colspan: cell.colspan,
                                      rowspan: cell.rowspan.clamp(1, row_count - r))
            placement.rows.each { |pr| placement.columns.each { |pc| @slots[[pr, pc]] = placement } }
            column += cell.colspan
            placement
          end
        end
      end
    end
  end
end
