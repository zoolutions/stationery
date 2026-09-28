# frozen_string_literal: true

module Stationery
  # Everything a render noticed but did not raise on. One collector per
  # render; equal warnings are kept once and missing glyphs are counted per
  # character and family.
  class Warnings
    include Enumerable

    Overflow = Layout::Overflow

    # `stand_in` is the character drawn in its place by a render that
    # replaces missing glyphs (`missing_glyphs: :replace`), nil for .notdef.
    MissingGlyph = Data.define(:char, :family, :count, :stand_in) do
      def initialize(char:, family:, count:, stand_in: nil)
        super
      end

      def message
        times = count == 1 ? "once" : "#{count} times"
        drawn = stand_in ? format('"%<stand_in>s" (U+%<code>04X)', stand_in:, code: stand_in.ord) : ".notdef"
        format('missing glyph "%<char>s" (U+%<code>04X) in %<family>s, drawn %<times>s as %<drawn>s',
               char:, code: char.ord, family:, times:, drawn:)
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
      def message = "#{kind} on page #{page} has no alt: text (alt: false marks decoration)"
    end

    # `allowed` is the deepest level the heading could have had: one below
    # the heading before it, and 1 for the first heading.
    SkippedHeading = Data.define(:level, :allowed, :page) do
      def message
        rule = "heading #{allowed} is the deepest that may follow heading #{allowed - 1}"
        "heading #{level} on page #{page} skips a level: #{allowed == 1 ? "the first heading is heading 1" : rule}"
      end
    end

    # A link annotation of a tagged render that no Link element holds.
    # `target` is the URL or `#anchor`; `place` is what painted it: :header,
    # :footer, :page_template, :artifact (any other artifact, such as the
    # header row a table repeats) or :canvas (`canvas.link` without a `tag:`).
    UntaggedLink = Data.define(:target, :place, :page) do
      def message = "link to #{target} #{PLACES.fetch(place)} page #{page} is outside the structure tree"
    end
    PLACES = { header: "in the header of", footer: "in the footer of", page_template: "in a page template of",
               artifact: "in an artifact of", canvas: "drawn by canvas.link without a tag: on" }.freeze

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

    # `stand_in` is the character drawn in its place, nil for .notdef.
    def missing_glyph(char, family, stand_in = nil)
      @glyphs[stand_in ? [char, family, stand_in] : [char, family]] += 1
    end

    def each(&)
      return enum_for(:each) unless block_given?

      @items.each(&)
      @glyphs.each { |(char, family, stand_in), count| yield MissingGlyph.new(char:, family:, count:, stand_in:) }
      self
    end

    def size = @items.size + @glyphs.size
    def empty? = size.zero?
  end
end
