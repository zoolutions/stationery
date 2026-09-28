# frozen_string_literal: true

module Stationery
  module Barcode
    # EAN-13 (ISO/IEC 15420): twelve digits and the check digit, which is
    # computed when twelve are given and checked when thirteen are. 95
    # modules across between guard bars, with a quiet zone of 11 modules on
    # the left and 7 on the right; the digits under it are not drawn (write
    # them with `text` when they are wanted).
    class EAN13
      L = %w[0001101 0011001 0010011 0111101 0100011 0110001 0101111 0111011 0110111 0001011].freeze
      R = L.map { |code| code.tr("01", "10") }.freeze
      G = R.map(&:reverse).freeze
      # Which of L and G the six digits on the left use, by the first digit.
      PARITY = %w[LLLLLL LLGLGG LLGGLG LLGGGL LGLLGG LGGLLG LGGGLL LGLGLG LGLGGL LGGLGL].freeze
      QUIET = 11

      attr_reader :data

      def self.check_digit(digits)
        sum = digits.chars.each_with_index.sum { |digit, index| digit.to_i * (index.odd? ? 3 : 1) }
        ((10 - (sum % 10)) % 10).to_s
      end

      def initialize(data)
        digits = data.to_s
        raise ArgumentError, "EAN-13 takes 12 or 13 digits, not #{data.inspect}" unless digits.match?(/\A\d{12,13}\z/)

        check = self.class.check_digit(digits[0, 12])
        if digits.size == 13 && digits[12] != check
          raise ArgumentError, "the check digit of #{digits} is #{check}, not #{digits[12]}"
        end

        @data = digits[0, 12] + check
      end

      def linear? = true
      def native? = true
      # Dots ZPL draws the symbol below its ^FO.
      def zpl_top = 0
      def quiet = QUIET
      def width = 95

      def bars
        pattern.chars.each_with_index.chunk_while { |a, b| a[0] == b[0] }.filter_map do |run|
          [run[0][1], run.size] if run[0][0] == "1"
        end
      end

      # ^BE, which adds the check digit itself.
      def zpl(module_dots:, height_dots:)
        "^BY#{module_dots}^BEN,#{height_dots},N,N#{Barcode.field(@data[0, 12])}"
      end

      private

      def pattern
        left = @data[1, 6].chars.each_with_index.map do |digit, index|
          (PARITY[@data[0].to_i][index] == "L" ? L : G)[digit.to_i]
        end
        right = @data[7, 6].chars.map { |digit| R[digit.to_i] }
        "101#{left.join}01010#{right.join}101"
      end
    end
  end
end
