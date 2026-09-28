# frozen_string_literal: true

module Stationery
  module Fonts
    # Splits runs so each character is drawn by a font that has its glyph: the
    # run's family, then the book's fallbacks in order, then bundled Inter. A
    # glyph no font has stays in the run's family and draws as .notdef.
    #
    # Whitespace (any Unicode White_Space), soft hyphens, joiners, variation
    # selectors and combining marks carry the family of the character before them (or
    # after them at the start of a run) so words are not chopped and marks
    # stay with their base; whitespace a font lacks draws as a blank of the
    # right width (see Font::WHITESPACE).
    class Fallback
      CARRIED = /[\p{Space}­​‌‍︀-️\p{M}]/

      def self.carried?(char) = CARRIED.match?(char)

      # Yields each character of `text` that `font` lacks and nothing carries,
      # in order and once per occurrence, walking the codepoints (Font#lacks?
      # remembers the answer per codepoint): a text the font covers, which is
      # nearly every one, allocates nothing. Text that is not UTF-8 is walked
      # character by character, as every text was.
      def self.each_missing(text, font)
        return text.each_char { |char| yield char unless carried?(char) || font.glyph?(char) } unless utf8?(text)

        text.each_codepoint { |codepoint| yield codepoint.chr(Encoding::UTF_8) if font.lacks?(codepoint) }
      end

      # Whether `text` has a character `font` lacks and nothing carries.
      def self.missing?(text, font)
        return text.each_char.any? { |char| !carried?(char) && !font.glyph?(char) } unless utf8?(text)

        text.each_codepoint { |codepoint| return true if font.lacks?(codepoint) }
        false
      end

      def self.utf8?(text) = text.encoding == Encoding::UTF_8 || text.ascii_only?

      def initialize(book)
        @book = book
        @found = {}
      end

      def apply(runs) = runs.flat_map { |run| split(run) }

      private

      def split(run)
        style = run.style
        font = @book.resolve(style).first
        return [run] unless self.class.missing?(run.text, font)

        chars = run.text.chars
        families = fill(chars.map { |char| family_for(char, style) unless self.class.carried?(char) }, style.family)
        pieces = chars.zip(families).chunk_while { |(_, left), (_, right)| left == right }.map do |group|
          Text::Run.new(group.map(&:first).join, style.with(family: group.first.last))
        end
        Text::Run.merge(pieces)
      end

      def family_for(char, style)
        key = [char, style.family, style.weight, style.style]
        @found.fetch(key) do
          @found[key] = chain(style.family).find do |name|
            @book.resolve(style.with(family: name)).first.glyph?(char)
          end || style.family
        end
      end

      def chain(family) = [family, *@book.fallbacks, Bundled::DEFAULT].uniq

      # Carried characters (nil) take the previous family, or the first one
      # after them at the start.
      def fill(families, default)
        previous = families.compact.first || default
        families.map { |family| previous = family || previous }
      end
    end
  end
end
