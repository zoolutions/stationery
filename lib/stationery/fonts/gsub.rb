# frozen_string_literal: true

module Stationery
  module Fonts
    # Standard ligatures from the GSUB `liga` feature: LigatureSubst lookups
    # (format 1), directly or behind Extension lookups. Only `liga` applies;
    # contextual (`clig`) and discretionary (`dlig`) ligatures are left out.
    # Scripts, languages and lookup flags are not distinguished.
    class Gsub
      LIGATURE = 4
      EXTENSION = 7

      # nil when the font has no GSUB table or no `liga` ligatures.
      def self.parse(ttf)
        base = ttf.table_offset("GSUB")
        return unless base && ttf.u16(base) == 1

        lookups = Gpos.feature_lookups(ttf, base, "liga").map { |offset| lookup(ttf, offset) }.reject(&:empty?)
        new(lookups) if lookups.any?
      end

      # A lookup's LigatureSubst subtables; other lookup types have none.
      def self.lookup(ttf, offset)
        type = ttf.u16(offset)
        subtables = Array.new(ttf.u16(offset + 4)) { |i| offset + ttf.u16(offset + 6 + (i * 2)) }
        subtables.filter_map do |subtable|
          if type == LIGATURE
            LigatureSubst.read(ttf, subtable)
          elsif type == EXTENSION && ttf.u16(subtable + 2) == LIGATURE
            LigatureSubst.read(ttf, subtable + ttf.u32(subtable + 4))
          end
        end.freeze
      end
      private_class_method :lookup

      def initialize(lookups)
        @lookups = lookups.freeze
        freeze
      end

      # [[gid, number of source glyphs it stands for], ...]. Lookups apply in
      # order; within one, the first subtable matching at a position wins and
      # its glyph is not matched again by that lookup.
      def substitute(gids)
        @lookups.reduce(gids.map { |gid| [gid, 1] }) { |glyphs, subtables| apply(subtables, glyphs) }
      end

      private

      def apply(subtables, glyphs)
        ids = glyphs.map(&:first)
        result = []
        i = 0
        while i < glyphs.size
          match = nil
          subtables.find { |subtable| match = subtable.match(ids, i) }
          length = match ? match.last : 1
          result << [match ? match.first : ids[i], glyphs[i, length].sum(&:last)]
          i += length
        end
        result
      end
    end
  end
end
