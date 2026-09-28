# frozen_string_literal: true

module Stationery
  module Barcode
    # Reed–Solomon error correction over GF(256) with the QR code's
    # polynomial (x⁸ + x⁴ + x³ + x² + 1, 0x11D).
    module ReedSolomon
      EXP = Array.new(512)
      LOG = Array.new(256, 0)
      value = 1
      255.times do |power|
        EXP[power] = value
        LOG[value] = power
        value <<= 1
        value ^= 0x11D if value > 255
      end
      (255...512).each { |power| EXP[power] = EXP[power - 255] }
      EXP.freeze
      LOG.freeze

      module_function

      def multiply(a, b) = a.zero? || b.zero? ? 0 : EXP[LOG[a] + LOG[b]]

      # The generator polynomial of `degree`, highest power first and its
      # leading 1 left out.
      def divisor(degree)
        result = Array.new(degree, 0)
        result[-1] = 1
        root = 1
        degree.times do
          degree.times do |j|
            result[j] = multiply(result[j], root)
            result[j] ^= result[j + 1] if j + 1 < degree
          end
          root = multiply(root, 2)
        end
        result
      end

      # The error correction codewords of `data` for `divisor`.
      def remainder(data, divisor)
        result = Array.new(divisor.size, 0)
        data.each do |byte|
          factor = byte ^ result.shift
          result << 0
          divisor.each_with_index { |coefficient, i| result[i] ^= multiply(coefficient, factor) }
        end
        result
      end
    end
  end
end
