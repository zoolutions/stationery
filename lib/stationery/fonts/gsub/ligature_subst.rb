# frozen_string_literal: true

module Stationery
  module Fonts
    class Gsub
      # LigatureSubst format 1 (GSUB lookup type 4): for each first glyph, the
      # ligatures starting with it, longest first.
      class LigatureSubst
        def self.read(ttf, offset)
          return unless ttf.u16(offset) == 1

          sets = Gpos::Coverage.read(ttf, offset + ttf.u16(offset + 2)).each_with_index.to_h do |first, i|
            set = offset + ttf.u16(offset + 6 + (i * 2))
            [first, ligatures(ttf, set).sort_by.with_index { |(rest, _), j| [-rest.size, j] }.freeze]
          end
          new(sets)
        end

        # [[component gids after the first, ligature gid], ...]
        def self.ligatures(ttf, set)
          Array.new(ttf.u16(set)) do |i|
            ligature = set + ttf.u16(set + 2 + (i * 2))
            count = ttf.u16(ligature + 2)
            [ttf.data.byteslice(ligature + 4, (count - 1) * 2).unpack("n*").freeze, ttf.u16(ligature)]
          end
        end
        private_class_method :ligatures

        def initialize(sets)
          @sets = sets.freeze
          freeze
        end

        # [ligature gid, glyphs consumed] for the longest ligature at `index`, or nil.
        def match(gids, index)
          @sets[gids[index]]&.each do |components, ligature|
            return [ligature, components.size + 1] if gids[index + 1, components.size] == components
          end
          nil
        end
      end
    end
  end
end
