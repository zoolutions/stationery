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
    class Table < Node
      DEFAULT_CELL = { padding: 5, borders: %i[top right bottom left], border_width: 0.5,
                       border_color: "#000000" }.freeze

      # `tag` is the Table element its fragments share; a `continued` fragment
      # repeats header rows already read on an earlier page.
      def initialize(rows, context:, widths: nil, width: :auto, header: false, split_rows: false, cell: {},
                     tag: Tagging::Element.new(:Table), continued: false)
        super()
        @tag = tag
        @continued = continued
        @split_rows = split_rows
        @context = context
        @widths = widths
        @width = width
        @header = header == true ? 1 : (header || 0).to_i
        defaults = DEFAULT_CELL.merge(cell)
        @cells = rows.map { |row| row.map { |content| build_cell(content, defaults) } }
        check_header
        tag_cells
        yield self if block_given?
      end

      def row_count = @cells.size
      def column_count = grid.column_count
      def cell(row, column) = grid.at(row, column)

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
      def invalidate!
        @column_widths = nil
        @column_metrics = nil
        @row_heights = nil
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
        @column_widths[available] ||= Widths.resolve(
          spec: Array.new(column_count) { |i| @widths&.[](i) },
          natural: column_metric(:natural_width), min: column_metric(:min_width), target: target(available)
        )
      end

      def measure(width) = row_heights(width).sum

      def paint(canvas, x, y, width, _height = nil, **)
        widths = column_widths(width)
        heights = row_heights(width)
        lefts = offsets(widths)
        tops = offsets(heights)
        canvas.structure(@tag) do
          grid.placements.each do |p|
            rect = Rect.new(x + lefts[p.column], y + tops[p.row], widths[p.columns].sum, heights[p.rows].sum)
            paint_cell(canvas, p, rect)
          end
        end
      end

      def split(width, height, **options)
        heights = row_heights(width)
        used = heights.first(@header).sum
        count = @header
        count += 1 while count < row_count && used + heights[count] <= height + EPSILON && (used += heights[count])
        return [self, nil] if count == row_count

        count = grid.boundaries.grep(@header..count).max
        split_row(count, width, height - heights.first(count).sum, fresh: options[:fresh]) ||
          split_before(count, width)
      end

      protected

      # Becomes a fragment holding `rows`, with the column widths and row
      # heights its table measured at `width`.
      def carry(rows, continued, widths, heights)
        @cells = rows
        @continued = continued
        @grid = nil
        @column_widths = widths
        @row_heights = heights
        self
      end

      private

      def grid = @grid ||= Grid.new(@cells)

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

      def tag_cells
        @cells.each_with_index do |row, index|
          row_tag = Tagging::Element.new(:TR)
          row.each { |cell| cell.tagged(cell_tag(cell, index < @header), row_tag) }
        end
      end

      def cell_tag(cell, header)
        return Tagging::Element.new(:TD) unless header || cell.colspan > 1 || cell.rowspan > 1

        attributes = { Scope: (:Column if header), ColSpan: (cell.colspan if cell.colspan > 1),
                       RowSpan: (cell.rowspan if cell.rowspan > 1) }.compact
        Tagging::Element.new(header ? :TH : :TD, attributes: attributes.empty? ? {} : { Table: attributes })
      end

      def split_before(count, width)
        return [nil, self] if count == @header

        heights = row_heights(width)
        [fragment(@cells.first(count), width, heights.first(count)),
         fragment(@cells.first(@header) + @cells.drop(count), width,
                  heights.first(@header) + heights.drop(count), continued: true)]
      end

      def split_row(row, width, space, fresh:)
        return unless @split_rows || (fresh && row == @header)
        return unless grid.boundaries.include?(row + 1)

        widths = column_widths(width)
        placements = grid.placements.select { |p| p.row == row }
        heads, tails = RowSplitter.new(placements, widths:, context: @context).call(space)
        return unless heads

        heights = row_heights(width)
        above, below = [heads, tails].map { |cells| [row_height(placements, cells, widths)] }
        [fragment(@cells.first(row) + [heads], width, heights.first(row) + above),
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
        return if @header.zero? || grid.boundaries.include?([@header, row_count].min)

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
        natural = column_metric(:natural_width)
        Array.new(column_count) { |i| @widths&.[](i) || natural[i] }.sum
      end

      def column_metric(metric)
        @column_metrics ||= {}
        @column_metrics[metric] ||= grid.column_metric { |p| p.cell.public_send(metric, @context) }
      end

      def row_heights(width)
        @row_heights ||= {}
        @row_heights[width] ||= grid.row_heights(column_widths(width)) { |p, span| p.cell.measure(@context, span) }
      end

      # A copy holding other rows of this table. Its cells are built and
      # tagged already and its column metrics are this table's.
      def fragment(rows, width, heights, continued: @continued)
        %i[natural_width min_width].each { |metric| column_metric(metric) }
        dup.carry(rows, continued, { width => column_widths(width) }, { width => heights })
      end
    end
  end
end
