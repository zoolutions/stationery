# frozen_string_literal: true

module Stationery
  module Forms
    # What a field's appearance is set in. A field built by the element DSL
    # draws with the document's own fonts (Typeface): embedded, subset and
    # Identity-H encoded like any other text, with the book's fallbacks per
    # character, so a value in any script the fonts cover renders. A field
    # made without a font book (`Forms::Field.new` on a bare canvas) draws
    # with the standard Helvetica in Windows-1252 (Standard).
    #
    # Both answer the same questions for an Appearance once bound to a
    # render's resources with #with.
    class Typeface
      # What an editable field's font keeps beyond the value it shows, so the
      # text a viewer redraws after an edit has its glyphs: printable ASCII
      # and Latin-1. A read-only field keeps its value's glyphs only.
      REPERTOIRE = [*0x20..0x7E, *0xA0..0xFF].pack("U*").freeze

      def initialize(book, style, resources = nil)
        @book = book
        @style = style
        @resources = resources
        @names = {}
      end

      # This typeface naming its fonts in `resources` (a render's Resources).
      def with(resources) = self.class.new(@book, @style, resources)

      def embedded? = true
      def ascent(size) = primary.ascender(size)
      def descent(size) = primary.descender(size)
      def width(text, size) = runs(text, size).sum { |font, run| font.width_of(run.text, size, ligatures: false) }

      # The resource names of the fonts drawn or kept so far.
      def names = @names.values

      # The name the field's /DA selects: the font of the surrounding text.
      def name = name_of(primary)

      # The operators showing `text` at the current text position: a font
      # selection and a string per run of one font. Characters no font has
      # draw as .notdef inside a Span with their ActualText (see
      # Fonts::GlyphRun) and are reported, as in any other text.
      def show(text, size)
        runs(text, size).flat_map do |font, run|
          report(font, run)
          ["/#{name_of(font)} #{PDF::Serializer.number(size)} Tf", glyphs(font, run.text).to_operator]
        end
      end

      # Keeps the glyphs of `text` in the embedded fonts without drawing it
      # (a select's other options), and the REPERTOIRE when `repertoire:`.
      def keep(text, size, repertoire: false)
        runs(text, size).each do |font, run|
          name_of(font)
          glyphs(font, run.text)
        end
        return unless repertoire

        name
        glyphs(primary, REPERTOIRE.each_char.select { |char| primary.glyph?(char) }.join)
      end

      private

      def primary = @primary ||= @book.resolve(@style).first
      def name_of(font) = @names[font] ||= @resources.font(font)

      # Marks the glyphs as used, so the subset embeds them.
      def glyphs(font, text) = font.glyph_run(text, ligatures: false)

      # [font, run] per stretch of `text` one font draws.
      def runs(text, size)
        return [] if text.empty?

        @book.fallback([Text::Run.new(text, @style.with(size:))]).map { |run| [@book.resolve(run.style).first, run] }
      end

      def report(font, run)
        run.text.each_char do |char|
          next if Fonts::Fallback.carried?(char) || font.glyph?(char)

          @book.warnings.missing_glyph(char, run.style.family)
        end
      end
    end

    # The standard Helvetica, not embedded: text is Windows-1252 bytes and
    # characters outside it become "?". That is a glyph of its own, not
    # .notdef, so it is shown without ActualText; the field's /V has the value.
    class Standard
      NAME = :Helv
      FONT = { Type: :Font, Subtype: :Type1, BaseFont: :Helvetica, Encoding: :WinAnsiEncoding }.freeze

      def with(_resources) = self.class.new
      def embedded? = false
      def ascent(size) = size * Metrics::ASCENT
      def descent(size) = size * -Metrics::DESCENT
      def width(text, size) = Metrics.width(Metrics.encode(text), size)
      def names = @named ? [NAME] : []
      # Nothing to keep: a standard font is the viewer's, whole.
      def keep(*, **) = nil

      def name
        @named = true
        NAME
      end

      def show(text, size)
        ["/#{name} #{PDF::Serializer.number(size)} Tf", "#{PDF::Serializer.literal(Metrics.encode(text))} Tj"]
      end
    end
  end
end
