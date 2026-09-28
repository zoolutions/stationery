# frozen_string_literal: true

module Stationery
  module ZPL
    # Which barcodes a label printer draws itself, and the fields that tell
    # it to (`^FOx,y` then ^BC, ^BE or ^BQ): the printer puts the bars on its
    # own dot grid, which scanners read more reliably than a picture of them.
    #
    # A barcode (Raster::Canvas::Native) is drawn natively when its own
    # `native:` says so, or the render's `default` when it says nothing, and
    # when the printer can draw it as it is: upright and unclipped, dark, a
    # module of 1 to 10 dots, and data ^BQ takes (a QR code of UTF-8 text is
    # not). Anything else stays part of the picture.
    class Native
      DOTS = 1..10

      def initialize(dpi, default)
        @scale = dpi / 72.0
        @default = default
      end

      # Whether the printer draws `call`.
      def call(call)
        wanted = call.native.nil? ? @default : call.native
        return false unless wanted && call.symbol.native? && call.clip.nil? && upright?(call.matrix)

        Monochrome.tone(call.color) < 0.5 && DOTS.cover?(dots(call.module_size)) && origin(call)[1] >= 0
      end

      # The field for `call`, where its first module is.
      def field(call)
        x, y = origin(call)
        height = call.height && dots(call.height)
        "^FO#{x},#{y}#{call.symbol.zpl(module_dots: dots(call.module_size), height_dots: height)}"
      end

      private

      # The ^FO that puts the symbol's first module where it is drawn.
      def origin(call)
        e, f = call.matrix ? call.matrix.values_at(4, 5) : [0, 0]
        [dots(call.x + e), dots(call.y + f) - call.symbol.zpl_top]
      end

      def dots(points) = (points * @scale).round
      def upright?(matrix) = matrix.nil? || matrix.first(4) == [1, 0, 0, 1]
    end
  end
end
