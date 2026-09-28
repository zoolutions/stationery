# frozen_string_literal: true

module Stationery
  module Images
    class JPEG
      # Reads the entropy-coded data of a scan most significant bit first,
      # one restart interval at a time: `start` takes the interval's bytes
      # with its stuffed zero bytes already taken out. Bits are kept in one
      # Integer window refilled four bytes at a time; past the end of the
      # interval it fills with zeros, as libjpeg does with a truncated file.
      class BitReader
        # The bits still unread when the window is refilled (never more than
        # 16), kept below the next four bytes: the window stays a Fixnum.
        KEEP = 0xFFFF
        PAD = "\0\0\0\0".b

        def initialize
          start("".b)
        end

        def start(data)
          @data = data
          @size = data.bytesize
          @pos = 0
          @window = 0
          @bits = 0
        end

        # The next symbol of a Huffman table.
        def symbol(table)
          fill if @bits < 16
          entry = table.lookup[(@window >> (@bits - Huffman::LOOKAHEAD)) & 511]
          if entry.zero?
            long_symbol(table)
          else
            @bits -= entry >> 8
            entry & 255
          end
        end

        def read(count)
          fill if @bits < count
          @bits -= count
          (@window >> @bits) & ((1 << count) - 1)
        end

        def bit
          fill if @bits < 1
          @bits -= 1
          (@window >> @bits) & 1
        end

        # `count` bits read as a signed difference (JPEG's EXTEND).
        def signed(count)
          value = read(count)
          value < (1 << (count - 1)) ? value - (1 << count) + 1 : value
        end

        private

        def fill
          chunk = @pos + 4 <= @size ? @data.unpack1("N", offset: @pos) : tail
          @window = ((@window & KEEP) << 32) | chunk
          @pos += 4
          @bits += 32
        end

        def tail
          return 0 if @pos >= @size

          (@data.byteslice(@pos, 4) + PAD).unpack1("N")
        end

        # A code longer than the lookahead: the length whose largest code
        # holds the next bits.
        def long_symbol(table)
          fill if @bits < 17
          length = Huffman::LOOKAHEAD + 1
          code = (@window >> (@bits - length)) & ((1 << length) - 1)
          while code > table.maxcode[length]
            length += 1
            code = (@window >> (@bits - length)) & ((1 << length) - 1)
          end
          @bits -= length
          return 0 if length > 16

          table.symbols[code + table.offset[length]] || 0
        end
      end
    end
  end
end
