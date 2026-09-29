# frozen_string_literal: true

module Stationery
  module Layout
    class Table < Node
      # The rows of a table read from an Enumerator one at a time, as pages
      # reach them. Selections made before the first row is read are kept as
      # rules and applied to each row as it arrives, by its index from the
      # start of the table: an index from the end is not known until the
      # last row is read, and a cell spanning rows would tie a row to rows
      # not read yet, so neither is taken.
      class Stream
        attr_reader :column_count

        # `build` turns a row of the source into its cells.
        def initialize(source, column_count, &build)
          @source = source
          @column_count = column_count
          @build = build
          @index = 0
          @rules = []
        end

        # Styles the cells of `columns` in every row `rows` (a Proc of the
        # row's index) answers true for, as rows are read.
        def style(rows, columns, name, value) = @rules << [rows, columns, name, value]

        # The cells of the row at `index`, the next one, nil once the source
        # has none. A table and its fragments read it in turn: the one that
        # asks is the one holding the rows read so far.
        def pull(index)
          raise Error, "a streamed table was asked for row #{index} after row #{@index - 1}" unless index == @index

          cells = @build.call(@source.next)
          check(cells)
          @rules.each { |rows, columns, name, value| apply(cells, columns, name, value) if rows.call(@index) }
          @index += 1
          cells
        rescue StopIteration
          nil
        end

        # A row matcher for a selection by index from the start: an Integer,
        # a Range or an Array of them.
        def self.rows(spec)
          case spec
          when Integer
            from_end(spec) if spec.negative?
            ->(row) { row == spec }
          when Range
            from_end(spec) if [spec.begin, spec.end].any? { it&.negative? }
            ->(row) { spec.cover?(row) }
          when Array
            matchers = spec.map { rows(it) }
            ->(row) { matchers.any? { it.call(row) } }
          else raise ArgumentError, "select rows or columns with an Integer, Range or Array, not #{spec.inspect}"
          end
        end

        def self.from_end(spec)
          raise ArgumentError, "a table read from an Enumerator selects rows from its start: #{spec.inspect} " \
                               "counts from its end, which is not known until its last row is read " \
                               "(give the rows as an Array)"
        end

        private

        def check(cells)
          if cells.any? { it.rowspan > 1 }
            raise ArgumentError, "row #{@index} of a table read from an Enumerator has a cell that spans rows, " \
                                 "which ties it to rows not read yet (give the rows as an Array)"
          end
          columns = cells.sum(&:colspan)
          return if columns <= @column_count

          raise ArgumentError, "row #{@index} of a table read from an Enumerator has #{columns} columns " \
                               "and the table #{@column_count} widths"
        end

        def apply(cells, columns, name, value)
          columns.filter_map { |column| at(cells, column) }.uniq.each { |cell| cell[name] = value }
        end

        # The cell of `cells` covering `column`, as Table#cell finds it.
        def at(cells, column)
          cells.each { |cell| return cell if (column -= cell.colspan).negative? }
          nil
        end

        # Rows and columns of a table read from an Enumerator, picked out to
        # style as Table::Selection does, for the rows still to be read.
        class Selection
          def initialize(stream, rows, columns)
            @stream = stream
            @rows = rows
            @columns = columns
          end

          def rows(spec)
            own = @rows
            other = Stream.rows(spec)
            Selection.new(@stream, ->(row) { own.call(row) && other.call(row) }, @columns)
          end
          alias row rows

          def columns(spec)
            Selection.new(@stream, @rows, @columns & Table::Selection.indexes(spec, @stream.column_count))
          end
          alias column columns

          def set(**attributes)
            attributes.each { |name, value| public_send(:"#{name}=", value) }
            self
          end

          Table::Selection::ATTRIBUTES.each do |name|
            define_method(:"#{name}=") { |value| @stream.style(@rows, @columns, name, value) }
          end
        end
      end
    end
  end
end
