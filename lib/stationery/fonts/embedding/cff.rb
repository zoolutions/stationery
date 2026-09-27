# frozen_string_literal: true

module Stationery
  module Fonts
    module Embedding
      # A CIDFontType0 over the whole OpenType file (FontFile3 /OpenType, PDF
      # 1.6). Codes are CIDs: the charset's for a CID-keyed font, glyph ids
      # for a name-keyed one, so no CIDToGIDMap is needed.
      class CFF < Base
        # Returns [base_font_name, cid_font_reference].
        def build(writer, gids)
          name = @ttf.postscript_name.to_sym
          font_file = writer.add(PDF::Stream.new(@ttf.data, { Subtype: :OpenType }))

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
