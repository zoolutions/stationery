# frozen_string_literal: true

module Stationery
  module Fonts
    class Gsub
      # SingleSubst (GSUB lookup type 1): one glyph for another. Format 1
      # adds a delta to every covered glyph, format 2 lists the substitute
      # for each covered glyph in coverage order. Small caps, oldstyle and
      # tabular figures, stylistic sets and slashed zero are all this.
      class SingleSubst
        def self.read(ttf, offset)
          format = ttf.u16(offset)
          coverage = Gpos::Coverage.read(ttf, offset + ttf.u16(offset + 2))
          case format
          when 1
            delta = ttf.i16(offset + 4)
            new(coverage.to_h { |gid| [gid, (gid + delta) & 0xFFFF] })
          when 2
            substitutes = ttf.data.byteslice(offset + 6, ttf.u16(offset + 4) * 2).unpack("n*")
            new(coverage.zip(substitutes).to_h.compact)
          end
        end

        def initialize(map)
          @map = map.freeze
          freeze
        end

        # [substitute gid, 1] for a covered glyph at `index`, or nil.
        def match(gids, index)
          gid = @map[gids[index]]
          [gid, 1] if gid
        end
      end
    end
  end
end
