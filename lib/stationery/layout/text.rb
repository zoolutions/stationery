# frozen_string_literal: true

module Stationery
  module Layout
    # A paragraph of styled runs. Splits between lines; `orphans:` is the
    # fewest lines a split leaves at the foot of a page and `widows:` the
    # fewest it carries to the next (1 and 1: any line). A paragraph that
    # cannot meet them moves to the next page whole, unless it is already
    # first on a fresh page, where it splits as best it can. Beside floats
    # (`exclusions:`) its lines take the width each has; what a page break
    # carries over no longer has the floats beside it.
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
      def wraps? = true

      def measure(width, exclusions: nil) = paragraph(width, exclusions).height

      def paint(canvas, x, y, width, _height = nil, exclusions: nil)
        paragraph(width, exclusions).draw(canvas, x, y, tag: @tag)
      end

      def split(width, height, fresh: false, exclusions: nil, **)
        paragraph = paragraph(width, exclusions)
        head, tail = paragraph.split(height)
        return [head && from(head), tail && from(tail)] if (@orphans == 1 && @widows == 1) || !(head && tail)

        keep_lines(paragraph, head.lines.size, fresh:)
      end

      def fit(width, height, overflow:)
        from(paragraph(width).fit(height, overflow:))
      end

      def natural_width
        @natural_width ||= paragraph(Float::INFINITY).lines.map(&:width).max || 0
      end

      # The widest piece that cannot be broken: a word, or one break unit of a
      # word with CJK characters.
      def min_width
        @min_width ||= @runs.flat_map do |run|
          font = @context.book.resolve(run.style).first
          run.text.delete(::Stationery::Text::Wrapper::SOFT_HYPHEN).split(/[ \t\n\u200B]+/).map do |word|
            next piece_width(font, run.style, word) unless ::Stationery::Text::Breaks.cjk?(word)

            ::Stationery::Text::Breaks.units(word).map { |unit, _| piece_width(font, run.style, unit) }.max
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
        kept -= 1 while kept.positive? && widowed?(paragraph, kept)
        kept = fitting if fresh && kept < 1
        return [nil, self] if !fresh && (kept < @orphans || total < @orphans + @widows)

        head, tail = paragraph.split_at(kept)
        [head && from(head), tail && from(tail)]
      end

      # Beside a float the lines carried over are wrapped again at the full
      # width and may come out fewer than the widows.
      def widowed?(paragraph, kept)
        paragraph.exclusions && paragraph.split_at(kept).last.lines.size < @widows
      end

      def piece_width(font, style, text)
        font.width_of(text, style.render_size, letter_spacing: style.letter_spacing, kerning: style.kerning,
                                               ligatures: style.ligatures, features: style.features)
      end

      def paragraph(width, exclusions = nil)
        @paragraph || (@paragraphs[exclusions ? [width, exclusions] : width] ||= ::Stationery::Text::Paragraph.new(
          @runs, book: @context.book, width:, align: @align, leading: @leading, fallback_style: @context.style,
                 exclusions:
        ))
      end

      def from(paragraph)
        self.class.new(@runs, context: @context, align: @align, leading: @leading, orphans: @orphans, widows: @widows,
                              paragraph:, tag: @tag)
      end
    end
  end
end
