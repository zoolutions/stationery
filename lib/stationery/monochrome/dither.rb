# frozen_string_literal: true

module Stationery
  module Monochrome
    # Grey to one bit: `grey` is a binary String of `width` × `height` 8-bit
    # samples (0 black, 255 white), row by row; the answer is the rows packed
    # eight pixels to a byte, most significant bit first, each row padded to
    # a whole byte, 1 for white: a DeviceGray image of one bit per component.
    #
    # :floyd_steinberg spreads each pixel's error over its neighbours (7/16
    # right, 3/16, 5/16 and 1/16 on the row below), which keeps detail and
    # tone; :ordered compares with an 8 × 8 Bayer matrix, a regular pattern
    # that survives being printed again; :threshold cuts at half.
    module Dither
      BAYER = [
        [0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
        [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
        [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
        [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21]
      ].map { |row| row.map { |v| ((v + 0.5) * 4).round }.freeze }.freeze

      module_function

      def call(grey, width, height, method)
        bits = case method
               when :floyd_steinberg then floyd_steinberg(grey.bytes, width, height)
               when :ordered then ordered(grey.bytes, width)
               when :threshold then grey.bytes.map { |v| v >= 128 ? 1 : 0 }
               else raise ArgumentError, "unknown dither #{method.inspect} (use #{DITHERS.map(&:inspect).join(", ")})"
               end
        pack(bits, width, height)
      end

      def ordered(samples, width)
        samples.each_with_index.map do |value, index|
          value > BAYER[(index / width) % 8][index % width % 8] ? 1 : 0
        end
      end

      # Errors are carried as Integers, in sixteenths.
      def floyd_steinberg(samples, width, height)
        bits = Array.new(width * height)
        below = Array.new(width + 2, 0)
        height.times do |y|
          current = below
          below = Array.new(width + 2, 0)
          carry = 0
          width.times do |x|
            index = (y * width) + x
            value = samples[index] + ((carry + current[x + 1]) / 16)
            bit = value >= 128 ? 1 : 0
            bits[index] = bit
            error = value - (bit * 255)
            carry = error * 7
            below[x] += error * 3
            below[x + 1] += error * 5
            below[x + 2] += error
          end
        end
        bits
      end

      def pack(bits, width, height)
        stride = ((width + 7) / 8) * 8
        rows = Array.new(height) do |y|
          row = bits[y * width, width]
          row.fill(1, width, stride - width) if stride > width
          row.join
        end
        [rows.join].pack("B*")
      end
    end
  end
end
