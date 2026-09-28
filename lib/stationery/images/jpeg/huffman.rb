# frozen_string_literal: true

module Stationery
  module Images
    class JPEG
      # A Huffman table of a DHT segment, as the decoder reads it: `lookup`
      # answers a code of up to LOOKAHEAD bits at once from the next
      # LOOKAHEAD bits of the stream (an entry is `length << 8 | symbol`, 0
      # for a longer code); a longer code is found length by length through
      # `maxcode` and `offset`, as libjpeg does.
      class Huffman
        LOOKAHEAD = 9

        attr_reader :lookup, :maxcode, :offset, :symbols

        # `counts` holds how many codes there are of each length 1 to 16,
        # `symbols` the values in code order.
        def initialize(counts, symbols)
          raise UnsupportedImage, "invalid JPEG image: bad Huffman table" if counts.sum > symbols.size

          @symbols = symbols
          @lookup = Array.new(1 << LOOKAHEAD, 0)
          @maxcode = Array.new(18, -1)
          @offset = Array.new(18, 0)
          build(counts)
          @maxcode[17] = 0xFFFFF # a sentinel: ends the search on corrupt data
        end

        private

        def build(counts)
          code = 0
          index = 0
          counts.each_with_index do |count, i|
            length = i + 1
            if count.positive?
              @offset[length] = index - code
              count.times do
                fill(code, length, @symbols[index]) if length <= LOOKAHEAD
                code += 1
                index += 1
              end
              @maxcode[length] = code - 1
            end
            raise UnsupportedImage, "invalid JPEG image: bad Huffman table" if code > (1 << length)

            code <<= 1
          end
        end

        def fill(code, length, symbol)
          spare = LOOKAHEAD - length
          first = code << spare
          (1 << spare).times { |i| @lookup[first + i] = (length << 8) | symbol }
        end
      end
    end
  end
end
