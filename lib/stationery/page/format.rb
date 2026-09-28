# frozen_string_literal: true

module Stationery
  class Page
    # Reads and checks what `size:` and `margin:` take. A name and a value in
    # points are answered as they were given, so a document written in points
    # is configured as it was; lengths with a unit are answered in points.
    module Format
      # "4in x 6in", "102mm × 74mm", and "102 x 74 mm", where the first
      # length takes the unit of the second.
      SIZE = /\A *(#{Units::NUMBER}) *(mm|cm|in|pt)? *[x×] *(#{Units::NUMBER}) *(mm|cm|in|pt) *\z/i
      SIZES_TAKEN = '[width, height] in points, ["102mm", "74mm"] or "4in x 6in"'
      MARGINS_TAKEN = 'points or a length as "3mm", or one to four of them as [y, x], [top, x, bottom], ' \
                      "[top, right, bottom, left] or { top:, right:, bottom:, left:, x:, y: }"
      UNITS_TAKEN = "units are mm, cm, in and pt"

      module_function

      # A known name, two positive numbers, two lengths with their units or
      # both in one string; anything else raises.
      def size(value)
        size = case value
               when Array then pair(value)
               when String then named(value) || written(value)
               when Symbol then named(value)
               end
        size || raise(ArgumentError, "unknown page size #{value.inspect} " \
                                     "(use #{SIZES.keys.join(", ")}, #{SIZES_TAKEN}; #{UNITS_TAKEN})")
      end

      # What Geometry.box takes, each side a number or a length with its
      # unit; anything else raises.
      def margin(value)
        sides = value.is_a?(String) ? [value] * 4 : box(value)
        invalid_margin(value) unless sides&.all? { |side| side?(side) }
        return value if sides.none?(String)

        sides.map { |side| side.is_a?(String) ? Units.points(side) : side }
      end

      # The four sides of a margin in points.
      def sides(value)
        return margin(value) if value.is_a?(String)

        sides = Geometry.box(value)
        sides.any?(String) ? margin(value) : sides
      end

      def pair(value)
        return unless value.size == 2
        return value if value.all? { |length| positive?(length) }

        lengths = value.map { |length| side?(length) && length.is_a?(String) ? Units.points(length) : length }
        lengths if lengths.all? { |length| positive?(length) }
      end

      def written(value)
        match = SIZE.match(value) or return
        lengths = [Units.convert(match[1], match[2] || match[4]), Units.convert(match[3], match[4])]
        lengths if lengths.all?(&:positive?)
      end

      def named(value) = (value if SIZES.key?(value.to_s.downcase.to_sym))

      def positive?(length) = length.is_a?(Numeric) && length.real? && length.finite? && length.positive?

      def side?(side)
        return Units::LENGTH.match?(side) if side.is_a?(String)

        side.is_a?(Numeric) && side.real? && side.finite?
      end

      def box(value)
        Geometry.box(value)
      rescue ArgumentError
        nil
      end

      def invalid_margin(value)
        raise ArgumentError, "invalid page margin #{value.inspect} (use #{MARGINS_TAKEN}; #{UNITS_TAKEN})"
      end
    end
  end
end
