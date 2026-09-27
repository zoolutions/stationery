# frozen_string_literal: true

module Stationery
  # Ordered-list labels: decimal, alpha, roman (lower or upper case) or a
  # Proc given the number. Formats with no numeral for a number fall back to
  # decimal.
  module ListMarkers
    ROMAN = { 1000 => "m", 900 => "cm", 500 => "d", 400 => "cd", 100 => "c", 90 => "xc",
              50 => "l", 40 => "xl", 10 => "x", 9 => "ix", 5 => "v", 4 => "iv", 1 => "i" }.freeze

    module_function

    def label(format, number, suffix = ".") = "#{numeral(format, number)}#{suffix}"

    def numeral(format, number)
      case format
      when Proc then format.call(number).to_s
      when :decimal then number.to_s
      when :alpha then alpha(number)
      when :upper_alpha then alpha(number).upcase
      when :roman then roman(number)
      when :upper_roman then roman(number).upcase
      else raise ArgumentError, "unknown list format: #{format.inspect}"
      end
    end

    def alpha(number)
      return number.to_s if number < 1

      letters = +""
      while number.positive?
        number, rest = (number - 1).divmod(26)
        letters.prepend((97 + rest).chr)
      end
      letters
    end

    def roman(number)
      return number.to_s unless (1..3999).cover?(number)

      ROMAN.each_with_object(+"") do |(value, letters), numeral|
        count, number = number.divmod(value)
        numeral << (letters * count)
      end
    end
  end
end
