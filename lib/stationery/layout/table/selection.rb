# frozen_string_literal: true

module Stationery
  module Layout
    class Table < Node
      # Rows, columns or single cells picked out of a table to style together:
      #
      #   t.row(0).background = "#111"
      #   t.columns(1..).align = :right
      #   t.row(-1).columns(2..).borders = [:top]
      class Selection
        ATTRIBUTES = %i[background color weight style size align valign borders border_color border_width
                        padding font markup leading letter_spacing].freeze

        def initialize(table, rows, columns)
          @table = table
          @rows = rows
          @columns = columns
        end

        def rows(spec) = Selection.new(@table, @rows & Selection.indexes(spec, @table.row_count), @columns)
        alias row rows

        def columns(spec) = Selection.new(@table, @rows, @columns & Selection.indexes(spec, @table.column_count))
        alias column columns

        def cells = @rows.flat_map { |r| @columns.filter_map { |c| @table.cell(r, c) } }

        def set(**attributes)
          attributes.each { |name, value| public_send(:"#{name}=", value) }
          self
        end

        ATTRIBUTES.each do |name|
          define_method(:"#{name}=") do |value|
            cells.each { |cell| cell[name] = value }
            @table.invalidate!
          end
        end

        def self.indexes(spec, count)
          all = (0...count).to_a
          case spec
          when Integer then [all[spec]].compact
          when Range then Array(all[spec])
          when Array then spec.flat_map { |s| indexes(s, count) }
          else raise ArgumentError, "select rows or columns with an Integer, Range or Array, not #{spec.inspect}"
          end
        end
      end
    end
  end
end
