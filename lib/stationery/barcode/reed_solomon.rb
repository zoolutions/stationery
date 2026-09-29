# frozen_string_literal: true

module Stationery
  module Barcode
    # Reed–Solomon error correction over GF(256) built on `polynomial`, the
    # generator's roots starting at α^`first_root`: QR codes use 0x11D
    # (x⁸ + x⁴ + x³ + x² + 1) from α⁰, Data Matrix 0x12D (x⁸ + x⁵ + x³ + x² + 1)
    # from α¹.
    class ReedSolomon
      def initialize(polynomial, first_root)
        @exp = Array.new(512)
        @log = Array.new(256, 0)
        value = 1
        255.times do |power|
          @exp[power] = value
          @log[value] = power
          value <<= 1
          value ^= polynomial if value > 255
        end
        (255...512).each { |power| @exp[power] = @exp[power - 255] }
        @first_root = first_root
        @divisors = {}
      end

      def multiply(a, b) = a.zero? || b.zero? ? 0 : @exp[@log[a] + @log[b]]

      # The generator polynomial of `degree`, highest power first and its
      # leading 1 left out.
      def divisor(degree)
        @divisors[degree] ||= begin
          result = Array.new(degree, 0)
          result[-1] = 1
          root = @exp[@first_root]
          degree.times do
            degree.times do |j|
              result[j] = multiply(result[j], root)
              result[j] ^= result[j + 1] if j + 1 < degree
            end
            root = multiply(root, 2)
          end
          result
        end
      end

      # The `degree` error correction codewords of `data`.
      def remainder(data, degree)
        divisor = divisor(degree)
        result = Array.new(degree, 0)
        data.each do |byte|
          factor = byte ^ result.shift
          result << 0
          divisor.each_with_index { |coefficient, i| result[i] ^= multiply(coefficient, factor) }
        end
        result
      end

      QR = new(0x11D, 0)
      DATA_MATRIX = new(0x12D, 1)
    end
  end
end
