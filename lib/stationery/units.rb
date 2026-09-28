# frozen_string_literal: true

module Stationery
  # Lengths in the units paper, labels and envelopes are specified in, as
  # points (1/72 inch), which is what every size and position is given in:
  #
  #   page size: [mm(102), mm(74)], margin: mm(3)
  #   box(at: [mm(20), mm(45)], width: cm(9)) { … }
  #
  # Every component and document has them; anything else gets them with
  # `include Stationery::Units` (in its body and in its instances, as private
  # methods), or calls `Stationery::Units.mm(102)`. `points` reads a length
  # written with its unit, which is what `page size:` and `margin:` take.
  module Units
    UNITS = { "mm" => :mm, "cm" => :cm, "in" => :inch, "pt" => :pt }.freeze
    NUMBER = /\d+(?:\.\d+)?/
    # Digits, with a fraction after a point if any, then mm, cm, in or pt in
    # either case: no sign, no exponent and no comma. Spaces may surround the
    # number and the unit.
    LENGTH = /\A *(#{NUMBER}) *(mm|cm|in|pt) *\z/i

    def self.included(base)
      super
      base.extend(self)
    end

    # The points of "102mm", "10.2 cm", "4in" or "12pt".
    def self.points(text)
      match = LENGTH.match(text) if text.is_a?(String)
      return convert(match[1], match[2]) if match

      raise ArgumentError, "#{text.inspect} is not a length (use a number with its unit, mm, cm, in or pt, " \
                           'as in "102mm", "10.2 cm", "4in" or "12pt")'
    end

    def self.convert(number, unit) = send(UNITS.fetch(unit.downcase), Float(number))

    module_function

    def mm(value) = value * 72 / 25.4
    def cm(value) = value * 720 / 25.4
    def inch(value) = value * 72
    def pt(value) = value
  end
end
