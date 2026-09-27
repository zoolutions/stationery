# frozen_string_literal: true

module Stationery
  module Fonts
    # Splits runs so each character is drawn by a font that has its glyph: the
    # run's family, then the book's fallbacks in order, then bundled Inter. A
    # glyph no font has stays in the run's family and draws as .notdef.
    #
    # Whitespace, joiners, variation selectors and combining marks carry the
    # family of the character before them (or after them at the start of a
    # run) so words are not chopped and marks stay with their base.
    class Fallback
      CARRIED = /[\s‌‍︀-️\p{M}]/

      def self.carried?(char) = CARRIED.match?(char)

      def initialize(book)
        @book = book
        @found = {}
      end

      def apply(runs) = runs.flat_map { |run| split(run) }

      private

      def split(run)
        style = run.style
        font = @book.resolve(style).first
        return [run] if run.text.each_char.all? { |char| self.class.carried?(char) || font.glyph?(char) }

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
