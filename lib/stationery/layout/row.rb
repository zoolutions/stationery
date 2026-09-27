# frozen_string_literal: true

module Stationery
  module Layout
    # Columns side by side. A column's `width:` is points (a number above 1),
    # a fraction of the row (0.5), :auto (its natural width) or nil (an equal
    # share of what is left). The row is as tall as its tallest column and
    # stretches every column to that height. Like a box it moves to the next
    # page whole when it fits there and otherwise splits every column at the
    # same line; a column that ends early continues as an empty fragment so
    # the backgrounds stay aligned.
    class Row < Node
      attr_reader :columns

      def initialize(columns, gap: 0, align: :top)
        super()
        @columns = columns
        @gap = gap
        @align = align
      end

      def natural_width = @columns.sum(&:natural_width) + gaps
      def min_width = @columns.sum(&:min_width) + gaps

      def splittable? = @columns.all?(&:splittable?)
      def prefer_whole? = break_inside.nil? && splittable?

      def split(width, height, fresh: false)
        return [self, nil] if measure(width) <= height + EPSILON

        parts = @columns.zip(column_widths(width)).map do |column, w|
          next [column, nil] if column.measure(w) <= height + EPSILON

          column.avoid_break? ? [nil, column] : column.split(w, height, fresh:)
        end
        return [nil, self] if parts.any? { |head, _| head.nil? }

        heads = parts.map { |head, _| head.with_open(:bottom) }
        tails = parts.zip(@columns).map { |(_, tail), column| tail || column.with_content(Flow.new).with_open(:top) }
        [with_columns(heads).tap { |row| row.keep_with_next = nil }, with_columns(tails)]
      end

      def with_columns(columns) = dup.replace_columns(columns)

      def measure(width)
        memoize_by_width(width) { @columns.zip(column_widths(width)).map { |column, w| column.measure(w) }.max || 0 }
      end

      def paint(canvas, x, y, width, height = nil, **)
        height ||= measure(width)
        left = x
        @columns.zip(column_widths(width)).each do |column, w|
          column.paint(canvas, left, y, w, height, valign: @align, debug_kind: :column)
          left += w + @gap
        end
      end

      def column_widths(width)
        available = [width - gaps, 0].max
        widths = @columns.map { |column| declared(column, available) }
        shrink_auto(widths, available)
        shared = @columns.each_index.select { |i| widths[i].nil? }
        rest = [available - widths.compact.sum, 0].max
        shared.each { |i| widths[i] = rest / shared.size }
        widths
      end

      protected

      def replace_columns(columns)
        @columns = columns
        self
      end

      private

      def gaps = @gap * [@columns.size - 1, 0].max

      def declared(column, available)
        spec = column.respond_to?(:width_spec) ? column.width_spec : nil
        case spec
        when nil then nil
        when :auto then [column.natural_width, available].min
        when Float then spec <= 1 ? available * spec : spec
        else spec
        end
      end

      def shrink_auto(widths, available)
        excess = widths.compact.sum - available
        autos = @columns.each_index.select do |i|
          @columns[i].respond_to?(:width_spec) && @columns[i].width_spec == :auto
        end
        return unless excess.positive? && autos.any?

        total = autos.sum { |i| widths[i] }
        autos.each { |i| widths[i] -= excess * widths[i] / total }
      end
    end
  end
end
