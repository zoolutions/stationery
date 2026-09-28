# frozen_string_literal: true

module Stationery
  # Everything a render noticed but did not raise on. One collector per
  # render; equal warnings are kept once and missing glyphs are counted per
  # character and family.
  class Warnings
    include Enumerable

    Overflow = Layout::Overflow

    MissingGlyph = Data.define(:char, :family, :count) do
      def message
        times = count == 1 ? "once" : "#{count} times"
        format('missing glyph "%<char>s" (U+%<code>04X) in %<family>s, drawn %<times>s as .notdef',
               char:, code: char.ord, family:, times:)
      end
    end

    UnknownFamily = Data.define(:requested, :used) do
      def message = %(font family "#{requested}" is not registered, using "#{used}")
    end

    UnsupportedSvg = Data.define(:elements, :source) do
      def message = %(SVG "#{source}" uses unsupported elements: #{elements.join(", ")})
    end

    SkippedImage = Data.define(:source, :reason) do
      def message = %(image "#{source}" skipped: #{reason})
    end

    OversizedImage = Data.define(:source, :pixels, :ppi, :limit) do
      def message
        %(image "#{source}" #{pixels}px wide is drawn at #{ppi} ppi (limit #{limit}); resize it before embedding)
      end
    end

    UnresolvedLink = Data.define(:name, :page) do
      def message = %(link to "#{name}" on page #{page} has no matching anchor)
    end

    DroppedLink = Data.define(:href) do
      def message = %(link "#{href}" dropped: scheme not allowed)
    end

    NestingLimit = Data.define(:depth, :limit) do
      def message = "content nested #{depth} levels deep was flattened below level #{limit}"
    end

    UnsupportedCss = Data.define(:properties, :selectors) do
      def message
        parts = []
        parts << "properties #{properties.join(", ")}" if properties.any?
        parts << "selectors #{selectors.join(", ")}" if selectors.any?
        "html styles not read: #{parts.join("; ")}"
      end
    end

    DuplicateAnchor = Data.define(:name, :page) do
      def message = %(anchor "#{name}" on page #{page} is already defined)
    end

    MissingAlt = Data.define(:kind, :page) do
      def message = "#{kind} on page #{page} has no alt: text"
    end

    # `allowed` is the deepest level the heading could have had: one below
    # the heading before it, and 1 for the first heading.
    SkippedHeading = Data.define(:level, :allowed, :page) do
      def message
        rule = "heading #{allowed} is the deepest that may follow heading #{allowed - 1}"
        "heading #{level} on page #{page} skips a level: #{allowed == 1 ? "the first heading is heading 1" : rule}"
      end
    end

    MissingLanguage = Data.define do
      def message = "tagged PDF has no language: set metadata lang:"
    end

    ConformanceIssue = Data.define(:level, :subject) do
      def message = "#{PDF::Conformance.label(level)}: #{subject} is not covered by the sRGB output intent"
    end

    def initialize
      @items = []
      @glyphs = Hash.new(0)
    end

    def <<(warning)
      @items << warning unless @items.include?(warning)
      self
    end

    def missing_glyph(char, family)
      @glyphs[[char, family]] += 1
    end

    def each(&)
      return enum_for(:each) unless block_given?

      @items.each(&)
      @glyphs.each { |(char, family), count| yield MissingGlyph.new(char:, family:, count:) }
      self
    end

    def size = @items.size + @glyphs.size
    def empty? = size.zero?
  end
end
