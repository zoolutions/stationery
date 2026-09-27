# frozen_string_literal: true

module Stationery
  module Layout
    # Children laid out left to right at their own widths, wrapping onto new
    # rows when the width runs out — chips, tags, badges. Splits between rows.
    class Wrap < Node
      attr_reader :children

      def initialize(children, gap: 0, row_gap: 0, align: :left)
        super()
        @children = children
        @gap = gap
        @row_gap = row_gap
        @align = align
      end

      def splittable? = true

      def natural_width
        widths = @children.map { |child| child.fixed_width(Float::INFINITY) || child.natural_width }
        widths.sum + (@gap * [widths.size - 1, 0].max)
      end

      def min_width = @children.map { |child| child.fixed_width(Float::INFINITY) || child.min_width }.max || 0

      # [[[child, width], …], …] — one array per row.
      def rows(width)
        @children.each_with_object([[]]) do |child, rows|
          own = [child.fixed_width(width) || width, width].min
          used = rows.last.sum { |_, w| w } + (@gap * rows.last.size)
          rows << [] if rows.last.any? && used + own > width + EPSILON
          rows.last << [child, own]
        end.reject(&:empty?)
      end

      def measure(width)
        heights = row_heights(width)
        heights.sum + (@row_gap * [heights.size - 1, 0].max)
      end

      def paint(canvas, x, y, width, _height = nil, **)
        top = y
        rows(width).zip(row_heights(width)).each do |row, height|
          used = row.sum { |_, w| w } + (@gap * (row.size - 1))
          left = x + Geometry.align_offset(@align, width, used)
          row.each do |child, w|
            child.paint(canvas, left, top, w)
            left += w + @gap
          end
          top += height + @row_gap
        end
      end

      def split(width, height, **)
        heights = row_heights(width)
        used = 0
        count = heights.take_while.with_index { |h, i| (used += h + (i.zero? ? 0 : @row_gap)) <= height + EPSILON }.size
        return [self, nil] if count == heights.size
        return [nil, self] if count.zero?

        taken = rows(width).first(count).sum(&:size)
        [with(@children.first(taken)), with(@children.drop(taken))]
      end

      private

      def row_heights(width)
        rows(width).map { |row| row.map { |child, w| child.measure(w) }.max }
      end

      def with(children) = self.class.new(children, gap: @gap, row_gap: @row_gap, align: @align)
    end
  end
end
