# frozen_string_literal: true

module Stationery
  module Fonts
    # Glyph ids for one run of text in one font, with an extra advance after
    # each glyph in thousandths of the font size (positive widens). All-zero
    # adjustments draw as a plain Tj string; otherwise as a TJ array.
    GlyphRun = Data.define(:font, :gids, :adjust) do
      def width(size, letter_spacing: 0)
        units = gids.sum { |gid| font.ttf.advance(gid) }
        (units * size / font.ttf.units_per_em.to_f) + (adjust.sum * size / 1000.0) + (letter_spacing * gids.size)
      end

      def with_word_spacing(chars, extra_points, size)
        extra = extra_points * 1000.0 / size
        with(adjust: adjust.each_with_index.map { |a, i| chars[i] == " " ? a + extra : a })
      end

      def to_operator
        return "<#{hex(gids)}> Tj" unless adjusted?

        parts = gids.each_index.slice_after { |i| !adjust[i].zero? }.flat_map do |indices|
          last = indices.last
          chunk = ["<#{hex(indices.map { |i| gids[i] })}>"]
          last == gids.size - 1 || adjust[last].zero? ? chunk : chunk << PDF::Serializer.number(-adjust[last])
        end
        "[#{parts.join(" ")}] TJ"
      end

      private

      def adjusted? = adjust[0...-1].any? { |a| !a.zero? }

      def hex(ids) = ids.pack("n*").unpack1("H*").upcase
    end
  end
end
