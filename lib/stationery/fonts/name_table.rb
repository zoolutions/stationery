# frozen_string_literal: true

module Stationery
  module Fonts
    # Reads the PostScript name (name id 6) used as the embedded font's BaseFont.
    module NameTable
      FORBIDDEN = "[](){}<>/%#"

      module_function

      def postscript_name(ttf)
        name = find(ttf) if ttf.table?("name")
        name.nil? || name.empty? ? "Font" : name
      end

      def find(ttf)
        t = ttf.table_offset("name")
        strings = t + ttf.u16(t + 4)
        ttf.u16(t + 2).times do |i|
          record = t + 6 + (i * 12)
          next unless ttf.u16(record + 6) == 6

          raw = ttf.data.byteslice(strings + ttf.u16(record + 10), ttf.u16(record + 8)).dup
          name = decode(raw, ttf.u16(record)).delete("^!-~").delete(FORBIDDEN)
          return name unless name.empty?
        end
        nil
      end

      def decode(raw, platform)
        if platform == 1
          raw.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8)
        else
          raw.force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        end
      end
    end
  end
end
