# frozen_string_literal: true

module Stationery
  module Text
    # Wrapped lines of runs at a width, ready to measure, split across pages
    # and draw. Beside floats (`exclusions:`) every line has its own width
    # and offset; the lines a split carries over are wrapped again without
    # the floats, which stay on the page the first lines are on.
    #
    # A piece of a split paragraph keeps the runs of the whole and knows
    # where it starts: after `skipped` lines of a wrap that was free of the
    # floats from line `free_from`. The piece that holds the end of the text
    # (`last`) can so be wrapped again at another width (#at).
    class Paragraph
      MIN_SHRINK_SIZE = 4

      attr_reader :runs, :lines, :width, :align, :leading, :exclusions

      def initialize(runs, book:, width:, align: :left, leading: 0, lines: nil, fallback_style: nil, exclusions: nil,
                     skipped: 0, free_from: nil, last: true)
        @runs = lines ? runs : book.fallback(runs)
        @book = book
        @width = width
        @align = align
        @leading = leading
        @fallback_style = fallback_style || runs.first&.style
        @exclusions = exclusions
        @skipped = skipped
        @free_from = free_from
        @last = last
        @lines = lines || wrap
      end

      # This paragraph where the width is another: what it has left of its
      # text, wrapped again. At its own width, and for a piece whose end a
      # split cut off, that is the paragraph itself.
      def at(width)
        return self if !@last || (width - @width).abs <= Wrapper::EPSILON

        (@others ||= {})[width] ||= self.class.new(left, book: @book, width:, align: @align, leading: @leading,
                                                         fallback_style: @fallback_style)
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

        [with_lines(@lines.first(count), last: false), rest_from(count)]
      end

      # [first `count` lines, the rest]; nil for an empty side.
      def split_at(count)
        return [nil, self] if count <= 0
        return [self, nil] if count >= @lines.size

        [with_lines(@lines.first(count), last: false), rest_from(count)]
      end

      # A paragraph that fits `max_height`: truncated to whole lines, shrunk
      # (never below 4pt) or left as is for :visible.
      def fit(max_height, overflow:)
        return self if overflow == :visible || height <= max_height
        return split(max_height).first || with_lines([]) if overflow == :truncate

        shrink(max_height)
      end

      # `tag` is the structure element the text belongs to in a tagged PDF;
      # linked runs become Link elements inside it.
      def draw(canvas, x, y, tag: nil)
        links = Links.new(canvas.tagging?)
        canvas.tag_runs(tag) do |mark|
          top = y
          @lines.each do |line|
            offset = x + line.offset + Geometry.align_offset(@align, line.available || @width, line.width)
            extra = word_spacing(line)
            spaces = 0
            line.fragments.each do |fragment|
              link = links.for(fragment.style.link)
              mark.call(link) { draw_fragment(canvas, fragment, offset + (extra * spaces), top, line, extra, link:) }
              spaces += fragment.text.count(" ")
            end
            top += line.height + @leading
          end
        end
      end

      # One Link element per run of fragments with the same link target;
      # none when the canvas builds no structure tree.
      class Links
        # `tagging` is whether the canvas builds a tree; a keyword here would
        # cost a Hash per paragraph drawn.
        def initialize(tagging)
          @tagging = tagging
        end

        def for(target)
          @element = nil unless target == @target
          @target = target
          @element = target && @tagging && (@element || Tagging::Element.new(:Link))
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

      def wrap(free_from: @free_from)
        Wrapper.new(@book).wrap(@runs, @width, fallback_style: @fallback_style, exclusions: @exclusions,
                                               leading: @leading, free_from:)
      end

      # The runs of the text from this piece's first line on.
      def left
        Wrapper.new(@book).rest(@runs, @width, @skipped, fallback_style: @fallback_style, exclusions: @exclusions,
                                                         leading: @leading, free_from: @free_from)
      end

      # The lines after the first `count`, wrapped again when a float is
      # beside any of them.
      def rest_from(count)
        rest = @lines.drop(count)
        from = @skipped + count
        return with_lines(rest, skipped: from) unless rest.any? { |line| line.available && line.available < @width }

        with_lines(wrap(free_from: from).drop(from), skipped: from, free_from: from)
      end

      def with_lines(lines, skipped: @skipped, free_from: @free_from, last: @last)
        self.class.new(@runs, book: @book, width: @width, align: @align, leading: @leading, lines:,
                              fallback_style: @fallback_style, exclusions: @exclusions, skipped:, free_from:, last:)
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

      # Extra points per space that stretch a justifiable line to the width.
      def word_spacing(line)
        return 0 unless @align == :justify && line.justifiable? && line.space_count.positive?

        [((line.available || @width) - line.width) / line.space_count, 0].max
      end

      def draw_fragment(canvas, fragment, offset, top, line, word_spacing, link: nil)
        style = fragment.style
        count_missing(fragment)
        x = offset + fragment.x
        width = canvas.text(fragment.text, x:, y: top + line.ascent, font: fragment.font, size: style.render_size,
                                           color: style.color, letter_spacing: style.letter_spacing, rise: style.rise,
                                           opacity: style.opacity, underline: style.underline,
                                           strikethrough: style.strikethrough, kerning: style.kerning,
                                           ligatures: style.ligatures, features: style.features,
                                           synthetic_bold: fragment.face.synthetic_bold,
                                           synthetic_oblique: fragment.face.synthetic_oblique, word_spacing:)
        canvas.link(x, top, width, line.height, style.link, tag: link) if style.link
      end

      def count_missing(fragment)
        return count_shaped(fragment) if @book.shaper

        Fonts::Fallback.each_missing(fragment.text, fragment.font) do |char|
          @book.warnings.missing_glyph(char, fragment.style.family, fragment.font.stand_in&.char)
        end
      end

      # With a shaper a missing glyph is one the shaper answered glyph 0 for;
      # text it declined is drawn, and so counted, without it.
      def count_shaped(fragment)
        style = fragment.style
        run = fragment.font.shaped(fragment.text, style.render_size, letter_spacing: style.letter_spacing,
                                                                     kerning: style.kerning,
                                                                     ligatures: style.ligatures,
                                                                     features: style.features)
        chars = run ? run.missing : fragment.text.each_char.reject { |char| covered?(fragment.font, char) }
        chars.each { |char| @book.warnings.missing_glyph(char, style.family, fragment.font.stand_in&.char) }
      end

      def covered?(font, char) = Fonts::Fallback.carried?(char) || font.glyph?(char)
    end
  end
end
