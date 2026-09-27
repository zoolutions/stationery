# frozen_string_literal: true

module Stationery
  module Fonts
    # Pair kerning from a TrueType `kern` table: the OpenType (version 0)
    # layout with horizontal format 0 subtables. Apple's version 1 table,
    # vertical, cross-stream and class-based subtables are ignored.
    class KernTable
      HORIZONTAL = 0x0001
      CROSS_STREAM = 0x0004
      OVERRIDE = 0x0008
      SUBTABLE_HEADER = 6
      PAIR = 6

      # nil when the font has no usable kern table.
      def self.parse(ttf)
        offset = ttf.table_offset("kern")
        return unless offset && ttf.u16(offset).zero?

        pairs = {}
        cursor = offset + 4
        ttf.u16(offset + 2).times { cursor = read_subtable(ttf, cursor, pairs) }
        new(pairs)
      end

      # Returns the offset of the next subtable. A format 0 subtable's length
      # is derived from its pair count: large tables overflow the 16-bit field.
      def self.read_subtable(ttf, offset, pairs)
        coverage = ttf.u16(offset + 4)
        return offset + ttf.u16(offset + 2) unless (coverage >> 8).zero?

        count = ttf.u16(offset + SUBTABLE_HEADER)
        start = offset + SUBTABLE_HEADER + 8
        if coverage.anybits?(HORIZONTAL) && coverage.nobits?(CROSS_STREAM)
          ttf.data.byteslice(start, count * PAIR).unpack("nns>" * count).each_slice(3) do |left, right, value|
            key = (left << 16) | right
            pairs[key] = coverage.nobits?(OVERRIDE) ? pairs.fetch(key, 0) + value : value
          end
        end
        start + (count * PAIR)
      end
      private_class_method :read_subtable

      def initialize(pairs)
        @pairs = pairs.freeze
        freeze
      end

      def adjust(left, right) = @pairs.fetch((left << 16) | right, 0)
    end
  end
end
