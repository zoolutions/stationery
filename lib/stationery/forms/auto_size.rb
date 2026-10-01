# frozen_string_literal: true

module Stationery
  module Forms
    # The size `font_size: :auto` draws a field's value at: the largest that
    # fits the field's box less its padding, no larger than `max_font_size:`
    # and no smaller than `min_font_size:` (4 points by default, the smallest
    # Chrome's PDFium auto-sizes to). Sizes are whole tenths of a point,
    # rounded down.
    #
    # A typeface's widths and heights are linear in the size, so one line and
    # a comb field's cells are arithmetic; wrapped lines are not, and their
    # size is found by bisection. Only the typeface's measures are asked:
    # nothing is drawn or named here.
    class AutoSize
      MIN = 4
      # Measures are taken at this size and scaled: less rounding than at 1.
      UNIT = 100.0

      # The value broken into lines no wider than `width` at `size`, keeping
      # its own line breaks; a word wider than a line stands alone.
      def self.wrap(type, text, width, size)
        text.split("\n", -1).flat_map do |paragraph|
          paragraph.split.each_with_object([+""]) do |word, lines|
            candidate = lines.last.empty? ? word : "#{lines.last} #{word}"
            if lines.last.empty? || type.width(candidate, size) <= width
              lines[-1] = candidate
            else
              lines << word
            end
          end
        end
      end

      # `type` is the typeface the appearance draws with; `width` and
      # `height` the widget's.
      def initialize(field, type, width, height)
        @field = field
        @type = type
        @inner_width = width - (2 * Appearance::PADDING)
        @inner_height = height - (2 * Appearance::PADDING)
        @cell = field.options[:comb] && width.fdiv(field.max_length)
      end

      def size
        min = @field.min_font_size || [MIN, @field.max_font_size].compact.min
        max = [tenth([@field.max_font_size, height_fit].compact.min), min].max
        fit = @field.options[:multiline] ? lines_fit(min, max) : [max, width_fit].compact.min
        [tenth(fit), min].max
      end

      private

      def value = @field.value.to_s
      def tenth(size) = (size * 10).floor / 10.0
      def per_point(measure) = measure / UNIT
      def glyph_box = per_point(@type.ascent(UNIT) + @type.descent(UNIT))
      def height_fit = @inner_height / glyph_box

      # What the width allows one line, or the widest character a cell; nil
      # when the value has no width.
      def width_fit
        return cell_fit if @cell

        width = per_point(@type.width(value, UNIT))
        @inner_width / width if width.positive?
      end

      def cell_fit
        widest = value[0, @field.max_length].chars.map { |char| per_point(@type.width(char, UNIT)) }.max
        @cell / widest if widest&.positive?
      end

      # The largest tenth in min..max at which the wrapped value fits.
      def lines_fit(min, max)
        low = (min * 10).ceil
        high = (max * 10).floor
        return min unless high >= low && fits?(low / 10.0)

        while low < high
          middle = (low + high + 1) / 2
          fits?(middle / 10.0) ? low = middle : high = middle - 1
        end
        low / 10.0
      end

      def fits?(size)
        lines = AutoSize.wrap(@type, value, @inner_width, size)
        height = @type.ascent(size) + ((lines.size - 1) * size * Appearance::LEADING) + @type.descent(size)
        height <= @inner_height && lines.all? { |line| @type.width(line, size) <= @inner_width }
      end
    end
  end
end
