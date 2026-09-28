# frozen_string_literal: true

module Stationery
  module Images
    class WebP
      # Canonical prefix (Huffman) codes as lookup tables. A table is a flat
      # Array indexed by the next ROOT_BITS bits of the stream: an entry is
      # `length << 16 | symbol`; codes longer than ROOT_BITS share a LINK
      # entry (`LINK | bits << 16 | offset`) to a second-level table appended
      # after the root. A code with a single symbol takes no bits at all.
      module PrefixCode
        ROOT_BITS = 8
        ROOT_SIZE = 1 << ROOT_BITS
        ROOT_MASK = ROOT_SIZE - 1
        LINK = 1 << 20
        MAX_LENGTH = 15
        # The order the lengths of the code-length code are stored in.
        LENGTH_ORDER = [17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15].freeze
        # Extra bits and base of the repeat codes 16, 17 and 18.
        REPEATS = [[2, 3], [3, 3], [7, 11]].freeze

        module_function

        # Reads one prefix code over `size` symbols and returns its table.
        def read(reader, size)
          build(reader.read(1) == 1 ? simple_lengths(reader, size) : coded_lengths(reader, size))
        end

        # One or two symbols stored as they are, the code being 0 or 1 bit.
        def simple_lengths(reader, size)
          count = reader.read(1) + 1
          symbols = [reader.read(reader.read(1) == 1 ? 8 : 1)]
          symbols << reader.read(8) if count == 2
          raise UnsupportedImage, "invalid WebP image: prefix code symbol out of range" if symbols.max >= size

          lengths = Array.new(size, 0)
          symbols.each { |symbol| lengths[symbol] = 1 }
          lengths
        end

        # Code lengths that are themselves prefix coded, with repeat codes.
        def coded_lengths(reader, size)
          code_lengths = Array.new(LENGTH_ORDER.size, 0)
          (reader.read(4) + 4).times { |i| code_lengths[LENGTH_ORDER[i]] = reader.read(3) }
          table = build(code_lengths)
          remaining = reader.read(1) == 1 ? 2 + reader.read(2 + (2 * reader.read(3))) : size
          raise UnsupportedImage, "invalid WebP image: too many code lengths" if remaining > size

          expand(reader, table, size, remaining)
        end

        def expand(reader, table, size, remaining)
          lengths = Array.new(size, 0)
          previous = 8
          symbol = 0
          while symbol < size && remaining.positive?
            remaining -= 1
            length = reader.symbol(table)
            if length < 16
              lengths[symbol] = length
              symbol += 1
              previous = length unless length.zero?
            else
              symbol = repeat(reader, lengths, symbol, length, previous)
            end
          end
          lengths
        end

        def repeat(reader, lengths, symbol, code, previous)
          bits, base = REPEATS[code - 16]
          count = reader.read(bits) + base
          raise UnsupportedImage, "invalid WebP image: code lengths overflow" if symbol + count > lengths.size

          lengths.fill(previous, symbol, count) if code == 16
          symbol + count
        end

        # The lookup table of the canonical code with these lengths, which
        # must be complete (every bit pattern decodes) or hold one symbol.
        def build(lengths)
          counts = Array.new(MAX_LENGTH + 1, 0)
          lengths.each { |length| counts[length] += 1 }
          used = lengths.size - counts[0]
          counts[0] = 0
          return Array.new(ROOT_SIZE, lengths.index(&:positive?)) if used == 1

          space = (1..MAX_LENGTH).sum { |length| counts[length] << (MAX_LENGTH - length) }
          raise UnsupportedImage, "invalid WebP image: incomplete prefix code" unless space == 1 << MAX_LENGTH

          fill(lengths, counts)
        end

        def fill(lengths, counts)
          codes = reversed_codes(lengths, counts)
          table = Array.new(ROOT_SIZE, 0)
          link(table, lengths, codes)
          lengths.each_with_index do |length, symbol|
            next if length.zero?

            code = codes[symbol]
            if length <= ROOT_BITS
              spread(table, 0, ROOT_BITS, code, length, (length << 16) | symbol)
            else
              entry = table[code & ROOT_MASK]
              spread(table, entry & 0xFFFF, (entry >> 16) & 0xF, code >> ROOT_BITS, length - ROOT_BITS,
                     ((length - ROOT_BITS) << 16) | symbol)
            end
          end
          table
        end

        # Every symbol's code with its bits reversed, since the stream is
        # read least significant bit first.
        def reversed_codes(lengths, counts)
          code = 0
          first = Array.new(MAX_LENGTH + 1, 0)
          (1..MAX_LENGTH).each { |length| first[length] = code = (code + counts[length - 1]) << 1 }
          lengths.map do |length|
            next 0 if length.zero?

            value = first[length]
            first[length] += 1
            reverse(value, length)
          end
        end

        def reverse(value, length)
          reversed = 0
          length.times do
            reversed = (reversed << 1) | (value & 1)
            value >>= 1
          end
          reversed
        end

        # Appends a second-level table for every root entry that long codes
        # share, sized for the longest of them.
        def link(table, lengths, codes)
          longest = {}
          lengths.each_with_index do |length, symbol|
            next unless length > ROOT_BITS

            root = codes[symbol] & ROOT_MASK
            longest[root] = length if length > longest.fetch(root, 0)
          end
          longest.each do |root, length|
            bits = length - ROOT_BITS
            table[root] = LINK | (bits << 16) | table.size
            table.concat(Array.new(1 << bits, 0))
          end
        end

        # Writes `entry` at every index of a `bits`-wide table whose low
        # `length` bits are `code`.
        def spread(table, offset, bits, code, length, entry)
          index = code
          size = 1 << bits
          step = 1 << length
          while index < size
            table[offset + index] = entry
            index += step
          end
        end
      end
    end
  end
end
