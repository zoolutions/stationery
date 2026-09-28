# frozen_string_literal: true

module Stationery
  # A device colour. Accepts "#RRGGBB", "RRGGBB", "#RGB", [r, g, b] in 0-255 or
  # [c, m, y, k] in 0-100. Input values are never mutated.
  class Color
    HEX = /\A#?(\h{3}|\h{6})\z/
    # The colours parsed from Strings that are remembered, by their String:
    # every fill, stroke and run of text names its colour ("#000000"), and
    # parsing it again made eleven objects. Past this many the memo starts
    # over, as the fonts' memos do.
    MEMO = 256

    @parsed = {}
    @lock = Mutex.new

    attr_reader :space, :components, :fill, :stroke

    def self.parse(value)
      case value
      when Color then value
      when String then @parsed[value] || remember(value)
      when Array then from_array(value)
      else invalid(value)
      end
    end

    # A Hash keeps a frozen copy of a String key, so a String changed after
    # it was parsed does not change what the memo holds.
    def self.remember(value)
      color = from_hex(value)
      @lock.synchronize do
        @parsed.clear if @parsed.size >= MEMO
        @parsed[value] ||= color
      end
    end
    private_class_method :remember

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

    # The fill and stroke operators are written here, once: a colour is
    # frozen, and one parsed from a String is drawn with again and again.
    def initialize(space, components)
      @space = space
      @components = components.freeze
      numbers = components.map { |v| PDF::Serializer.number(v.round(4)) }.join(" ")
      op = space == :rgb ? "rg" : "k"
      @fill = "#{numbers} #{op}".freeze
      @stroke = "#{numbers} #{op.upcase}".freeze
      freeze
    end

    def ==(other)
      other.is_a?(Color) && other.space == space && other.components == components
    end
    alias eql? ==

    def hash = [space, components].hash
  end
end
