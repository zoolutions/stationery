# frozen_string_literal: true

module Stationery
  module Images
    class WebP
      # Reads a VP8L bitstream least significant bit first. Bits are kept in
      # one Integer window refilled four bytes at a time; past the end of the
      # data the window fills with zeros and `overrun?` turns true, so the
      # decoder's loops stay free of bounds checks and end on their own.
      class BitReader
        # Most bits one `read` may ask for; the window then stays a Fixnum.
        MAX_BITS = 24

        def initialize(data, pos = 0, limit = data.bytesize)
          @data = data
          @pos = pos
          @limit = limit
          @window = 0
          @bits = 0
          @missing = 0
        end

        def read(count)
          fill if @bits < count
          value = @window & ((1 << count) - 1)
          @window >>= count
          @bits -= count
          value
        end

        # The next symbol of a prefix code, from its lookup table (see
        # PrefixCode): an entry holds the code's length above bit 16, and one
        # at LINK or above points into a second-level table for codes longer
        # than ROOT_BITS.
        def symbol(table)
          fill if @bits < MAX_BITS
          entry = table[@window & PrefixCode::ROOT_MASK]
          if entry >= PrefixCode::LINK
            @window >>= PrefixCode::ROOT_BITS
            @bits -= PrefixCode::ROOT_BITS
            entry = table[(entry & 0xFFFF) + (@window & ((1 << ((entry >> 16) & 0xF)) - 1))]
          end
          length = entry >> 16
          @window >>= length
          @bits -= length
          entry & 0xFFFF
        end

        # True once more bits were consumed than the data holds.
        def overrun? = @bits < @missing

        private

        def fill
          if @pos + 4 <= @limit
            @window |= @data.unpack1("V", offset: @pos) << @bits
            @pos += 4
            @bits += 32
          else
            fill_tail
          end
        end

        def fill_tail
          while @bits < MAX_BITS
            if @pos < @limit
              @window |= @data.getbyte(@pos) << @bits
              @pos += 1
            else
              @missing += 8
            end
            @bits += 8
          end
        end
      end
    end
  end
end
