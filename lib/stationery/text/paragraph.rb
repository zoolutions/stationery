# frozen_string_literal: true

module Stationery
  module Text
    # Wrapped lines of runs at a width, ready to measure, split across pages
    # and draw.
    class Paragraph
      MIN_SHRINK_SIZE = 4

      attr_reader :runs, :lines, :width, :align, :leading

      def initialize(runs, book:, width:, align: :left, leading: 0, lines: nil, fallback_style: nil)
        @runs = runs
        @book = book
        @width = width
        @align = align
        @leading = leading
        @fallback_style = fallback_style || runs.first&.style
        @lines = lines || Wrapper.new(book).wrap(runs, width, fallback_style: @fallback_style)
      end

      def height
        return 0 if @lines.empty?

        @lines.sum(&:height) + (@leading * (@lines.size - 1))
      end

      # [fits, rest] by whole lines; nil for an empty side.
      def split(max_height)
        count = fitting_lines(max_height)
        return [self, nil] if count == @lines.size
        return [nil, self] if count.zero?

        [with_lines(@lines.first(count)), with_lines(@lines.drop(count))]
      end

      # A paragraph that fits `max_height`: truncated to whole lines, shrunk
      # (never below 4pt) or left as is for :visible.
      def fit(max_height, overflow:)
        return self if overflow == :visible || height <= max_height
        return split(max_height).first || with_lines([]) if overflow == :truncate

        shrink(max_height)
      end

      def draw(canvas, x, y)
        top = y
        @lines.each do |line|
          offset = x + Geometry.align_offset(@align, @width, line.width)
          line.fragments.each { |fragment| draw_fragment(canvas, fragment, offset, top, line) }
          top += line.height + @leading
        end
      end

      private

      def fitting_lines(max_height)
        used = 0
        @lines.take_while.with_index do |line, index|
          used += line.height + (index.zero? ? 0 : @leading)
          used <= max_height + 0.0001
        end.size
      end

      def with_lines(lines)
        self.class.new(@runs, book: @book, width: @width, align: @align, leading: @leading, lines:,
                              fallback_style: @fallback_style)
      end

      def shrink(max_height)
        factor = 1.0
        loop do
          factor -= 0.05
          scaled = scaled_runs(factor)
          candidate = self.class.new(scaled, book: @book, width: @width, align: @align, leading: @leading * factor,
                                             fallback_style: scaled.first&.style || @fallback_style)
          return candidate if candidate.height <= max_height || scaled.all? { |run| run.style.size <= MIN_SHRINK_SIZE }
        end
      end

      def scaled_runs(factor)
        @runs.map { |run| Run.new(run.text, run.style.with(size: [run.style.size * factor, MIN_SHRINK_SIZE].max)) }
      end

      def draw_fragment(canvas, fragment, offset, top, line)
        style = fragment.style
        x = offset + fragment.x
        canvas.text(fragment.text, x:, y: top + line.ascent, font: fragment.font, size: style.render_size,
                                   color: style.color, letter_spacing: style.letter_spacing, rise: style.rise,
                                   opacity: style.opacity, underline: style.underline,
                                   strikethrough: style.strikethrough,
                                   synthetic_bold: fragment.face.synthetic_bold,
                                   synthetic_oblique: fragment.face.synthetic_oblique)
        canvas.link(x, top, fragment.width, line.height, style.link) if style.link
      end
    end
  end
end
