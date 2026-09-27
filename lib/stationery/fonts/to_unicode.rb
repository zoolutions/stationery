# frozen_string_literal: true

module Stationery
  module Fonts
    # The ToUnicode CMap mapping each two-byte character code a document drew
    # back to its text, so the PDF extracts and searches correctly.
    module ToUnicode
      module_function

      # `chars` is { code => text }; a ligature maps to several characters.
      def cmap(chars)
        mappings = chars.sort.map do |code, char|
          format("<%<code>04X> <%<utf16>s>", code:, utf16: char.encode(Encoding::UTF_16BE).unpack1("H*").upcase)
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
