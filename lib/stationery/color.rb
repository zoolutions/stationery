# frozen_string_literal: true

module Stationery
  # A device colour. Accepts "#RRGGBB", "RRGGBB", "#RGB", [r, g, b] in 0-255 or
  # [c, m, y, k] in 0-100. Input values are never mutated.
  class Color
    HEX = /\A#?(\h{3}|\h{6})\z/

    attr_reader :space, :components

    def self.parse(value)
      case value
      when Color then value
      when String then from_hex(value)
      when Array then from_array(value)
      else invalid(value)
      end
    end

    def self.from_hex(value)
      hex = value[HEX, 1] || invalid(value)
      hex = hex.chars.map { |c| c * 2 }.join if hex.size == 3
      new(:rgb, hex.scan(/../).map { |pair| pair.to_i(16) / 255.0 })
    end

    def self.from_array(value)
      case value.size
      when 3 then new(:rgb, value.map { |v| v.to_f / 255 })
      when 4 then new(:cmyk, value.map { |v| v.to_f / 100 })
      else invalid(value)
      end
    end

    def self.invalid(value)
      raise ArgumentError, "not a colour: #{value.inspect} (use \"#RRGGBB\", [r, g, b] or [c, m, y, k])"
    end

    def initialize(space, components)
      @space = space
      @components = components.freeze
      freeze
    end

    def fill = operator(false)
    def stroke = operator(true)

    def ==(other)
      other.is_a?(Color) && other.space == space && other.components == components
    end
    alias eql? ==

    def hash = [space, components].hash

    private

    def operator(stroke)
      numbers = components.map { |v| PDF::Serializer.number(v.round(4)) }.join(" ")
      op = space == :rgb ? "rg" : "k"
      "#{numbers} #{stroke ? op.upcase : op}"
    end
  end
end
