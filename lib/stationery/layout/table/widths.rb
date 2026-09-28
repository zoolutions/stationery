# frozen_string_literal: true

module Stationery
  module Layout
    class Table < Node
      # Column widths from a spec (points, a fraction of the table, or nil for
      # flexible), each column's natural and minimum width, and a target width.
      module Widths
        module_function

        def resolve(spec:, natural:, min:, target:)
          widths = spec.map { |s| fixed(s, target) }
          flexible = widths.each_index.select { |i| widths[i].nil? }
          return widths if flexible.empty?

          remaining = [target - widths.compact.sum, 0].max
          shares = distribute(flexible.map { |i| natural[i] }, flexible.map { |i| min[i] }, remaining)
          flexible.zip(shares).each { |i, width| widths[i] = width }
          widths
        end

        # Grid#column_metric for rows no rowspan reaches across, read off the
        # rows without placing every cell on a grid: the largest single-column
        # value, then the excess of a spanning cell spread over its columns.
        def per_column(rows, count)
          values = Array.new(count, 0)
          spanning = []
          rows.each do |row|
            column = 0
            row.each do |cell|
              if cell.colspan == 1
                value = yield(cell)
                values[column] = value if value > values[column]
              else
                spanning << [cell, column]
              end
              column += cell.colspan
            end
          end
          spanning.each do |cell, column|
            columns = column...(column + cell.colspan)
            excess = yield(cell) - values[columns].sum
            columns.each { |c| values[c] += excess.fdiv(cell.colspan) } if excess.positive?
          end
          values
        end

        def fixed(spec, target)
          case spec
          when nil then nil
          when Float then spec <= 1 ? target * spec : spec
          else spec
          end
        end

        def distribute(natural, min, remaining)
          total = natural.sum
          return grow(natural, remaining, total) if total <= remaining
          return shrink(natural, min, total - remaining) if min.sum <= remaining

          min.map { |m| min.sum.zero? ? remaining.fdiv(min.size) : m * remaining.fdiv(min.sum) }
        end

        def grow(natural, remaining, total)
          extra = remaining - total
          return natural.map { |n| n + extra.fdiv(natural.size) } if total.zero?

          natural.map { |n| n + (extra * n.fdiv(total)) }
        end

        def shrink(natural, min, excess)
          slack = natural.zip(min).map { |n, m| n - m }
          total = slack.sum
          natural.zip(slack).map { |n, s| n - (excess * s.fdiv(total)) }
        end
      end
    end
  end
end
