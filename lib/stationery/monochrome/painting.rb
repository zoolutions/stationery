# frozen_string_literal: true

module Stationery
  module Monochrome
    # The primitives of Canvas::Interface under a render's Rules: included
    # into a canvas class that implements them, over which it paints what the
    # rules answer. The including canvas sets `@monochrome` (the Rules) and
    # `@ctm` (nil). Whatever a node, an SVG or a `canvas { }` block draws
    # comes down to these, so they see every colour and every line.
    #
    # The dot grid is kept outside any `transform`: a rectangle filled on
    # its own and a path of horizontal and vertical lines are put on it;
    # anything else, and anything transformed, keeps its geometry and has
    # only its line width checked (scaled by the transform).
    module Painting
      # A filled axis-aligned rectangle this thin or thinner is a rule (a
      # `rule`, an underline, a strikethrough), anything else a background.
      RULE = 3

      def transform(matrix)
        outer = @ctm
        @ctm = outer ? Painting.compose(outer, matrix) : matrix
        super
      ensure
        @ctm = outer
      end

      def draw(path, fill: nil, stroke: nil, line_width: 1, cap: nil, join: nil, dash: nil, even_odd: false,
               opacity: nil)
        return super unless fill || stroke

        segments = path.each_segment.to_a
        box = @monochrome.grid.rectangle(segments)
        kind = box && box[2..].min <= RULE ? :rule : :background
        fill &&= @monochrome.paint(fill, kind, @page, opacity:)&.first
        stroke &&= @monochrome.paint(stroke, :border, @page, opacity:)&.first
        return unless fill || stroke

        opacity = nil if @monochrome.snap?
        path, line_width = stroke ? stroked(path, segments, line_width) : filled(path, box, kind)
        super
      end

      def glyphs(run, x, y, font:, size:, color:, letter_spacing: 0, rise: 0, bold: false, oblique: false,
                 opacity: nil)
        color, opacity = @monochrome.paint(color, :text, @page, opacity:)
        super
      end

      # A field's value is text: its colour is reported, or snapped in /DA
      # and the appearance alike. Its frame is drawn as it is.
      def widget(field, x, y, w, h, tag: nil)
        if field.variable_text?
          color, = @monochrome.paint(field.color, :text, @page)
          field = field.with(color:) unless color.equal?(field.color)
        end
        super
      end

      # A gradient is reported by its stops; snapped, it is a black fill or nothing.
      def shade_path(path, shading, matrix:, even_odd: false, opacity: nil)
        return super unless shading.respond_to?(:stops)

        fill = @monochrome.gradient(shading.stops, @page, opacity:)
        return super unless @monochrome.snap?

        draw(path, fill:, even_odd:) if fill
      end

      # A bitmap is dithered to the dots it covers; a translucent one is
      # reported, or painted opaque with snap:.
      def image(image, x:, y:, width:, height:, opacity: nil)
        scale = Painting.scale(@ctm)
        image = @monochrome.bitmap(image, width * scale, height * scale, @page)
        opacity = @monochrome.translucent(opacity, @page)
        super
      end

      # A barcode outside any transform is put on the dot grid: its corner
      # on a dot and its module a whole number of dots, one at least, so
      # every bar of a width prints as wide.
      def barcode(symbol, x:, y:, module_size:, height: nil, color: "#000000", native: nil)
        unless @ctm
          grid = @monochrome.grid
          x = grid.edge(x)
          y = grid.edge(y)
          module_size = [grid.dots(module_size), 1].max * grid.dot
          height &&= [grid.dots(height), 1].max * grid.dot
        end
        super
      end

      # The affine `inner` applied first, then `outer` ([a, b, c, d, e, f] each).
      def self.compose(outer, inner)
        a, b, c, d, e, f = outer
        p, q, r, s, t, u = inner
        [(a * p) + (c * q), (b * p) + (d * q), (a * r) + (c * s), (b * r) + (d * s),
         (a * t) + (c * u) + e, (b * t) + (d * u) + f]
      end

      # How much a length grows under `matrix`, 1 without one.
      def self.scale(matrix)
        return 1 unless matrix

        a, b, c, d, = matrix
        Math.sqrt(((a * d) - (b * c)).abs)
      end

      private

      # [path, line width] of a stroke: widened to a dot with snap: (else
      # left and reported when thinner), and on the grid when it can be.
      def stroked(path, segments, width)
        scale = Painting.scale(@ctm)
        if width * scale < @monochrome.grid.dot
          widened = @monochrome.thin(width, :border, @page, scale:)
          return [path, width] unless widened

          width = widened
        end
        return [path, width] if @ctm

        count = [@monochrome.grid.dots(width), 1].max
        snapped = @monochrome.grid.stroke(segments, count)
        snapped ? [trace(snapped), count * @monochrome.grid.dot] : [path, width]
      end

      # [path, nil] of a fill: a rectangle on the grid, one thinner than a
      # dot widened with snap: (else left and reported).
      def filled(path, box, kind)
        return [path, 1] unless box && !@ctm

        short = box[2..].min
        return [path, 1] if short < @monochrome.grid.dot && !@monochrome.thin(short, kind, @page)

        [outline { |rect| rect.rect(*@monochrome.grid.rect(*box)) }, 1]
      end

      def trace(segments)
        outline do |path|
          segments.each do |segment|
            next path.close if segment == :close

            segment[0] == :move ? path.move_to(segment[1], segment[2]) : path.line_to(segment[1], segment[2])
          end
        end
      end
    end
  end
end
