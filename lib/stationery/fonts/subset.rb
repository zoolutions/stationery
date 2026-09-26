# frozen_string_literal: true

module Stationery
  module Fonts
    # Builds a TrueType font holding only the given glyphs (plus the parts of
    # composite glyphs and .notdef), renumbered compactly from zero.
    module Subset
      HINTING_TABLES = ["cvt ", "fpgm", "prep"].freeze
      CHECKSUM_MAGIC = 0xB1B0AFBA

      module_function

      # Returns [font_bytes, { original_gid => subset_gid }].
      def build(ttf, gids)
        glyphs = closure(ttf, Set.new(gids) << 0).sort
        mapping = glyphs.each_with_index.to_h
        glyf, loca = glyph_tables(ttf, glyphs, mapping)

        tables = {
          "head" => head(ttf), "hhea" => patch(ttf, "hhea", 34, glyphs.size),
          "maxp" => patch(ttf, "maxp", 4, glyphs.size), "hmtx" => hmtx(ttf, glyphs),
          "loca" => loca.pack("N*"), "glyf" => glyf
        }
        HINTING_TABLES.each { |tag| tables[tag] = ttf.table_data(tag) if ttf.table?(tag) }
        tables["post"] = post(ttf) if ttf.table?("post")

        [assemble(tables), mapping]
      end

      def checksum(data)
        (data + padding(data)).unpack("N*").sum & 0xFFFFFFFF
      end

      def closure(ttf, gids)
        glyphs = Set.new
        queue = gids.to_a
        until queue.empty?
          gid = queue.pop
          next if gid >= ttf.num_glyphs || !glyphs.add?(gid)

          each_component(ttf.glyph_data(gid)) { |_, component| queue << component }
        end
        glyphs
      end

      def glyph_tables(ttf, glyphs, mapping)
        glyf = String.new(encoding: Encoding::BINARY)
        loca = glyphs.map do |gid|
          offset = glyf.bytesize
          data = remap_components(ttf.glyph_data(gid), mapping)
          glyf << data << padding(data)
          offset
        end
        [glyf, loca << glyf.bytesize]
      end

      def head(ttf)
        head = ttf.table_data("head").dup
        head[8, 4] = [0].pack("N") # checkSumAdjustment, filled in by assemble
        head[50, 2] = [1].pack("n") # indexToLocFormat: long offsets
        head
      end

      def patch(ttf, tag, offset, count)
        data = ttf.table_data(tag).dup
        data[offset, 2] = [count].pack("n")
        data
      end

      def hmtx(ttf, glyphs)
        glyphs.flat_map { |gid| [ttf.advance(gid), ttf.left_side_bearing(gid)] }.pack("ns>" * glyphs.size)
      end

      # Version 3.0: metrics only, no glyph names.
      def post(ttf)
        post = ttf.table_data("post").byteslice(0, 32).dup
        post[0, 4] = [0x00030000].pack("N")
        post
      end

      def remap_components(data, mapping)
        copy = nil
        each_component(data) do |pos, component|
          copy ||= data.dup
          copy[pos, 2] = [mapping.fetch(component, 0)].pack("n")
        end
        copy || data
      end

      # Yields the byte offset of each component glyph id in a composite glyph.
      def each_component(data)
        return if data.bytesize < 10 || data.unpack1("s>") >= 0

        pos = 10
        loop do
          flags, component = data.byteslice(pos, 4).unpack("nn")
          yield pos + 2, component
          pos += 4 + component_arguments_size(flags)
          break if flags.nobits?(0x0020) # MORE_COMPONENTS
        end
      end

      def component_arguments_size(flags)
        size = flags.allbits?(0x0001) ? 4 : 2 # ARG_1_AND_2_ARE_WORDS
        if flags.allbits?(0x0008) then size + 2 # WE_HAVE_A_SCALE
        elsif flags.allbits?(0x0040) then size + 4 # WE_HAVE_AN_X_AND_Y_SCALE
        elsif flags.allbits?(0x0080) then size + 8 # WE_HAVE_A_TWO_BY_TWO
        else size
        end
      end

      def assemble(tables)
        tags = tables.keys.sort
        entry_selector = Math.log2(tags.size).floor
        search_range = (2**entry_selector) * 16
        directory = [0x00010000, tags.size, search_range, entry_selector, (tags.size * 16) - search_range]
                    .pack("Nnnnn")
        body = String.new(encoding: Encoding::BINARY)
        body_offset = 12 + (tags.size * 16)
        head_offset = nil

        tags.each do |tag|
          data = tables[tag]
          head_offset = body_offset + body.bytesize if tag == "head"
          directory << [tag, checksum(data), body_offset + body.bytesize, data.bytesize].pack("a4NNN")
          body << data << padding(data)
        end

        font = directory << body
        font[head_offset + 8, 4] = [(CHECKSUM_MAGIC - checksum(font)) & 0xFFFFFFFF].pack("N")
        font
      end

      def padding(data)
        "\0".b * (-data.bytesize % 4)
      end
    end
  end
end
