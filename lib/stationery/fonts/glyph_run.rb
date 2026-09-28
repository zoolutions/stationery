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
    # and reads aloud as written.
    GlyphRun = Data.define(:font, :gids, :adjust, :chars) do
      def width(size, letter_spacing: 0)
        units = gids.sum { |gid| font.ttf.advance(gid) }
        (units * size / font.ttf.units_per_em.to_f) + (adjust.sum * size / 1000.0) + (letter_spacing * gids.size)
      end

      def with_word_spacing(extra_points, size)
        extra = extra_points * 1000.0 / size
        with(adjust: adjust.each_with_index.map { |a, i| chars[i] == " " ? a + extra : a })
      end

      def missing? = gids.include?(0)

      def to_operator
        return show unless missing?

        last = gids.size - 1
        gids.each_index.chunk_while { |a, b| gids[a].zero? == gids[b].zero? }.map do |indices|
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

      def show(trailing: false)
        return "<#{hex(gids)}> Tj" unless adjusted?(trailing)

        parts = gids.each_index.slice_after { |i| !adjust[i].zero? }.flat_map do |indices|
          last = indices.last
          chunk = ["<#{hex(indices.map { |i| gids[i] })}>"]
          (last == gids.size - 1 && !trailing) || adjust[last].zero? ? chunk : chunk << PDF::Serializer.number(-adjust[last])
        end
        "[#{parts.join(" ")}] TJ"
      end

      def adjusted?(trailing) = (trailing ? adjust : adjust[0...-1]).any? { |a| !a.zero? }

      def hex(ids) = ids.map { |gid| font.code(gid) }.pack("n*").unpack1("H*").upcase
    end
  end
end
