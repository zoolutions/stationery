# frozen_string_literal: true

module Stationery
  module ZPL
    # A render to ZPL (Document#to_zpl): the pages chosen, rasterised as a
    # monochrome to_png draws them (see Raster::Render), each written as a
    # label. A label printer prints one bit, so the render is monochrome
    # whether the class declares it or not: with the class's settings when
    # it does (snap:, threshold:, dither:), the defaults of Monochrome when it
    # does not, `monochrome:` options laid over either. `dpi:` is the
    # printer's, by default the monochrome dpi (203 unless the class says
    # otherwise), and `copies:` by default the class's `print copies:`, else 1.
    # `native:` is whether barcodes that do not say are drawn by the printer
    # (see Native).
    class Render
      def initialize(document, dpi:, copies:, pages:, compression:, native:, monochrome:, debug:, strict:, shaper:)
        settings = Monochrome.for(document.class.config[:monochrome], monochrome)
        raise ArgumentError, "to_zpl is always monochrome: a label printer prints one bit a dot" unless settings

        @copies = copies(copies || document.class.config[:print][:copies] || 1)
        @compression = ZPL.check_compression(compression)
        dpi = ZPL.check_dpi(dpi || settings.dpi)
        @native = Native.new(dpi, native)
        @raster = Raster::Render.new(document, dpi:, pages:, monochrome: settings, debug:, strict:, shaper:)
      end

      # The labels, one for each page chosen, in one String; also written to
      # `target` when given, a path or an IO.
      def call(target = nil)
        zpl = @raster.paint(native: @native) do |surface, natives|
          fields = natives.map { |call| @native.field(call) }
          ZPL.label(@raster.bits(surface), width: surface.width, height: surface.height, copies: @copies,
                                           compression: @compression, fields:)
        end.map(&:last).join
        if target.respond_to?(:write)
          target.write(zpl)
        elsif target
          File.binwrite(target.to_s, zpl)
        end
        zpl
      end

      private

      def copies(count)
        return count if count.is_a?(Integer) && count.between?(1, 99_999_999)

        raise ArgumentError, "copies: is an Integer from 1 to 99999999, not #{count.inspect}"
      end
    end
  end
end
