# frozen_string_literal: true

module Stationery
  module Fonts
    # One stretch of text as a shaper placed it (see Shaper): its glyphs in
    # visual order at one size, the source text of each cluster, and the
    # extra points after each glyph that letter and word spacing add. It
    # answers what a GlyphRun does, so the canvas draws either.
    #
    # Drawn as Tj/TJ like any run. The PDF's widths stay the font's own, so
    # an advance the shaper changed is a TJ adjustment; an x offset moves the
    # pen before its glyph and back after it, a y offset is a text rise (Ts)
    # around it. Both are text space, so they follow a synthetic oblique's
    # shear and leave the text matrix the line was positioned with alone.
    #
    # A glyph can only map to one text in the font's ToUnicode, and a reader
    # takes glyphs in the order drawn. Wherever that cannot give the source
    # text (glyphs out of logical order, several glyphs for one cluster, a
    # glyph already standing for another text, .notdef) the glyphs are shown
    # inside a Span whose ActualText is the characters in logical order.
    ShapedRun = Data.define(:font, :size, :glyphs, :texts, :extra, :rise) do
      def self.build(font, size, text, glyphs)
        starts = glyphs.map(&:cluster).uniq.sort
        texts = starts.each_with_index.to_h do |start, index|
          [start, text[(index.zero? ? 0 : start)...(starts[index + 1] || text.length)]]
        end
        new(font:, size:, glyphs: glyphs.freeze, texts: texts.freeze, extra: Array.new(glyphs.size, 0).freeze, rise: 0)
      end

      def gids = glyphs.map(&:gid)

      # The spacing is part of the run, whatever is asked for here.
      def width(*, **) = (glyphs.sum(&:advance) * size / units_per_em) + extra.sum

      # Letter spacing follows each cluster, not each glyph: a mark stays on
      # its base and a ligature counts once.
      def with_letter_spacing(points)
        points.zero? ? self : widened { points }
      end

      # Widens every U+0020 space, as justification asks.
      def with_word_spacing(points, _size = size)
        widened { |text| points * text.count(" ") }
      end

      def missing? = glyphs.any? { |glyph| glyph.gid.zero? }

      # The characters the shaper found no glyph for.
      def missing
        glyphs.select { |glyph| glyph.gid.zero? }.map(&:cluster).uniq.flat_map { |cluster| texts[cluster].chars }
      end

      def to_operator
        groups = stretches.chunk_while { |(left, _), (right, _)| left == right }
                          .map { |group| [group.first.first, group.flat_map(&:last)] }
        groups.each_with_index.map do |(plain, indices), index|
          trailing = index < groups.size - 1
          plain ? show(indices, trailing) : marked(indices, trailing)
        end.join("\n")
      end

      private

      def units_per_em = font.ttf.units_per_em.to_f

      def widened
        last = glyphs.size - 1
        with(extra: glyphs.each_with_index.map do |glyph, index|
          closes = index == last || glyphs[index + 1].cluster != glyph.cluster
          closes ? extra[index] + yield(texts[glyph.cluster]) : extra[index]
        end)
      end

      # [[plain, glyph indexes], …]: the run cut wherever everything drawn so
      # far comes before everything still to draw in the text. A piece is
      # plain when the font's ToUnicode gives its text.
      def stretches
        counts = glyphs.map(&:cluster).tally
        own = glyphs.map { |glyph| own?(glyph, counts[glyph.cluster] == 1) }
        lows = lowest_ahead
        high = -1
        glyphs.each_index.slice_when { |index, following| (high = [high, glyphs[index].cluster].max) < lows[following] }
              .map { |indices| [indices.size == 1 && own[indices.first], indices] }
      end

      # The lowest cluster from each glyph to the end of the run.
      def lowest_ahead
        low = nil
        glyphs.reverse_each.map { |glyph| low = [low || glyph.cluster, glyph.cluster].min }.reverse
      end

      # Marks the glyph as used, and answers whether the font's ToUnicode maps
      # it to its cluster's text. A glyph sharing its cluster holds the text
      # only until a glyph drawn on its own claims another.
      def own?(glyph, alone)
        text = texts[glyph.cluster]
        return font.use(glyph.gid, text) == text && glyph.gid.positive? if alone

        font.use(glyph.gid, text, loosely: true)
        false
      end

      def marked(indices, trailing)
        text = indices.map { |index| glyphs[index].cluster }.uniq.sort.map { |cluster| texts[cluster] }.join
        "/Span <</ActualText <FEFF#{text.encode(Encoding::UTF_16BE).unpack1("H*").upcase}>>> BDC\n" \
          "#{show(indices, trailing)}\nEMC"
      end

      # The operators showing these glyphs. `trailing` keeps the movement
      # after the last glyph, which glyphs that follow need.
      def show(indices, trailing)
        ops = []
        parts = []
        pending = 0.0
        lift = 0
        indices.each do |index|
          glyph = glyphs[index]
          pending += thousandths(glyph.x_offset)
          lift = lifted(ops, parts, glyph) unless glyph.y_offset == lift
          parts << pending unless pending.round(4).zero?
          parts << glyph.gid
          pending = after(index)
        end
        parts << pending if trailing && !pending.round(4).zero?
        flush(ops, parts)
        ops << "#{PDF::Serializer.number(rise)} Ts" unless lift.zero?
        ops.join("\n")
      end

      # Ends the string being shown and sets the rise of the glyph; answers
      # how far it is now lifted.
      def lifted(ops, parts, glyph)
        flush(ops, parts)
        ops << "#{PDF::Serializer.number(rise + (glyph.y_offset * size / units_per_em))} Ts"
        glyph.y_offset
      end

      # How far the pen moves after a glyph beyond the font's own advance, in
      # thousandths of the size: the shaper's advance, the spacing, and back
      # from the glyph's x offset.
      def after(index)
        glyph = glyphs[index]
        thousandths(glyph.advance - font.ttf.advance(glyph.gid) - glyph.x_offset) + (extra[index] * 1000.0 / size)
      end

      def thousandths(units) = units * 1000.0 / units_per_em

      # Glyph ids (Integers) and movements (Floats) as one Tj or TJ.
      def flush(ops, parts)
        return if parts.empty?

        strings = parts.chunk_while { |left, right| left.is_a?(Integer) && right.is_a?(Integer) }.map do |chunk|
          chunk.first.is_a?(Integer) ? "<#{hex(chunk)}>" : PDF::Serializer.number(-chunk.first)
        end
        ops << (strings.size == 1 ? "#{strings.first} Tj" : "[#{strings.join(" ")}] TJ")
        parts.clear
      end

      def hex(ids) = ids.map { |gid| font.code(gid) }.pack("n*").unpack1("H*").upcase
    end
  end
end
