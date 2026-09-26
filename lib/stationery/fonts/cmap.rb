# frozen_string_literal: true

module Stationery
  module Fonts
    # Parses a font's Unicode character map (formats 4 and 12) into a Hash of
    # codepoint => glyph id.
    module Cmap
      module_function

      def parse(ttf)
        t = ttf.table_offset("cmap")
        subtables = Array.new(ttf.u16(t + 2)) do |i|
          record = t + 4 + (i * 8)
          offset = t + ttf.u32(record + 4)
          [ttf.u16(record), ttf.u16(record + 2), offset, ttf.u16(offset)]
        end

        best = preferred(subtables)
        raise UnsupportedFont, "font has no Unicode character map" unless best

        best[3] == 12 ? format12(ttf, best[2]) : format4(ttf, best[2])
      end

      # Full Unicode (format 12) wins over the Basic Multilingual Plane (format 4).
      def preferred(subtables)
        subtables.find { |platform, encoding, _, format| platform == 3 && encoding == 10 && format == 12 } ||
          subtables.find { |platform, _, _, format| platform.zero? && format == 12 } ||
          subtables.find { |platform, encoding, _, format| platform == 3 && encoding == 1 && format == 4 } ||
          subtables.find { |platform, _, _, format| platform.zero? && format == 4 }
      end

      def format4(ttf, offset)
        map = {}
        seg_count = ttf.u16(offset + 6) / 2
        ends = offset + 14
        starts = ends + (seg_count * 2) + 2
        deltas = starts + (seg_count * 2)
        range_offsets = deltas + (seg_count * 2)

        seg_count.times do |i|
          range = ttf.u16(starts + (i * 2))..ttf.u16(ends + (i * 2))
          format4_segment(ttf, map, range, ttf.u16(deltas + (i * 2)), range_offsets + (i * 2))
        end
        map
      end

      def format4_segment(ttf, map, range, delta, range_offset_pos)
        range_offset = ttf.u16(range_offset_pos)
        first = range.begin
        range.each do |codepoint|
          next if codepoint == 0xFFFF

          gid = if range_offset.zero?
                  (codepoint + delta) & 0xFFFF
                else
                  glyph = ttf.u16(range_offset_pos + range_offset + ((codepoint - first) * 2))
                  glyph.zero? ? 0 : (glyph + delta) & 0xFFFF
                end
          map[codepoint] = gid unless gid.zero?
        end
      end

      def format12(ttf, offset)
        map = {}
        ttf.u32(offset + 12).times do |i|
          group = offset + 16 + (i * 12)
          first = ttf.u32(group)
          gid = ttf.u32(group + 8)
          (first..ttf.u32(group + 4)).each { |codepoint| map[codepoint] = gid + codepoint - first }
        end
        map
      end
    end
  end
end
