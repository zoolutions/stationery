# frozen_string_literal: true

module Stationery
  module Fonts
    module Embedding
      # A CIDFontType0 over the font's CFF table with every undrawn glyph
      # blanked (FontFile3 /CIDFontType0C). Codes are CIDs: the charset's for
      # a CID-keyed font, glyph ids for a name-keyed one, so no CIDToGIDMap is
      # needed.
      class CFF < Base
        # Returns [base_font_name, cid_font_reference].
        def build(writer, gids)
          name = :"#{subset_tag(gids)}+#{@ttf.postscript_name}"
          font_file = writer.add(PDF::Stream.new(CffSubset.build(@ttf.cff, gids), { Subtype: :CIDFontType0C }))

          cid_font = writer.add(
            Type: :Font, Subtype: :CIDFontType0, BaseFont: name, CIDSystemInfo: system_info,
            FontDescriptor: descriptor(writer, name, FontFile3: font_file),
            DW: glyph_space(@ttf.advance(0)), W: widths(gids)
          )
          [name, cid_font]
        end

        private

        def system_info
          registry, ordering, supplement = @ttf.cff.ros
          return IDENTITY unless registry

          { Registry: registry, Ordering: ordering, Supplement: supplement }
        end
      end
    end
  end
end
