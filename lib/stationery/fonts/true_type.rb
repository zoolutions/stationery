# frozen_string_literal: true

module Stationery
  module Fonts
    # Reads the sfnt tables of a static font needed to measure text and to
    # embed it: TrueType outlines (.ttf) or CFF outlines (.otf), alone or as one
    # face of a collection (.ttc), or unwrapped from a WOFF web font. Variable
    # CFF2 fonts and WOFF2 are rejected with a named reason.
    class TrueType
      include SfntMetrics

      REQUIRED_TABLES = %w[head hhea maxp hmtx].freeze
      OUTLINE_TABLES = { "OTTO" => ["CFF "] }.freeze
      GLYF_TABLES = %w[loca glyf].freeze
      SFNT_VERSIONS = ["\x00\x01\x00\x00".b, "true", "OTTO"].freeze
      COLLECTION = "ttcf"
      SIGNATURES = {
        "wOF2" => "WOFF2 needs Brotli; convert to .ttf or .woff"
      }.freeze

      attr_reader :data, :tables, :units_per_em, :bbox, :ascender, :descender, :line_gap, :num_glyphs,
                  :number_of_hmetrics, :italic_angle, :underline_position, :underline_thickness,
                  :strikeout_position, :strikeout_size, :cap_height, :x_height, :weight, :postscript_name

      # A subset embedded in a PDF carries no cmap (the PDF maps glyphs itself),
      # so reading one back passes `cmap: false`. `index:` picks a face of a
      # collection, face 0 by default.
      def initialize(data, cmap: true, index: nil)
        @data = data.b
        @data = WOFF.unpack(@data) if @data.start_with?(WOFF::SIGNATURE)
        @sfnt = face_offset(index || 0)
        check_signature
        read_table_directory(cmap)
        parse_head
        parse_hhea
        parse_maxp
        parse_hmtx
        parse_loca unless cff?
        @cmap = cmap ? Cmap.parse(self) : {}
        parse_post
        parse_os2
        @postscript_name = NameTable.postscript_name(self)
      end

      def self.collection?(data) = data.byteslice(0, 4) == COLLECTION

      def self.faces(data)
        collection?(data) ? data.byteslice(8, 4).unpack1("N") : 1
      end

      def inspect = "#<#{self.class} #{@postscript_name} glyphs=#{@num_glyphs}>"

      def glyph_id(codepoint)
        @cmap.fetch(codepoint, 0)
      end

      def glyph?(char)
        char.each_codepoint.all? { |codepoint| glyph_id(codepoint).positive? }
      end

      def advance(gid)
        @advances[gid] || @advances.last
      end

      def left_side_bearing(gid)
        if gid < @number_of_hmetrics
          i16(@hmtx_offset + (gid * 4) + 2)
        else
          i16(@hmtx_offset + (@number_of_hmetrics * 4) + ((gid - @number_of_hmetrics) * 2))
        end
      end

      # Pair kerning, read on first use. Shared by every document using this
      # parse; the source is immutable once built.
      def kerning
        @kerning ||= Kerning.for(self)
      end

      def cff?
        @tables.key?("CFF ")
      end

      # The CFF table, read on first use; nil for TrueType outlines.
      def cff
        @cff ||= CFF.new(table_data("CFF ")) if cff?
      end

      def fixed_pitch?
        @fixed_pitch
      end

      def table?(tag)
        @tables.key?(tag)
      end

      def table_offset(tag)
        @tables[tag]&.first
      end

      def table_data(tag)
        offset, length = @tables.fetch(tag)
        @data.byteslice(offset, length)
      end

      def glyph_data(gid)
        return "".b if gid >= @num_glyphs

        @data.byteslice(@glyf_offset + @loca[gid], @loca[gid + 1] - @loca[gid])
      end

      def u16(offset) = @data.byteslice(offset, 2).unpack1("n")
      def i16(offset) = @data.byteslice(offset, 2).unpack1("s>")
      def u32(offset) = @data.byteslice(offset, 4).unpack1("N")

      private

      # Table offsets in a collection are already absolute, so a face is read
      # from the shared data at its own table directory.
      def face_offset(index)
        count = self.class.faces(@data)
        unless index.between?(0, count - 1)
          raise ArgumentError, "font face #{index} is out of range (numFonts #{count})"
        end

        self.class.collection?(@data) ? u32(12 + (index * 4)) : 0
      end

      def check_signature
        signature = @data.byteslice(@sfnt, 4)
        return if SFNT_VERSIONS.include?(signature)

        raise UnsupportedFont, SIGNATURES.fetch(signature, "not a TrueType font")
      end

      def read_table_directory(cmap)
        @tables = {}
        u16(@sfnt + 4).times do |i|
          record = @sfnt + 12 + (i * 16)
          @tables[@data.byteslice(record, 4)] = [u32(record + 8), u32(record + 12)]
        end
        raise UnsupportedFont, "variable CFF2 fonts are not supported" if @tables.key?("CFF2")

        required = REQUIRED_TABLES + OUTLINE_TABLES.fetch(@data.byteslice(@sfnt, 4), GLYF_TABLES)
        required += ["cmap"] if cmap
        missing = required.reject { |tag| @tables.key?(tag) }
        raise UnsupportedFont, "font is missing the #{missing.map(&:strip).join(", ")} table" if missing.any?
      end

      def parse_head
        t = table_offset("head")
        @units_per_em = u16(t + 18)
        @bbox = [i16(t + 36), i16(t + 38), i16(t + 40), i16(t + 42)]
        @index_to_loc_format = i16(t + 50)
      end

      def parse_maxp
        @num_glyphs = u16(table_offset("maxp") + 4)
      end

      def parse_hmtx
        @hmtx_offset = table_offset("hmtx")
        @advances = @data.byteslice(@hmtx_offset, @number_of_hmetrics * 4).unpack("n*").each_slice(2).map(&:first)
      end

      def parse_loca
        t = table_offset("loca")
        @loca = if @index_to_loc_format.zero?
                  @data.byteslice(t, (@num_glyphs + 1) * 2).unpack("n*").map { |offset| offset * 2 }
                else
                  @data.byteslice(t, (@num_glyphs + 1) * 4).unpack("N*")
                end
        @glyf_offset = table_offset("glyf")
      end
    end
  end
end
