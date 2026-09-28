# frozen_string_literal: true

module Stationery
  module Raster
    # The canvas of a raster render: it records what the page is asked to
    # draw, in `list`, each call with the transform (`matrix`, top-left page
    # space, nil for none) and the Clip it was made under, for a Painter to
    # replay once the page is finished. Links, form fields and tagging draw
    # nothing (Canvas::Interface); page numbers and anchors are recorded on
    # the page as on any canvas.
    class Canvas
      include Stationery::Canvas::Interface

      # The paths a clip joins under a rule, inside its parent's.
      Clip = Data.define(:parent, :paths, :even_odd, :matrix)
      Draw = Data.define(:path, :fill, :stroke, :line_width, :cap, :join, :dash, :even_odd, :opacity, :matrix, :clip)
      Shade = Data.define(:path, :shading, :shading_matrix, :even_odd, :opacity, :matrix, :clip)
      Picture = Data.define(:image, :x, :y, :width, :height, :opacity, :matrix, :clip)
      Glyphs = Data.define(:run, :x, :y, :font, :size, :color, :letter_spacing, :rise, :bold, :oblique, :opacity,
                           :matrix, :clip)
      # A barcode, and the `calls` that draw it on pixels.
      Native = Data.define(:symbol, :x, :y, :module_size, :height, :color, :native, :matrix, :clip, :calls)

      def initialize(page, list, template: false, debug: false, warnings: nil)
        @page = page
        @list = list
        @template = template
        @debug = debug
        @warnings = warnings
        @matrix = @clip = nil
      end

      def save = yield(self)

      def transform(matrix)
        outer = @matrix
        @matrix = outer ? Raster.compose(outer, matrix) : matrix
        yield self
      ensure
        @matrix = outer
      end

      def clip_to(paths, even_odd: false)
        paths = paths.reject(&:empty?)
        return if paths.empty?

        outer = @clip
        @clip = Clip.new(outer, paths, even_odd, @matrix)
        yield self
      ensure
        @clip = outer
      end

      def draw(path, fill: nil, stroke: nil, line_width: 1, cap: nil, join: nil, dash: nil, even_odd: false,
               opacity: nil)
        return unless fill || stroke

        @list << Draw.new(path, fill && Color.parse(fill), stroke && Color.parse(stroke), line_width, cap, join, dash,
                          even_odd, opacity, @matrix, @clip)
      end

      def shade_path(path, shading, matrix:, even_odd: false, opacity: nil)
        @list << Shade.new(path, shading, matrix, even_odd, opacity, @matrix, @clip)
      end

      # A JPEG of a kind that is not decoded (lossless, arithmetic-coded,
      # 12-bit) is drawn as a placeholder and reported.
      def image(image, x:, y:, width:, height:, opacity: nil)
        reason = Images.unreadable(image)
        if reason
          @warnings&.<<(Warnings::SkippedImage.new(source: "#{image.class.name.split("::").last} " \
                                                           "#{image.width}x#{image.height}",
                                                   reason: "#{reason}; drawn as a crossed box"))
        end
        @list << Picture.new(image, x, y, width, height, opacity, @matrix, @clip)
      end

      def glyphs(run, x, y, font:, size:, color:, letter_spacing: 0, rise: 0, bold: false, oblique: false,
                 opacity: nil)
        @list << Glyphs.new(run, x, y, font, size, color, letter_spacing, rise, bold, oblique, opacity, @matrix, @clip)
      end

      # Records the barcode with the calls that draw it, so an output with
      # barcodes of its own can draw it with those instead (see Native).
      def barcode(symbol, x:, y:, module_size:, height: nil, color: "#000000", native: nil)
        outer = @list
        @list = []
        super
        outer << Native.new(symbol, x, y, module_size, height, Color.parse(color), native, @matrix, @clip, @list)
      ensure
        @list = outer
      end
    end

    # The canvas of a monochrome raster render: what it paints goes through
    # the render's Monochrome::Rules first, as on the PDF canvas.
    class MonochromeCanvas < Canvas
      include Monochrome::Painting

      def initialize(page, list, rules, **)
        super(page, list, **)
        @monochrome = rules
        @ctm = nil
        rules.page_number(page)
      end
    end
  end
end
