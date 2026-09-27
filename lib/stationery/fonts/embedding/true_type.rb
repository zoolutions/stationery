# frozen_string_literal: true

module Stationery
  module Fonts
    module Embedding
      # A CIDFontType2 over a TrueType subset holding only the drawn glyphs.
      # Text uses the original glyph ids as CIDs; CIDToGIDMap maps them to the
      # subset's renumbered ids.
      class TrueType < Base
        # Returns [base_font_name, cid_font_reference].
        def build(writer, gids)
          subset, mapping = Subset.build(@ttf, gids)
          name = :"#{subset_tag(gids)}+#{@ttf.postscript_name}"
          font_file = writer.add(PDF::Stream.new(subset, { Length1: subset.bytesize }))

          cid_font = writer.add(
            Type: :Font, Subtype: :CIDFontType2, BaseFont: name, CIDSystemInfo: IDENTITY,
            FontDescriptor: descriptor(writer, name, FontFile2: font_file),
            DW: glyph_space(@ttf.advance(0)), W: widths(gids),
            CIDToGIDMap: writer.add(PDF::Stream.new(cid_to_gid_map(gids, mapping)))
          )
          [name, cid_font]
        end

        private

        def cid_to_gid_map(gids, mapping)
          map = Array.new((gids.max || 0) + 1, 0)
          gids.each { |gid| map[gid] = mapping.fetch(gid) }
          map.pack("n*")
        end
      end
    end
  end
end
