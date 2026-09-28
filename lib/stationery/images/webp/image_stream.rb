# frozen_string_literal: true

module Stationery
  module Images
    class WebP
      # One entropy-coded image of a VP8L bitstream, decoded to an Array of
      # ARGB Integers: the pixels themselves (with the entropy image choosing
      # a group of prefix codes per block) and the smaller images the
      # transforms and the entropy image are stored as.
      class ImageStream
        LITERALS = 256
        LENGTH_CODES = 24
        DISTANCE_CODES = 40
        MAX_CACHE_BITS = 11
        HASH = 0x1E35A7BD
        # Distance codes 1..120 name a pixel near the current one: the
        # vertical offset in the high nibble, 8 minus the horizontal one in
        # the low nibble.
        NEIGHBOURS = [
          0x18, 0x07, 0x17, 0x19, 0x28, 0x06, 0x27, 0x29, 0x16, 0x1a, 0x26, 0x2a, 0x38, 0x05, 0x37, 0x39, 0x15, 0x1b,
          0x36, 0x3a, 0x25, 0x2b, 0x48, 0x04, 0x47, 0x49, 0x14, 0x1c, 0x35, 0x3b, 0x46, 0x4a, 0x24, 0x2c, 0x58, 0x45,
          0x4b, 0x34, 0x3c, 0x03, 0x57, 0x59, 0x13, 0x1d, 0x56, 0x5a, 0x23, 0x2d, 0x44, 0x4c, 0x55, 0x5b, 0x33, 0x3d,
          0x68, 0x02, 0x67, 0x69, 0x12, 0x1e, 0x66, 0x6a, 0x22, 0x2e, 0x54, 0x5c, 0x43, 0x4d, 0x65, 0x6b, 0x32, 0x3e,
          0x78, 0x01, 0x77, 0x79, 0x53, 0x5d, 0x11, 0x1f, 0x64, 0x6c, 0x42, 0x4e, 0x76, 0x7a, 0x21, 0x2f, 0x75, 0x7b,
          0x31, 0x3f, 0x63, 0x6d, 0x52, 0x5e, 0x00, 0x74, 0x7c, 0x41, 0x4f, 0x10, 0x20, 0x62, 0x6e, 0x30, 0x73, 0x7d,
          0x51, 0x5f, 0x40, 0x72, 0x7e, 0x61, 0x6f, 0x50, 0x71, 0x7f, 0x60, 0x70
        ].freeze

        def self.decode(reader, width, height, top: false) = new(reader, width, height).decode(top:)

        # The side of an image stored at one sample per 2**bits pixels.
        def self.subsample(size, bits) = (size + (1 << bits) - 1) >> bits

        def initialize(reader, width, height)
          @reader = reader
          @width = width
          @height = height
        end

        # Only the top-level image may carry an entropy image.
        def decode(top:)
          read_cache
          read_entropy_image if top && @reader.read(1) == 1
          read_groups
          pixels
        end

        private

        def read_cache
          return if @reader.read(1).zero?

          bits = @reader.read(4)
          raise UnsupportedImage, "invalid WebP image: colour cache size" unless (1..MAX_CACHE_BITS).cover?(bits)

          @cache = Array.new(1 << bits, 0)
          @shift = 32 - bits
        end

        def read_entropy_image
          @block_bits = @reader.read(3) + 2
          @block_mask = (1 << @block_bits) - 1
          @blocks_wide = self.class.subsample(@width, @block_bits)
          image = self.class.decode(@reader, @blocks_wide, self.class.subsample(@height, @block_bits))
          @entropy = image.map { |argb| (argb >> 8) & 0xFFFF }
        end

        # Five prefix codes per group: green (with lengths and cache
        # indexes), red, blue, alpha and distance. Groups no block refers to
        # are read and dropped.
        def read_groups
          used = @entropy ? @entropy.uniq.to_h { |index| [index, true] } : { 0 => true }
          green = LITERALS + LENGTH_CODES + (@cache ? @cache.size : 0)
          @groups = Array.new(used.keys.max + 1) do |index|
            codes = [green, LITERALS, LITERALS, LITERALS, DISTANCE_CODES].map { |size| PrefixCode.read(@reader, size) }
            codes << literal_base(codes) if used[index]
          end
        end

        # Red, blue and alpha in place when all three codes hold one symbol,
        # so a pixel is one green symbol away; nil otherwise.
        def literal_base(codes)
          red, blue, alpha = codes[1, 3].map { |table| table[0] }
          return if [red, blue, alpha].any? { |entry| entry > 0xFFFF }

          (alpha << 24) | (red << 16) | blue
        end

        # rubocop:disable-next Metrics/AbcSize, Metrics/MethodLength -- the pixel loop, kept in one frame
        def pixels
          out = Array.new(@width * @height, 0)
          total = out.size
          reader = @reader
          cache = @cache
          group = @groups[0]
          pos = 0
          column = 0
          while pos < total
            group = group_at(pos) if @entropy && column.nobits?(@block_mask)
            green = reader.symbol(group[0])
            if green >= LITERALS && green < LITERALS + LENGTH_CODES
              pos = copy(out, pos, extent(green - LITERALS), extent(reader.symbol(group[4])))
              column = pos % @width
              group = group_at(pos) if @entropy && pos < total
              next
            end

            argb = if green >= LITERALS
                     cache[green - LITERALS - LENGTH_CODES]
                   elsif (base = group[5])
                     base | (green << 8)
                   else
                     red = reader.symbol(group[1])
                     blue = reader.symbol(group[2])
                     (reader.symbol(group[3]) << 24) | (red << 16) | (green << 8) | blue
                   end
            out[pos] = argb
            cache[((argb * HASH) & 0xFFFFFFFF) >> @shift] = argb if cache
            pos += 1
            column += 1
            column = 0 if column == @width
          end
          out
        end

        def group_at(pos)
          @groups[@entropy[(((pos / @width) >> @block_bits) * @blocks_wide) + ((pos % @width) >> @block_bits)]]
        end

        # The length or distance code a prefix symbol and its extra bits
        # stand for.
        def extent(symbol)
          return symbol + 1 if symbol < 4

          bits = (symbol - 2) >> 1
          ((2 + (symbol & 1)) << bits) + @reader.read(bits) + 1
        end

        # Repeats `length` pixels from `code` back (overlapping on purpose:
        # a run repeats itself) and returns the position after them.
        def copy(out, pos, length, code)
          distance = distance_of(code)
          stop = pos + length
          raise UnsupportedImage, "invalid WebP image: backward reference out of range" if distance > pos
          raise UnsupportedImage, "invalid WebP image: backward reference past the end" if stop > out.size

          cache = @cache
          source = pos - distance
          while pos < stop
            argb = out[source]
            out[pos] = argb
            cache[((argb * HASH) & 0xFFFFFFFF) >> @shift] = argb if cache
            source += 1
            pos += 1
          end
          stop
        end

        def distance_of(code)
          return code - NEIGHBOURS.size if code > NEIGHBOURS.size

          neighbour = NEIGHBOURS[code - 1]
          [((neighbour >> 4) * @width) + 8 - (neighbour & 0xF), 1].max
        end
      end
    end
  end
end
