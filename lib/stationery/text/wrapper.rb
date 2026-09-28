# frozen_string_literal: true

require "strscan"
require_relative "wrapper/one_word"
require_relative "wrapper/remainder"

module Stationery
  module Text
    # Greedy line breaking over styled runs. Breaks at spaces (the space is
    # dropped at the break), after hyphens, at a zero-width space (U+200B,
    # HTML's <wbr>) and between ideographic characters (see Breaks); a word that does not fit is
    # hyphenated when it may be (a soft hyphen U+00AD names the break points,
    # else the style's `hyphenate` language), and a word wider than the line
    # is broken between characters. A word that changes style midway
    # ("<b>Tot</b>al") is still one word. Soft hyphens are never measured or
    # drawn: a broken word draws "-" at the break and nothing otherwise.
    #
    # Beside floats (`exclusions:`) every line has the width left at its own
    # top, found from the heights of the lines above it and the `leading`
    # between them; how tall the line will be is not known before it is
    # filled, so it is taken to be as tall as a line of the base style. The
    # lines from `free_from` on are wrapped as if the floats were gone: what
    # is left of a paragraph after a page break.
    class Wrapper
      include OneWord
      include Remainder

      TOKEN = /\n|[ \t]+|[^ \t\n-]*-+|[^ \t\n-]+/
      SOFT_HYPHEN = "­"
      ZERO_WIDTH_SPACE = Breaks::ZERO_WIDTH_SPACE
      EPSILON = 0.0001

      Segment = Data.define(:text, :style)

      def initialize(book)
        @book = book
      end

      def wrap(runs, max_width, fallback_style: runs.first&.style, exclusions: nil, leading: 0, free_from: nil)
        @fallback = fallback_style
        lines = one_word(runs, max_width) unless exclusions || @stop
        return lines if lines

        @max = max_width
        @lines = []
        @current = []
        @pending_space = []
        @fallback = fallback_style
        @widths = {}.compare_by_identity
        beside(exclusions, max_width, leading, free_from) if exclusions
        place_all(items(runs))
        finish unless @current.empty? && @lines.any? && !@ended_with_newline
        @lines
      end

      private

      # [:word, segments] | [:space, segments] | [:newline]. A word that runs
      # on into the next styled run stays one word ("<b>Tot</b>al"); a
      # zero-width space is an empty :space, a break that draws nothing; a
      # word with CJK characters is cut into its break units (Breaks).
      def items(runs)
        items = []
        @join = false # whether the next token may continue the last word
        runs.each do |run|
          if run.text.include?(ZERO_WIDTH_SPACE)
            run.text.split(ZERO_WIDTH_SPACE, -1).each_with_index do |part, index|
              if index.positive?
                items << [:space, []]
                @join = false
              end
              tokens(items, part, run.style)
            end
          else
            tokens(items, run.text, run.style)
          end
        end
        items
      end

      # A StringScanner hands each token over as one String; `String#scan`
      # made three objects of it.
      def tokens(items, text, style)
        scanner = StringScanner.new(text)
        while (token = scanner.scan(TOKEN))
          if token == "\n"
            items << [:newline]
            @join = false
          elsif token.match?(/\A[ \t]/)
            items << [:space, [Segment.new(token, style)]]
            @join = false
          else
            word_units(items, token, style)
          end
        end
      end

      # A Latin word is one unit and may run on into the next styled run
      # unless it ends in a hyphen; a word with CJK characters is cut into
      # its break units, none of which the next token continues. Latin words
      # skip the unit split, so they cost no allocation of their own.
      def word_units(items, token, style)
        if Breaks.cjk?(token)
          Breaks.units(token).each do |text, glued|
            add_unit(items, text, style, glued)
            @join = false
          end
        else
          add_unit(items, token, style, false)
          @join = !token.end_with?("-")
        end
      end

      def add_unit(items, text, style, glued)
        if (@join || glued) && items.last&.first == :word
          items.last.last << Segment.new(text, style)
        else
          items << [:word, [Segment.new(text, style)]]
        end
      end

      def place((kind, segments))
        @ended_with_newline = kind == :newline
        case kind
        when :newline then finish
        when :space then @pending_space.concat(segments)
        else place_word(segments)
        end
      end

      # A word holding soft hyphens breaks only at them, even once the part
      # after a break carries none (TeX's rule: a discretionary hyphen exempts
      # the whole word from the patterns).
      def place_word(word, explicit: word.any? { |segment| segment.text.include?(SOFT_HYPHEN) })
        @explicit = explicit
        needed = width(@pending_space) + width(word)
        if @current.empty? || line_width + needed <= @max + EPSILON
          @current.concat(@pending_space).concat(word) # one call with both would make an Array of them
        elsif (head, tail = hyphenated(word, @max - line_width - width(@pending_space)))
          @current.concat(@pending_space).concat(head)
          finish(wrapped: true, carry: tail)
          return place_word(tail, explicit:)
        else
          finish(wrapped: true, carry: word)
          @current.concat(word)
        end
        @pending_space = []
        overflow
      end

      # A word alone on its line and still too wide: hyphenate what fits,
      # else move the characters that overflow onto following lines.
      def overflow
        while line_width > @max + EPSILON && characters(@current) > 1
          head, tail = hyphenated(@current, @max)
          if head
            @current = head
            finish(wrapped: true, carry: tail)
            @current = tail
          else
            break_long_word
          end
        end
      end

      # [head, tail] with the longest hyphenation of `word` whose head (and
      # its hyphen) fits `available`; nil when the word offers no break that
      # fits. Soft hyphens name the breaks and suppress the patterns.
      def hyphenated(word, available)
        return unless @explicit || word.first&.style&.hyphenate

        chars = word.flat_map { |segment| segment.text.chars.map { |char| Segment.new(char, segment.style) } }
        break_points(chars).reverse_each do |index|
          head = chars.first(index).reject { |segment| segment.text == SOFT_HYPHEN }
          head << Segment.new(hyphen_for(chars[index - 1].style), chars[index - 1].style)
          return [head, chars.drop(index)] if width(head) <= available + EPSILON
        end
        nil
      end

      # Indexes into the word's characters before which it may break: after
      # each soft hyphen, else where the language's patterns allow.
      def break_points(chars)
        return (1...chars.length).select { |index| chars[index - 1].text == SOFT_HYPHEN } if @explicit

        text = chars.map(&:text).join
        return [] if Breaks.cjk?(text)

        language = chars.first.style.hyphenate or return []
        core = text[/\p{L}+/] or return []
        offset = text.index(core)
        Hyphenation.points(core, language).map { |point| point + offset }
      end

      # The font's hyphen, or the dedicated U+2010 when it lacks "-".
      def hyphen_for(style)
        font = @book.resolve(style).first
        !font.glyph?("-") && font.glyph?("‐") ? "‐" : "-"
      end

      # Moves characters that overflow the line onto following lines.
      def break_long_word
        fitting = []
        @current.each do |segment|
          segment.text.each_char do |char|
            piece = Segment.new(char, segment.style)
            return keep_overflow(fitting, piece) if fitting.any? && width(fitting + [piece]) > @max + EPSILON

            fitting << piece
          end
        end
      end

      def keep_overflow(fitting, piece)
        rest = [piece, *remaining_after(fitting.size).drop(1)]
        @current = fitting
        finish(wrapped: true, carry: rest)
        @current = rest
      end

      def remaining_after(count)
        @current.flat_map { |segment| segment.text.chars.map { |char| Segment.new(char, segment.style) } }.drop(count)
      end

      # `carry` is what the word broken at the end of the line has left.
      def finish(wrapped: false, carry: nil)
        segments = wrapped ? @current : @current + @pending_space
        @lines << line(fragments(trim_trailing(segments)), wrapped)
        throw :stopped, carry.to_a if @stop == @lines.size
        @current = []
        @pending_space = []
        next_line if @exclusions
      end

      def line(fragments, wrapped)
        return Line.new(fragments, fallback_metrics, justifiable: wrapped) unless @exclusions

        Line.new(fragments, fallback_metrics, justifiable: wrapped, offset: @offset, available: @max)
      end

      def beside(exclusions, width, leading, free_from)
        @exclusions = exclusions
        @full = width
        @leading = leading
        @free_from = free_from
        @top = 0
        font, size = fallback_metrics
        @probe = font.line_height(size)
        start_line
      end

      def next_line
        @top += @lines.last.height + @leading
        start_line
      end

      # The width and the offset of the line about to be filled.
      def start_line
        left, right = @free_from && @lines.size >= @free_from ? [0, 0] : @exclusions.insets(@top, @probe)
        @offset = left
        @max = [@full - left - right, 0].max
      end

      def trim_trailing(segments)
        segments = segments.dup
        segments.pop while segments.last && segments.last.text.strip.empty?
        segments
      end

      # A fragment per stretch of segments in one style. A stretch of one
      # segment keeps the segment's own String.
      def fragments(segments)
        x = 0
        fragments = []
        start = 0
        while start < segments.size
          style = segments[start].style
          stop = start + 1
          stop += 1 while stop < segments.size && segments[stop].style == style
          text = plain(stop - start == 1 ? +segments[start].text : segments[start...stop].map(&:text).join)
          start = stop
          next if text.empty?

          font, face = @book.resolve(style)
          fragment_width = measure(text, style)
          fragments << Fragment.new(text, style, font, face, fragment_width, x)
          x += fragment_width
        end
        fragments
      end

      def fallback_metrics
        [@book.resolve(@fallback).first, @fallback.render_size]
      end

      def line_width = width(@current)
      def characters(segments) = segments.sum { |segment| plain(segment.text).length }

      # A line is summed again for every word that joins it; its segments
      # are the same objects each time, so each is measured once per wrap.
      def width(segments)
        segments.sum { |segment| @widths[segment] ||= measure(plain(segment.text), segment.style) }
      end

      # The text without its soft hyphens; the same String when it has none,
      # which is nearly always, so measuring a word allocates nothing.
      def plain(text) = text.include?(SOFT_HYPHEN) ? text.delete(SOFT_HYPHEN) : text

      def measure(text, style)
        font = @book.resolve(style).first
        font.width_of(text, style.render_size, letter_spacing: style.letter_spacing, kerning: style.kerning,
                                               ligatures: style.ligatures, features: style.features)
      end
    end
  end
end
