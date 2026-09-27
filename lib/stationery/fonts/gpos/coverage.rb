# frozen_string_literal: true

module Stationery
  module Fonts
    class Gpos
      # OpenType Coverage table: the glyphs a subtable applies to, in
      # coverage-index order. Format 1 lists glyphs, format 2 ranges.
      module Coverage
        def self.read(ttf, offset)
          count = ttf.u16(offset + 2)
          return ttf.data.byteslice(offset + 4, count * 2).unpack("n*") if ttf.u16(offset) == 1

          ttf.data.byteslice(offset + 4, count * 6).unpack("n*").each_slice(3).flat_map do |first, last, _index|
            (first..last).to_a
          end
        end
      end
    end
  end
end
