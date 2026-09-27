# frozen_string_literal: true

module Stationery
  module Fonts
    # Reads the tables of a TrueType (.ttf) font needed to measure text and to
    # embed a subset of it. Static TrueType outlines only: CFF (.otf), font
    # collections and web font wrappers are rejected with a named reason.
    class TrueType
      REQUIRED_TABLES = %w[head hhea maxp hmtx loca glyf].freeze
      SIGNATURES = {
        "OTTO" => "OpenType fonts with CFF outlines (.otf) are not supported, use a TrueType (.ttf) font",
        "ttcf" => "TrueType collections (.ttc) are not supported, use a single TrueType (.ttf) font",
        "wOFF" => "WOFF web fonts are not supported, use the TrueType (.ttf) file",
        "wOF2" => "WOFF2 web fonts are not supported, use the TrueType (.ttf) file"
      }.freeze

      attr_reader :data, :tables, :units_per_em, :bbox, :ascender, :descender, :line_gap, :num_glyphs,
                  :number_of_hmetrics, :italic_angle, :underline_position, :underline_thickness,
                  :strikeout_position, :strikeout_size, :cap_height, :x_height, :weight, :postscript_name

      # A subset embedded in a PDF carries no cmap (the PDF maps glyphs itself),
      # so reading one back passes `cmap: false`.
      def initialize(data, cmap: true)
        @data = data.b
        check_signature
        read_table_directory(cmap)
        parse_head
        parse_hhea
        parse_maxp
        parse_hmtx
        parse_loca
        @cmap = cmap ? Cmap.parse(self) : {}
        parse_post
        parse_os2
        @postscript_name = NameTable.postscript_name(self)
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

      def check_signature
        signature = @data.byteslice(0, 4)
        return if ["\x00\x01\x00\x00".b, "true"].include?(signature)

        raise UnsupportedFont, SIGNATURES.fetch(signature, "not a TrueType font")
      end

      def read_table_directory(cmap)
        @tables = {}
        u16(4).times do |i|
          record = 12 + (i * 16)
          @tables[@data.byteslice(record, 4)] = [u32(record + 8), u32(record + 12)]
        end
        required = cmap ? REQUIRED_TABLES + ["cmap"] : REQUIRED_TABLES
        missing = required.reject { |tag| @tables.key?(tag) }
        raise UnsupportedFont, "font is missing the #{missing.join(", ")} table" if missing.any?
      end

      def parse_head
        t = table_offset("head")
        @units_per_em = u16(t + 18)
        @bbox = [i16(t + 36), i16(t + 38), i16(t + 40), i16(t + 42)]
        @index_to_loc_format = i16(t + 50)
      end

      def parse_hhea
        t = table_offset("hhea")
        @ascender = i16(t + 4)
        @descender = i16(t + 6)
        @line_gap = i16(t + 8)
        @number_of_hmetrics = u16(t + 34)
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

      def parse_post
        if (t = table_offset("post"))
          @italic_angle = i16(t + 4) + (u16(t + 6) / 65_536.0)
          @underline_position = i16(t + 8)
          @underline_thickness = i16(t + 10)
          @fixed_pitch = u32(t + 12) != 0
        else
          @italic_angle = 0
          @underline_position = -@units_per_em / 10
          @underline_thickness = @units_per_em / 20
          @fixed_pitch = false
        end
      end

      def parse_os2
        if (t = table_offset("OS/2"))
          @weight = u16(t + 4)
          @strikeout_size = i16(t + 26)
          @strikeout_position = i16(t + 28)
          if u16(t) >= 2
            @x_height = i16(t + 86)
            @cap_height = i16(t + 88)
          end
        end

        @weight ||= 400
        @strikeout_size ||= @underline_thickness
        @strikeout_position ||= (@ascender * 0.25).round
        @x_height ||= (@ascender * 0.5).round
        @cap_height = (@ascender * 0.7).round if @cap_height.nil?
      end
    end
  end
end
