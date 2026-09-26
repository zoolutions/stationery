# frozen_string_literal: true

require "digest/md5"

module Stationery
  module Fonts
    # One TrueType font as used by one document: measures text, encodes it as
    # glyph ids and remembers which glyphs were drawn so only those are embedded.
    #
    # Embedded as a Type0 font over a CIDFontType2 with Identity-H encoding and a
    # ToUnicode map, so text extracts and searches correctly.
    class Font
      OBLIQUE_SKEW = Math.tan(12 * Math::PI / 180)

      attr_reader :ttf

      def initialize(ttf)
        @ttf = ttf
        @used = {}
        @widths = {}
      end

      def width_of(text, size, letter_spacing: 0)
        units = text.each_char.sum { |char| @widths[char] ||= @ttf.advance(@ttf.glyph_id(char.ord)) }
        scale(units, size) + (letter_spacing * text.length)
      end

      def ascender(size) = scale(@ttf.ascender, size)
      def descender(size) = -scale(@ttf.descender, size)
      def line_gap(size) = scale(@ttf.line_gap, size)
      def line_height(size) = ascender(size) + descender(size) + line_gap(size)
      def underline_position(size) = scale(@ttf.underline_position, size)
      def underline_thickness(size) = scale(@ttf.underline_thickness, size)
      def strikeout_position(size) = scale(@ttf.strikeout_position, size)
      def strikeout_size(size) = scale(@ttf.strikeout_size, size)
      def glyph?(char) = @ttf.glyph?(char)

      def bold?
        @ttf.weight >= 600
      end

      def encode(text)
        text.each_char.map do |char|
          gid = @ttf.glyph_id(char.ord)
          @used[gid] ||= char
          gid
        end.pack("n*")
      end

      def used?
        @used.any?
      end

      def build(writer)
        gids = @used.keys.sort
        subset, mapping = Subset.build(@ttf, gids)
        name = :"#{subset_tag(gids)}+#{@ttf.postscript_name}"

        writer.add(
          Type: :Font, Subtype: :Type0, BaseFont: name, Encoding: :"Identity-H",
          DescendantFonts: [cid_font(writer, name, gids, subset, mapping)],
          ToUnicode: writer.add(PDF::Stream.new(to_unicode_cmap))
        )
      end

      private

      def cid_font(writer, name, gids, subset, mapping)
        writer.add(
          Type: :Font, Subtype: :CIDFontType2, BaseFont: name,
          CIDSystemInfo: { Registry: "Adobe", Ordering: "Identity", Supplement: 0 },
          FontDescriptor: descriptor(writer, name, subset),
          DW: glyph_space(@ttf.advance(0)), W: glyph_widths(gids),
          CIDToGIDMap: writer.add(PDF::Stream.new(cid_to_gid_map(gids, mapping)))
        )
      end

      def descriptor(writer, name, subset)
        writer.add(
          Type: :FontDescriptor, FontName: name, Flags: flags,
          FontBBox: @ttf.bbox.map { |v| glyph_space(v) }, ItalicAngle: @ttf.italic_angle,
          Ascent: glyph_space(@ttf.ascender), Descent: glyph_space(@ttf.descender),
          CapHeight: glyph_space(@ttf.cap_height), XHeight: glyph_space(@ttf.x_height),
          StemV: bold? ? 120 : 80,
          FontFile2: writer.add(PDF::Stream.new(subset, { Length1: subset.bytesize }))
        )
      end

      def scale(units, size)
        units * size / @ttf.units_per_em.to_f
      end

      def glyph_space(units)
        (units * 1000.0 / @ttf.units_per_em).round
      end

      def flags
        flags = 32 # Nonsymbolic
        flags |= 1 if @ttf.fixed_pitch?
        flags |= 64 unless @ttf.italic_angle.zero?
        flags
      end

      # Subset fonts are named with six uppercase letters: ABCDEF+OpenSans-Regular.
      def subset_tag(gids)
        Digest::MD5.digest(gids.pack("n*") + @ttf.postscript_name).bytes.first(6).map { |b| (65 + (b % 26)).chr }.join
      end

      # Text uses the original glyph ids as CIDs; this maps them to the subset's ids.
      def cid_to_gid_map(gids, mapping)
        map = Array.new((gids.max || 0) + 1, 0)
        gids.each { |gid| map[gid] = mapping.fetch(gid) }
        map.pack("n*")
      end

      def glyph_widths(gids)
        gids.slice_when { |a, b| b != a + 1 }.flat_map do |run|
          [run.first, run.map { |gid| glyph_space(@ttf.advance(gid)) }]
        end
      end

      def to_unicode_cmap
        mappings = @used.sort.map do |gid, char|
          format("<%<gid>04X> <%<utf16>s>", gid:, utf16: char.encode(Encoding::UTF_16BE).unpack1("H*").upcase)
        end
        blocks = mappings.each_slice(100).map { |slice| "#{slice.size} beginbfchar\n#{slice.join("\n")}\nendbfchar" }

        <<~CMAP
          /CIDInit /ProcSet findresource begin
          12 dict begin
          begincmap
          /CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
          /CMapName /Adobe-Identity-UCS def
          /CMapType 2 def
          1 begincodespacerange
          <0000> <FFFF>
          endcodespacerange
          #{blocks.join("\n")}
          endcmap
          CMapName currentdict /CMap defineresource pop
          end
          end
        CMAP
      end
    end
  end
end
