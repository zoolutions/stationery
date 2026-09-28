# frozen_string_literal: true

module Stationery
  module Layout
    # A paragraph of styled runs. Splits between lines; `orphans:` is the
    # fewest lines a split leaves at the foot of a page and `widows:` the
    # fewest it carries to the next (1 and 1: any line). A paragraph that
    # cannot meet them moves to the next page whole, unless it is already
    # first on a fresh page, where it splits as best it can.
    class Text < Node
      attr_reader :runs

      def initialize(runs, context:, align: :left, leading: 0, orphans: 1, widows: 1, paragraph: nil,
                     tag: Tagging::Element.new(:P))
        super()
        @tag = tag
        @runs = context.book.fallback(runs)
        @context = context
        @align = align
        @leading = leading
        @orphans = self.class.lines_option(:orphans, orphans)
        @widows = self.class.lines_option(:widows, widows)
        @paragraph = paragraph
        @paragraphs = {}
      end

      def self.lines_option(name, value)
        return value if value.is_a?(Integer) && value >= 1

        raise ArgumentError, "#{name}: must be an Integer of at least 1, got #{value.inspect}"
      end

      def splittable? = true

      def measure(width) = paragraph(width).height

      def paint(canvas, x, y, width, _height = nil, **)
        paragraph(width).draw(canvas, x, y, tag: @tag)
      end

      def split(width, height, fresh: false, **)
        head, tail = paragraph(width).split(height)
        return [head && from(head), tail && from(tail)] if (@orphans == 1 && @widows == 1) || !(head && tail)

        keep_lines(paragraph(width), head.lines.size, fresh:)
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
          run.text.delete(::Stationery::Text::Wrapper::SOFT_HYPHEN).split(/[ \t\n]+/).map do |word|
            font.width_of(word, style.render_size, letter_spacing: style.letter_spacing, kerning: style.kerning,
                                                   ligatures: style.ligatures, features: style.features)
          end
        end.max || 0
      end

      private

      # Applies orphans and widows to a split after `fitting` lines: carries
      # more lines over for the widows, then moves the paragraph whole when
      # too few would stay. First on a fresh page nothing can move, so the
      # widows are honoured if a line can still stay and the orphans are not.
      def keep_lines(paragraph, fitting, fresh:)
        total = paragraph.lines.size
        kept = [fitting, total - @widows].min
        kept = fitting if fresh && kept < 1
        return [nil, self] if !fresh && (kept < @orphans || total < @orphans + @widows)

        head, tail = paragraph.split_at(kept)
        [head && from(head), tail && from(tail)]
      end

      def paragraph(width)
        @paragraph || (@paragraphs[width] ||= ::Stationery::Text::Paragraph.new(
          @runs, book: @context.book, width:, align: @align, leading: @leading, fallback_style: @context.style
        ))
      end

      def from(paragraph)
        self.class.new(@runs, context: @context, align: @align, leading: @leading, orphans: @orphans, widows: @widows,
                              paragraph:, tag: @tag)
      end
    end
  end
end
