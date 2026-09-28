# frozen_string_literal: true

module Stationery
  module Fonts
    # Glyph ids for one run of text in one font, with an extra advance after
    # each glyph in thousandths of the font size (positive widens) and the
    # source text of each glyph (several characters for a ligature). All-zero
    # adjustments draw as a plain Tj string; otherwise as a TJ array. Glyphs
    # are written as the font's character codes (see Font#code).
    #
    # A character no font has is glyph 0, .notdef, which stands for no
    # character in particular: each stretch of them is shown inside a Span
    # whose ActualText is the characters, so the text still extracts, copies
    # and reads aloud as written. So is the glyph a font draws in its place
    # when the render replaces missing glyphs (see Font#stand_in): it is the
    # glyph of another character, which the map to Unicode gives.
    GlyphRun = Data.define(:font, :gids, :adjust, :chars) do
      def width(size, letter_spacing: 0)
        units = gids.sum { |gid| font.ttf.advance(gid) }
        (units * size / font.ttf.units_per_em.to_f) + (adjust.sum * size / 1000.0) + (letter_spacing * gids.size)
      end

      def with_word_spacing(extra_points, size)
        extra = extra_points * 1000.0 / size
        with(adjust: adjust.each_with_index.map { |a, i| chars[i] == " " ? a + extra : a })
      end

      def missing? = gids.include?(0) || (!font.stand_in.nil? && gids.each_index.any? { |index| stand_in?(index) })

      def to_operator
        return show unless missing?

        last = gids.size - 1
        gids.each_index.chunk_while { |a, b| missing_at?(a) == missing_at?(b) }.map do |indices|
          piece = with(gids: gids.values_at(*indices), adjust: adjust.values_at(*indices),
                       chars: chars.values_at(*indices))
          piece.marked(trailing: indices.last < last)
        end.join("\n")
      end

      protected

      # One stretch of a run: .notdef glyphs inside their Span. `trailing`
      # keeps the adjustment after the last glyph, which a stretch followed
      # by another needs and the end of a run does not.
      def marked(trailing:)
        return show(trailing:) unless missing?

        "/Span <</ActualText <FEFF#{chars.join.encode(Encoding::UTF_16BE).unpack1("H*").upcase}>>> BDC\n" \
          "#{show(trailing:)}\nEMC"
      end

      private

      def missing_at?(index) = gids[index].zero? || (!font.stand_in.nil? && stand_in?(index))
      def stand_in?(index) = font.stands_in?(gids[index], chars[index])

      # A Tj string, or a TJ array of a string per stretch of glyphs up to
      # and including an adjusted one, each followed by its adjustment (the
      # last one only when `trailing`). Written in one pass over the run's
      # hex, without an Array of its parts.
      def show(trailing: false)
        codes = hex(gids)
        return "<#{codes}> Tj" unless adjusted?(trailing)

        last = gids.size - 1
        operator = +"["
        start = 0
        gids.each_index do |index|
          next if adjust[index].zero? && index != last

          operator << " " unless start.zero?
          operator << "<" << codes[start * 4, (index - start + 1) * 4] << ">"
          written = !adjust[index].zero? && (trailing || index != last)
          operator << " " << PDF::Serializer.number(-adjust[index]) if written
          start = index + 1
        end
        operator << "] TJ"
      end

      # Whether any adjustment is written: the last one only when `trailing`.
      def adjusted?(trailing)
        index = 0
        stop = trailing ? adjust.size : adjust.size - 1
        while index < stop
          return true unless adjust[index].zero?

          index += 1
        end
        false
      end

      def hex(ids) = ids.map { |gid| font.code(gid) }.pack("n*").unpack1("H*").upcase
    end
  end
end
