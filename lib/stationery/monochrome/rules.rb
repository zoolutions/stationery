# frozen_string_literal: true

module Stationery
  module Monochrome
    # What a monochrome render does with what it is asked to paint, and what
    # it reports: one per render, shared by the canvases of its pages. It
    # decides on colours, widths and bitmaps; a canvas (see Painting) paints
    # what it answers.
    #
    # A colour is black, white, or neither, and so is an opacity below 1.
    # Without `snap:` neither is reported, once per colour, kind and page,
    # and painted as it is. With `snap:`, text, rules and strokes that are not
    # white are painted black, and a fill or a gradient is painted black
    # when its tone (Monochrome.tone, its opacity laid on white) is darker
    # than `threshold:` and not at all when it is lighter; an opacity is
    # taken away.
    class Rules
      BLACK = Color.parse("#000000")
      WHITE = Color.parse("#FFFFFF")
      # Kinds drawn as lines, which snap: blackens whatever their colour.
      LINES = %i[text rule border].freeze
      EPSILON = 1e-6

      attr_reader :settings, :grid

      def initialize(settings, warnings)
        @settings = settings
        @grid = Grid.new(settings.dpi)
        @warnings = warnings
        @pages = {}.compare_by_identity
        @seen = {}
        @bitmaps = {}
      end

      def snap? = @settings.snap

      # The number of `page` in the render: pages are counted as their
      # bodies are first painted.
      def page_number(page) = @pages[page] ||= @pages.size + 1

      # [color, opacity] to paint something of `kind` in, nil for nothing
      # (a light fill under snap:).
      def paint(color, kind, page, opacity: nil)
        color = Color.parse(color)
        return [color, opacity] if monochrome?(color, opacity)

        unless snap?
          report(color, kind, page, opacity)
          return [color, opacity]
        end
        return [white?(color) ? WHITE : BLACK, nil] if LINES.include?(kind)

        Monochrome.tone(color, opacity) < @settings.threshold ? [BLACK, nil] : nil
      end

      # A gradient's stops as [offset, [r, g, b]] (components 0 to 1): the
      # colour a snapped gradient is filled with, black or nil for nothing,
      # by the tone of its stops on average. Reported, unsnapped, as
      # :gradient with each stop that is not black or white.
      def gradient(stops, page, opacity: nil)
        colors = stops.map { |_, rgb| Color.new(:rgb, rgb) }
        unless snap?
          colors.each { |color| report(color, :gradient, page, opacity) unless monochrome?(color, opacity) }
          return
        end

        tone = colors.sum { |color| Monochrome.tone(color, opacity) } / colors.size
        tone < @settings.threshold ? BLACK : nil
      end

      # A line `width` points wide (`scale` times that on the page) thinner
      # than a dot: its width to paint with under snap: (a dot), else nil
      # once it is reported with its width on the page.
      def thin(width, kind, page, scale: 1)
        return if width * scale >= @grid.dot
        return @grid.dot / scale if snap?

        width = (width * scale).round(3)
        key = [:thin, kind, width, page_number(page)]
        return if @seen.key?(key)

        @seen[key] = true
        @warnings << Warnings::ThinLine.new(width:, kind:, page: key.last, dpi: @settings.dpi)
        nil
      end

      # `image` as it is printed: dithered at the dots it covers, `width` ×
      # `height` points, when its pixels can be read. A JPEG of a kind that is
      # not decoded is reported and kept.
      def bitmap(image, width, height, page)
        return report_image(image, page) if Images.unreadable(image)

        dots = [@grid.dots(width), @grid.dots(height)]
        @bitmaps[[image, *dots]] ||= Bitmap.new(Images.pixels(image, *dots.map { [it, 1].max }), *dots,
                                                @settings.dither)
      end

      # The opacity to paint a bitmap at: none under snap:, else the one it
      # has, reported when it is below 1.
      def translucent(opacity, page)
        return opacity unless opacity && opacity < 1
        return if snap?

        name = "image at opacity #{opacity.round(3)}"
        key = [name, :image, page_number(page)]
        @warnings << Warnings::NotMonochrome.new(color: name, kind: :image, page: key.last) unless @seen.key?(key)
        @seen[key] = true
        opacity
      end

      private

      def monochrome?(color, opacity)
        return false if opacity && opacity < 1

        tone = Monochrome.tone(color)
        tone < EPSILON || tone > 1 - EPSILON
      end

      def white?(color) = Monochrome.tone(color) > 1 - EPSILON

      def report(color, kind, page, opacity)
        name = Monochrome.hex(color)
        name = "#{name} at opacity #{opacity.round(3)}" if opacity && opacity < 1
        key = [name, kind, page_number(page)]
        return if @seen.key?(key)

        @seen[key] = true
        @warnings << Warnings::NotMonochrome.new(color: name, kind:, page: key.last)
      end

      def report_image(image, page)
        name = "#{image.class.name.split("::").last} #{image.width}x#{image.height}"
        key = [name, :image, page_number(page)]
        @warnings << Warnings::NotMonochrome.new(color: name, kind: :image, page: key.last) unless @seen.key?(key)
        @seen[key] = true
        image
      end
    end
  end
end
