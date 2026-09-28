# frozen_string_literal: true

module Stationery
  module Raster
    # A render to pictures (Document#to_png): the document painted on
    # Raster::Canvases, then each page chosen replayed onto a Surface and
    # written as a PNG, one page at a time, its recording let go once it is.
    #
    # A monochrome render (see Monochrome) is drawn at the settings' dpi,
    # which a `dpi:` given here replaces, without anti-aliasing, and written
    # one bit to a pixel: black and white as they are, and a page with grey
    # on it (a colour or an opacity monochrome reported and kept) dithered
    # the way the settings dither bitmaps.
    class Render
      DPI = 96
      # What only a PDF has: refused when asked for, left alone when the
      # class declares it.
      PDF_ONLY = %i[sign encrypt conformance attachments print tagged page_labels xmp factur_x incremental
                    missing_glyphs].freeze
      GREY = "\x01-\xFE".b
      DARK = "\x00-\x7F".b
      LIGHT = "\x80-\xFF".b

      def self.refuse(options, output = "to_png")
        key = options.keys.first
        return unless key
        raise ArgumentError, "unknown keyword: #{key.inspect}" unless PDF_ONLY.include?(key)

        raise ArgumentError, "#{output} does not take #{key}: (it is what a PDF has, not a picture)"
      end

      def initialize(document, dpi:, pages:, monochrome:, debug:, strict:, shaper:)
        raise ArgumentError, "dpi: is a number above 0, not #{dpi.inspect}" unless dpi.nil? || dpi_value?(dpi)

        @document = document
        @settings = Monochrome.for(document.class.config[:monochrome], monochrome)
        @settings = @settings.with(dpi:) if @settings && dpi
        @dpi = dpi || @settings&.dpi || DPI
        @pages = pages
        @debug = debug
        @strict = strict
        @shaper = shaper
        @cache = {}
      end

      # The PNGs of the pages chosen, also written to `target` when given:
      # one page to the path itself, several to "name-N.png", N the number
      # of the page in the document.
      def call(target = nil)
        pictures = paint { |surface| encode(surface) }
        pictures.each { |number, png| write(png, target, pictures.size == 1 ? nil : number) } if target
        pictures.map(&:last)
      end

      # Paints the document, then each page chosen onto a Surface, one at a
      # time, and answers [number, what the block makes of it] for each.
      def paint
        warnings = Warnings.new
        rules = Monochrome::Rules.new(@settings, warnings) if @settings
        canvases = Canvases.new(debug: @debug, warnings:, monochrome: rules)
        pages = @document.paint_on(canvases, warnings:, shaper: @shaper)
        raise WarningsError, warnings if @strict && warnings.any?

        chosen(pages.size).map do |number|
          page = pages[number - 1]
          [number, yield(surface(page, canvases.release(page)))]
        end
      end

      # The pixels of a monochrome `surface` one bit to a pixel, 1 for white:
      # cut at half where the page is only black and white, dithered where it
      # has grey.
      def bits(surface)
        grey = surface.data
        width = surface.width
        return Monochrome::Dither.call(grey, width, surface.height, @settings.dither) if grey.count(GREY).positive?

        cut = grey.tr(DARK, "0").tr(LIGHT, "1")
        Array.new(surface.height) { |y| [cut.byteslice(y * width, width)].pack("B*") }.join
      end

      private

      def dpi_value?(dpi) = dpi.is_a?(Numeric) && dpi.positive?

      def chosen(count)
        numbers = case @pages
                  when nil then (1..count).to_a
                  when Integer then [@pages]
                  else @pages.to_a
                  end
        missing = numbers.find { |number| !number.is_a?(Integer) || !number.between?(1, count) }
        raise ArgumentError, "no page #{missing.inspect} in a document of #{count}" if missing

        numbers
      end

      def surface(page, list)
        surface = Surface.new(Raster.pixels(page.width, @dpi), Raster.pixels(page.height, @dpi), @settings ? 1 : 3)
        Painter.new(surface, dpi: @dpi, antialias: @settings.nil?, cache: @cache).paint(list)
        surface
      end

      def encode(surface)
        width = surface.width
        height = surface.height
        return PNG.encode(surface.data, width:, height:, channels: 3) unless @settings

        PNG.encode(bits(surface), width:, height:, channels: 1, depth: 1)
      end

      def write(png, target, number)
        path = target.to_s
        path = "#{path.delete_suffix(File.extname(path))}-#{number}#{File.extname(path)}" if number
        File.binwrite(path, png)
      end
    end
  end
end
