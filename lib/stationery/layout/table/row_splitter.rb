# frozen_string_literal: true

module Stationery
  module Layout
    class Table < Node
      # Cuts one row too tall for the space left: each cell's content splits at
      # that height, what fits stays above the cut and the rest starts the row
      # again below it. A cell with nothing on one side becomes an empty cell
      # there, so backgrounds and borders run the full height of both parts.
      class RowSplitter
        # `fresh:` is true for the first row of a fresh page, where a cell
        # keeps the first float of a run it holds (see Flow::Splitter).
        def initialize(placements, widths:, context:, fresh: false)
          @placements = placements
          @widths = widths
          @context = context
          @fresh = fresh
        end

        # [head cells, tail cells], or nil when no cell fits anything above the cut.
        def call(height)
          parts = @placements.map { |placement| [placement.cell, *cut(placement, height)] }
          return if parts.none? { |_, head| head }

          [parts.map { |cell, head| cell.with_content(head || Flow.new) },
           parts.map { |cell, _, tail| cell.with_content(tail || Flow.new) }]
        end

        private

        def cut(placement, height)
          cell = placement.cell
          width = [@widths[placement.columns].sum - cell.horizontal, 0].max
          node = cell.node(@context)
          node.split(width, height - cell.vertical, fresh: @fresh && node.is_a?(Flow) && node.floats?)
        end
      end
    end
  end
end
