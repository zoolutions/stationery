# frozen_string_literal: true

module Stationery
  # A rectangle in top-left page coordinates, in points.
  Rect = Data.define(:x, :y, :width, :height) do
    def right = x + width
    def bottom = y + height

    def inset(top, right, bottom, left)
      Rect.new(x + left, y + top, [width - left - right, 0].max, [height - top - bottom, 0].max)
    end
  end

  module Geometry
    SIDES = { top: 0, right: 1, bottom: 2, left: 3 }.freeze

    module_function

    # CSS-style shorthand to [top, right, bottom, left].
    def box(value)
      case value
      when nil then [0, 0, 0, 0]
      when Numeric then [value] * 4
      when Hash then from_hash(value)
      when Array then from_array(value)
      else raise ArgumentError, "not a box: #{value.inspect}"
      end
    end

    def from_array(value)
      case value.size
      when 1 then value * 4
      when 2 then value * 2
      when 3 then [value[0], value[1], value[2], value[1]]
      when 4 then value.dup
      else raise ArgumentError, "a box takes 1 to 4 values, got #{value.size}"
      end
    end

    def from_hash(value)
      sides = [0, 0, 0, 0]
      sides[0] = sides[2] = value[:y] if value.key?(:y)
      sides[1] = sides[3] = value[:x] if value.key?(:x)
      SIDES.each { |name, index| sides[index] = value[name] if value.key?(name) }
      sides
    end

    def align_offset(align, available, used)
      case align
      when :center then (available - used) / 2.0
      when :right then available - used
      else 0
      end
    end
  end
end
