# frozen_string_literal: true

module Stationery
  module Fonts
    # Pair kerning from the GPOS `kern` feature: PairPos lookups (formats 1
    # and 2), directly or behind Extension lookups. Scripts and languages are
    # not distinguished; every lookup any `kern` feature record names applies.
    # Adjustments are the first glyph's X advance, in font units.
    class Gpos
      PAIR = 2
      EXTENSION = 9

      # nil when the font has no GPOS table or no `kern` feature.
      def self.parse(ttf)
        base = ttf.table_offset("GPOS")
        return unless base && ttf.u16(base) == 1

        indices = kern_lookups(ttf, base + ttf.u16(base + 6))
        return if indices.empty?

        list = base + ttf.u16(base + 8)
        new(indices.map { |i| lookup(ttf, list + ttf.u16(list + 2 + (i * 2))) })
      end

      def self.kern_lookups(ttf, list)
        records = Array.new(ttf.u16(list)) { |i| list + 2 + (i * 6) }
        records.select { |record| ttf.data.byteslice(record, 4) == "kern" }.flat_map do |record|
          feature = list + ttf.u16(record + 4)
          Array.new(ttf.u16(feature + 2)) { |j| ttf.u16(feature + 4 + (j * 2)) }
        end.uniq
      end

      # A lookup's PairPos subtables; other lookup types have none.
      def self.lookup(ttf, offset)
        type = ttf.u16(offset)
        subtables = Array.new(ttf.u16(offset + 4)) { |i| offset + ttf.u16(offset + 6 + (i * 2)) }
        subtables.filter_map do |subtable|
          if type == PAIR
            PairPos.read(ttf, subtable)
          elsif type == EXTENSION && ttf.u16(subtable + 2) == PAIR
            PairPos.read(ttf, subtable + ttf.u32(subtable + 4))
          end
        end.freeze
      end
      private_class_method :kern_lookups, :lookup

      def initialize(lookups)
        @lookups = lookups.freeze
        freeze
      end

      # Within a lookup the first subtable that applies wins; lookups add up.
      def adjust(left, right)
        @lookups.sum do |subtables|
          value = nil
          subtables.find { |subtable| value = subtable.adjust(left, right) }
          value || 0
        end
      end
    end
  end
end
