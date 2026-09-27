# frozen_string_literal: true

module Stationery
  module Fonts
    class Gpos
      # PairPos subtables (GPOS lookup type 2), keeping only the first glyph's
      # X advance. `adjust` answers nil when the subtable does not apply, so
      # the lookup tries its next subtable.
      module PairPos
        X_ADVANCE = 0x0004

        def self.read(ttf, offset)
          ttf.u16(offset) == 1 ? Pairs.read(ttf, offset) : Classes.read(ttf, offset)
        end

        # The first glyph's X advance of `count` records at `offset`, each
        # `lead` 16-bit fields (a second glyph id) followed by two value
        # records. A value record has one field per bit set in its format.
        def self.x_advances(ttf, offset, count, format1, format2, lead: 0)
          width = [lead + fields(format1) + fields(format2), 1].max
          records = ttf.data.byteslice(offset, count * width * 2).unpack("s>*").each_slice(width)
          return records.map { |record| [record.first & 0xFFFF, 0] } unless format1.anybits?(X_ADVANCE)

          index = lead + fields(format1 & (X_ADVANCE - 1))
          records.map { |record| [record.first & 0xFFFF, record[index]] }
        end

        def self.fields(format) = format.to_s(2).count("1")

        # Format 1: explicit pairs, grouped by first glyph.
        class Pairs
          def self.read(ttf, offset)
            format1 = ttf.u16(offset + 4)
            format2 = ttf.u16(offset + 6)
            pairs = {}
            Coverage.read(ttf, offset + ttf.u16(offset + 2)).each_with_index do |left, i|
              set = offset + ttf.u16(offset + 10 + (i * 2))
              PairPos.x_advances(ttf, set + 2, ttf.u16(set), format1, format2, lead: 1).each do |right, value|
                pairs[(left << 16) | right] = value
              end
            end
            new(pairs)
          end

          def initialize(pairs)
            @pairs = pairs.freeze
            freeze
          end

          def adjust(left, right) = @pairs[(left << 16) | right]
        end

        # Format 2: a class-by-class matrix over two ClassDefs, kept as classes
        # rather than expanded into every glyph pair.
        class Classes
          def self.read(ttf, offset)
            format1 = ttf.u16(offset + 4)
            format2 = ttf.u16(offset + 6)
            columns = ttf.u16(offset + 14)
            values = PairPos.x_advances(ttf, offset + 16, ttf.u16(offset + 12) * columns, format1, format2)
            new(Coverage.read(ttf, offset + ttf.u16(offset + 2)),
                ClassDef.read(ttf, offset + ttf.u16(offset + 8)), ClassDef.read(ttf, offset + ttf.u16(offset + 10)),
                values.map(&:last).each_slice(columns).to_a)
          end

          def initialize(coverage, first_classes, second_classes, matrix)
            @coverage = coverage.to_h { |gid| [gid, true] }.freeze
            @first_classes = first_classes
            @second_classes = second_classes
            @matrix = matrix.each(&:freeze).freeze
            freeze
          end

          def adjust(left, right)
            return unless @coverage[left]

            @matrix.dig(@first_classes.fetch(left, 0), @second_classes.fetch(right, 0)) || 0
          end
        end
      end
    end
  end
end
