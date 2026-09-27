# frozen_string_literal: true

module Stationery
  module Layout
    # A paragraph of styled runs. Splits between lines.
    class Text < Node
      attr_reader :runs

      def initialize(runs, context:, align: :left, leading: 0, paragraph: nil, tag: Tagging::Element.new(:P))
        super()
        @tag = tag
        @runs = context.book.fallback(runs)
        @context = context
        @align = align
        @leading = leading
        @paragraph = paragraph
        @paragraphs = {}
      end

      def splittable? = true

      def measure(width) = paragraph(width).height

      def paint(canvas, x, y, width, _height = nil, **)
        canvas.tag(@tag) { paragraph(width).draw(canvas, x, y) }
      end

      def split(width, height, **)
        head, tail = paragraph(width).split(height)
        [head && from(head), tail && from(tail)]
      end

      def fit(width, height, overflow:)
        from(paragraph(width).fit(height, overflow:))
      end

      def natural_width
        @natural_width ||= paragraph(Float::INFINITY).lines.map(&:width).max || 0
      end

      def min_width
        @min_width ||= @runs.flat_map do |run|
          style = run.style
          font = @context.book.resolve(style).first
          run.text.split(/[ \t\n]+/).map do |word|
            font.width_of(word, style.render_size, letter_spacing: style.letter_spacing, kerning: style.kerning,
                                                   ligatures: style.ligatures)
          end
        end.max || 0
      end

      private

      def paragraph(width)
        @paragraph || (@paragraphs[width] ||= ::Stationery::Text::Paragraph.new(
          @runs, book: @context.book, width:, align: @align, leading: @leading, fallback_style: @context.style
        ))
      end

      def from(paragraph)
        self.class.new(@runs, context: @context, align: @align, leading: @leading, paragraph:, tag: @tag)
      end
    end
  end
end
