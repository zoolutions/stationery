# frozen_string_literal: true

module Stationery
  module Layout
    # Rows of cells with column widths, per-cell styling through selections,
    # header rows repeated after a page break, and splitting between rows. A
    # row taller than a fresh page, or any row with split_rows: true, is cut
    # through its cells and continues below the repeated header.
    #
    # The fragments a page break cuts a table into keep the whole table's
    # column metrics, so every page resolves the same column widths, and the
    # widths and row heights measured for the cut, so a page break measures
    # nothing again. Laid out at another width they resolve and measure anew.
    # Where no cell spans rows a cut can fall before any row, so the rows
    # still to come are not placed on a grid until a page paints them, nor
    # measured until a page reaches them: a long table holds the wrapped
    # lines of the page being filled, not of every row.
    #
    # Rows given as an Enumerator, to a table whose every column has a width,
    # are read as pages reach them (see Stream): the table holds the rows of
    # the page being filled and the one after them, not every row.
    class Table < Node
      # How far over a limit the rows measured so far must be before the rest
      # is left unmeasured: more than any rounding in their sum.
      SLACK = 0.001
      DEFAULT_CELL = { padding: 5, borders: %i[top right bottom left], border_width: 0.5,
                       border_color: "#000000" }.freeze

      # `tag` is the Table element its fragments share; a `continued` fragment
      # repeats header rows already read on an earlier page.
      def initialize(rows, context:, widths: nil, width: :auto, header: false, split_rows: false, cell: {},
                     tag: context.element(:Table), continued: false)
        super()
        @tag = tag
        @continued = continued
        @split_rows = split_rows
        @context = context
        @widths = widths
        @width = width
        @header = header == true ? 1 : (header || 0).to_i
        defaults = DEFAULT_CELL.merge(cell)
        if Table.streams?(rows, widths)
          stream(rows, defaults)
        else
          @cells = rows.map { |row| row.map { |content| build_cell(content, defaults) } }.to_a
        end
        check_header
        yield self if block_given?
      end

      # Whether rows are read as pages reach them: an Enumerator (lazy or
      # not) for a table whose every column has a width, so that no column
      # waits on every row for its width.
      def self.streams?(rows, widths)
        rows.is_a?(Enumerator) && widths.is_a?(Array) && !widths.empty? && !widths.include?(nil)
      end

      # Every row, read to the end of a stream: what a page that paints the
      # whole table, or a question about the whole of it, needs.
      def row_count
        read_all
        @cells.size
      end

      def column_count
        @column_count ||= if row_spans?
                            grid.column_count
                          else
                            @cells.inject(0) { |most, row| [most, row.sum(&:colspan)].max }
                          end
      end

      def cell(row, column)
        return grid.at(row, column) if row_spans?
        return if row.negative? || column.negative?

        @cells[row]&.each { |cell| return cell if (column -= cell.colspan).negative? }
        nil
      end

      def rows(spec)
        return Stream::Selection.new(@stream, Stream.rows(spec), (0...column_count).to_a) if @stream

        Selection.new(self, Selection.indexes(spec, row_count), (0...column_count).to_a)
      end
      alias row rows

      def columns(spec)
        return cells.columns(spec) if @stream

        Selection.new(self, (0...row_count).to_a, Selection.indexes(spec, column_count))
      end
      alias column columns

      def cells
        return Stream::Selection.new(@stream, ->(_) { true }, (0...column_count).to_a) if @stream

        Selection.new(self, (0...row_count).to_a, (0...column_count).to_a)
      end

      def zebra(color:, from: 0, to: nil, every: 2)
        if @stream
          rows = ->(row) { row >= from && (to.nil? || row <= to) && ((row - from) % every).zero? }
          Stream::Selection.new(@stream, rows, (0...column_count).to_a).background = color
        else
          # One selection of every striped row, as each row's own would
          # be: a long table is not counted again for every row.
          count = row_count
          rows = (from..(to || (count - 1))).step(every).filter_map { |row| Selection.index(row, count) }
          Selection.new(self, rows, (0...column_count).to_a).background = color
        end
        self
      end

      def splittable? = true

      # Forgets measurements taken before a selection restyled cells.
      def invalidate!
        @column_widths = nil
        @column_metrics = nil
        @row_heights = nil
        @column_count = nil
        @flexible = nil
        @grid = nil
      end

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
        @column_widths[available] ||= begin
          flexible = flexible?
          Widths.resolve(spec: Array.new(column_count) { |i| @widths&.[](i) },
                         natural: (column_metric(:natural_width) if flexible),
                         min: (column_metric(:min_width) if flexible), target: target(available))
        end
      end

      def measure(width) = row_heights(width).sum

      def height_within(width, limit)
        return measure(width) if row_spans?

        used = 0
        row = 0
        while row?(row)
          used += height_of(width, row)
          return used if used > limit + SLACK

          row += 1
        end
        measure(width)
      end

      def paint(canvas, x, y, width, _height = nil, **)
        widths = column_widths(width)
        heights = row_heights(width)
        lefts = offsets(widths)
        tops = offsets(heights)
        row_count.times { |row| tag_row(row) }
        canvas.structure(@tag) do
          grid.placements.each do |p|
            rect = Rect.new(x + lefts[p.column], y + tops[p.row], widths[p.columns].sum, heights[p.rows].sum)
            paint_cell(canvas, p, rect)
          end
        end
      end

      def split(width, height, **options)
        heights = measured(width)
        @header.times { |row| row?(row) && height_of(width, row) }
        used = heights.first(@header).sum
        count = @header
        count += 1 while row?(count) && used + height_of(width, count) <= height + EPSILON &&
                         (used += heights[count])
        return [self, nil] unless row?(count)

        count = grid.boundaries.grep(@header..count).max if row_spans?
        split_row(count, width, height - heights.first(count).sum, fresh: options[:fresh]) ||
          split_before(count, width)
      end

      protected

      # Becomes a fragment holding `rows`, with the column widths and row
      # heights its table measured at `width`.
      def carry(rows, continued, widths, heights, stream)
        @cells = rows
        @continued = continued
        @stream = stream
        @grid = nil
        @column_widths = widths
        @row_heights = heights
        self
      end

      private

      def grid = @grid ||= Grid.new(@cells)

      def stream(rows, defaults)
        @stream = Stream.new(rows, @widths.size) { |row| row.map { |content| build_cell(content, defaults) } }
        @cells = []
        @read = 0
        @column_count = @widths.size
        @row_spans = false
      end

      # Whether the table has a row at `row`, read from its stream when it
      # is the next one. A row read joins the measured rows unmeasured.
      def row?(row)
        row < @cells.size || (@stream && pull) || false
      end

      def pull
        cells = @stream.pull(@read)
        return @stream = nil unless cells

        @read += 1
        @cells << cells
        @row_heights&.each_value { it << nil }
        true
      end

      def read_all
        nil while @stream && pull
      end

      # Whether a column takes its width from its cells, having none given.
      def flexible?
        return @flexible unless @flexible.nil?

        @flexible = false
        column_count.times { |i| @flexible = true if @widths&.[](i).nil? }
        @flexible
      end

      # Whether any cell spans rows, of the table a fragment was cut from too.
      def row_spans?
        return @row_spans if defined?(@row_spans)

        @row_spans = @cells.any? { |row| row.any? { |cell| cell.rowspan > 1 } }
      end

      # The placements of one row, which no cell from above reaches into.
      def placements_in(row)
        return grid.placements.select { |placement| placement.row == row } if row_spans?

        Grid.new([@cells[row]]).placements
      end

      # Where each column or row starts: the sizes before it, summed.
      def offsets(sizes) = Array.new(sizes.size) { |index| sizes[0...index].sum }

      def paint_cell(canvas, placement, rect)
        cell = placement.cell
        paint = lambda do
          cell.paint(canvas, @context, rect, last_column: placement.columns.end == column_count,
                                             last_row: placement.rows.end == row_count)
        end
        return canvas.artifact(type: :pagination, &paint) if @continued && placement.row < @header

        canvas.structure(cell.row_tag) { canvas.structure(cell.tag, &paint) }
      end

      # A row's TR and its cells' TH or TD, built when a page first paints or
      # cuts the row, so a long table holds the elements of the rows painted
      # so far. The first rows of a fragment that is not `continued` are the
      # table's header rows; a continued one repeats them as an artifact.
      # A render without a structure tree tags nothing.
      def tag_row(row)
        return unless @context.tagged

        cells = @cells[row]
        return if cells.all?(&:tag)

        row_tag = Tagging::Element.new(:TR)
        cells.each { |cell| cell.tagged(cell_tag(cell, row < @header), row_tag) }
      end

      def cell_tag(cell, header)
        return Tagging::Element.new(:TD) unless header || cell.colspan > 1 || cell.rowspan > 1

        attributes = { Scope: (:Column if header), ColSpan: (cell.colspan if cell.colspan > 1),
                       RowSpan: (cell.rowspan if cell.rowspan > 1) }.compact
        Tagging::Element.new(header ? :TH : :TD, attributes: attributes.empty? ? {} : { Table: attributes })
      end

      def split_before(count, width)
        return [nil, self] if count == @header

        heights = measured(width)
        [fragment(@cells.first(count), width, heights.first(count), stream: nil),
         fragment(@cells.first(@header) + @cells.drop(count), width,
                  heights.first(@header) + heights.drop(count), continued: true)]
      end

      def split_row(row, width, space, fresh:)
        return unless @split_rows || (fresh && row == @header)
        return if row_spans? && !grid.boundaries.include?(row + 1)

        widths = column_widths(width)
        placements = placements_in(row)
        tag_row(row)
        splitter = RowSplitter.new(placements, widths:, context: @context, fresh: fresh && row == @header)
        heads, tails = splitter.call(space)
        return unless heads

        heights = measured(width)
        above, below = [heads, tails].map { |cells| [row_height(placements, cells, widths)] }
        [fragment(@cells.first(row) + [heads], width, heights.first(row) + above, stream: nil),
         fragment(@cells.first(@header) + [tails] + @cells.drop(row + 1), width,
                  heights.first(@header) + below + heights.drop(row + 1), continued: true)]
      end

      # The height of a cut row's part. No cell of a row that can be cut
      # spans rows, so it is its tallest cell.
      def row_height(placements, cells, widths)
        placements.zip(cells).map { |placement, cell| cell.measure(@context, widths[placement.columns].sum) }.max
      end

      def build_cell(content, defaults)
        case content
        when Cell then content
        when Hash
          options = content.except(:content, :colspan, :rowspan)
          Cell.new(content[:content], defaults.merge(options),
                   colspan: content.fetch(:colspan, 1), rowspan: content.fetch(:rowspan, 1))
        else Cell.new(content, defaults)
        end
      end

      def check_header
        return if @header.zero? || !row_spans? || grid.boundaries.include?([@header, row_count].min)

        raise ArgumentError, "a rowspan crosses the end of the #{@header} header row(s)"
      end

      def target(available)
        case @width
        when :full then available
        when Numeric then [@width, available].min
        else [natural_total, available].min
        end
      end

      def natural_total
        natural = column_metric(:natural_width) if flexible?
        Array.new(column_count) { |i| @widths&.[](i) || natural[i] }.sum
      end

      def column_metric(metric)
        read_all
        @column_metrics ||= {}
        @column_metrics[metric] ||= if row_spans?
                                      grid.column_metric { |p| p.cell.public_send(metric, @context) }
                                    else
                                      Widths.per_column(@cells, column_count) { it.public_send(metric, @context) }
                                    end
      end

      def row_heights(width)
        read_all
        heights = measured(width)
        heights.each_index { |row| heights[row] || height_of(width, row) } if heights.include?(nil)
        heights
      end

      # The row heights measured so far at `width`, nil for a row no page has
      # reached. A rowspan ties its rows' heights together, so a table with
      # one measures them all at once.
      def measured(width)
        @row_heights ||= {}
        @row_heights[width] ||= if row_spans?
                                  grid.row_heights(column_widths(width)) { |p, span| p.cell.measure(@context, span) }
                                else
                                  Array.new(@cells.size)
                                end
      end

      # The height of one row: its tallest cell at the width it spans.
      def height_of(width, row)
        measured(width)[row] ||= begin
          widths = column_widths(width)
          column = 0
          tallest = 0
          @cells[row].each do |cell|
            span = cell.colspan == 1 ? widths[column] : widths[column, cell.colspan].sum
            column += cell.colspan
            tallest = [tallest, cell.measure(@context, span)].max
          end
          tallest
        end
      end

      # A copy holding other rows of this table. Its cells are built and
      # tagged already and its column metrics are this table's. The fragment
      # a page does not paint yet reads on from the stream, if there is one.
      def fragment(rows, width, heights, continued: @continued, stream: @stream)
        %i[natural_width min_width].each { |metric| column_metric(metric) } if flexible?
        column_count
        row_spans?
        dup.carry(rows, continued, { width => column_widths(width) }, { width => heights }, stream)
      end
    end
  end
end
