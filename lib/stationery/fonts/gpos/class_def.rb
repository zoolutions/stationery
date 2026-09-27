# frozen_string_literal: true

module Stationery
  module Fonts
    class Gpos
      # OpenType ClassDef table as a Hash of glyph id => class. Glyphs it
      # does not list are class 0. Format 1 is a run of classes from a start
      # glyph, format 2 ranges of glyphs sharing a class.
      module ClassDef
        def self.read(ttf, offset)
          if ttf.u16(offset) == 1
            start = ttf.u16(offset + 2)
            classes = ttf.data.byteslice(offset + 6, ttf.u16(offset + 4) * 2).unpack("n*")
            return classes.each_with_index.to_h { |klass, i| [start + i, klass] }.freeze
          end

          ranges = ttf.data.byteslice(offset + 4, ttf.u16(offset + 2) * 6).unpack("n*").each_slice(3)
          ranges.each_with_object({}) do |(first, last, klass), map|
            (first..last).each { |gid| map[gid] = klass }
          end.freeze
        end
      end
    end
  end
end
