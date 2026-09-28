# frozen_string_literal: true

module Stationery
  # Monochrome mode, for a printer that prints black or nothing (a thermal
  # label printer at 203 or 300 dpi, a receipt printer):
  #
  #   monochrome dpi: 203, snap: false, threshold: 0.5, dither: :floyd_steinberg
  #
  # Every colour that is not black or white is reported (Warnings::NotMonochrome)
  # and every line thinner than a dot (Warnings::ThinLine); `snap: true`
  # changes them instead. Lines and axis-aligned rectangles are put on the
  # printer's dot grid and bitmaps are dithered to one bit at `dpi:`. The
  # rules live in Rules and Grid, so an output other than PDF applies the
  # same ones; Painting applies them on a canvas.
  module Monochrome
    DITHERS = %i[floyd_steinberg ordered threshold].freeze
    DEFAULTS = { dpi: 203, snap: false, threshold: 0.5, dither: :floyd_steinberg }.freeze
    ACCEPTED = { dpi: "a number above 0", snap: "true or false", threshold: "a number from 0 to 1",
                 dither: DITHERS.map(&:inspect).join(", ").sub(/, (?=[^,]*\z)/, " or ") }.freeze

    # What a monochrome render is asked for. `dot` is the size of one of the
    # printer's dots in points.
    Settings = Data.define(:dpi, :snap, :threshold, :dither) do
      def dot = 72.0 / dpi
    end

    module_function

    # The settings `options` ask for, over the defaults, checked.
    def settings(**options)
      unknown = options.keys - DEFAULTS.keys
      raise ArgumentError, "unknown monochrome option #{unknown.first.inspect} (use #{names})" if unknown.any?

      options.each do |key, value|
        next if valid?(key, value)

        raise ArgumentError, "monochrome #{key}: is #{ACCEPTED.fetch(key)}, not #{value.inspect}"
      end
      Settings.new(**DEFAULTS, **options)
    end

    # The settings of a render: `given` is what the class declares (the
    # default), false or nil for none, true for the class's or the defaults,
    # or a Hash laid over the class's.
    def for(declared, given)
      case given
      when Settings, nil, false then given || nil
      when true then declared || settings
      when Hash then settings(**declared.to_h, **given)
      else raise ArgumentError, "monochrome: takes true, false or a Hash of options, not #{given.inspect}"
      end
    end

    # How light `color` (a Color) is, from 0 (black) to 1 (white): its luma
    # (ITU-R BT.601, the weights a printer driver greys a colour with),
    # painted at `opacity` on white paper.
    def tone(color, opacity = nil)
      r, g, b = rgb(color)
      luma = ((0.299 * r) + (0.587 * g) + (0.114 * b)).round(6)
      opacity && opacity < 1 ? 1 - (opacity * (1 - luma)) : luma
    end

    # "#RRGGBB" for `color`; CMYK is converted without a profile.
    def hex(color)
      r, g, b = rgb(color).map { |v| (v * 255).round }
      format("#%<r>02X%<g>02X%<b>02X", r:, g:, b:)
    end

    def rgb(color)
      return color.components if color.space == :rgb

      c, m, y, k = color.components
      [c, m, y].map { |v| (1 - v) * (1 - k) }
    end

    def names = DEFAULTS.keys.map(&:inspect).join(", ")

    def valid?(key, value)
      case key
      when :dpi then value.is_a?(Numeric) && value.positive?
      when :snap then [true, false].include?(value)
      when :threshold then value.is_a?(Numeric) && value.between?(0, 1)
      when :dither then DITHERS.include?(value)
      end
    end
  end
end
