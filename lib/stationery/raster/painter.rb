# frozen_string_literal: true

module Stationery
  module Raster
    # Replays what a Canvas recorded for a page onto a Surface at `dpi`:
    # fills and strokes, gradients, bitmaps and glyphs, each under its
    # transform and inside its clip. `antialias: false` draws a pixel in or
    # out by its centre, and every stroke at least a pixel wide (as poppler
    # does in mono), for a one-bit picture. `cache` keeps decoded bitmaps
    # across the pages of a render.
    class Painter
      PLACEHOLDER = { fill: Color.parse("#E5E7EB"), stroke: Color.parse("#9CA3AF") }.freeze

      def initialize(surface, dpi:, antialias:, cache: {})
        @surface = surface
        scale = dpi / 72.0
        @device = [scale, 0, 0, scale, 0, 0]
        @antialias = antialias
        @scanner = Scanner.new(surface.width, surface.height, antialias:)
        @cache = cache
        @masks = {}.compare_by_identity
        @colors = {}
      end

      def paint(list)
        list.each do |call|
          case call
          when Canvas::Draw then draw(call)
          when Canvas::Glyphs then glyphs(call)
          when Canvas::Shade then shade(call)
          when Canvas::Picture then picture(call)
          when Canvas::Native then paint(call.calls)
          end
        end
        @surface
      end

      private

      def draw(call)
        matrix = matrix(call.matrix)
        mask = mask(call.clip)
        return if mask && mask.empty?

        fill(fill_spans(call.path, matrix, call.even_odd), mask, call.fill, call.opacity) if call.fill
        return unless call.stroke

        spans = stroke_spans(call.path, matrix, call.line_width, cap: call.cap, join: call.join, dash: call.dash)
        fill(spans, mask, call.stroke, call.opacity)
      end

      def glyphs(call)
        matrix = matrix(call.matrix)
        mask = mask(call.clip)
        return if mask && mask.empty?

        path = Glyphs.path(call, matrix, antialias: @antialias)
        fill(fill_spans(path, matrix, false), mask, call.color, call.opacity)
        return unless call.bold

        fill(stroke_spans(path, matrix, call.size * Stationery::Canvas::Text::BOLD_STROKE), mask, call.color,
             call.opacity)
      end

      def shade(call)
        return unless call.shading.respond_to?(:stops)

        matrix = matrix(call.matrix)
        spans = clipped(fill_spans(call.path, matrix, call.even_odd), mask(call.clip))
        inverse = Raster.invert(Raster.compose(matrix, call.shading_matrix))
        return unless inverse

        shading = Shading.new(call.shading, inverse, method(:samples))
        @surface.paint(spans, call.opacity || 1.0) { |x, y| shading.color_at(x, y) }
      end

      def picture(call)
        matrix = matrix(call.matrix)
        box = [call.x, call.y, call.width, call.height]
        return placeholder(Stationery::Path.new.rect(*box), call, matrix) if Images.unreadable(call.image)

        matrix, box = Adjust.picture(matrix, box) if Adjust.upright?(matrix)
        spans = clipped(fill_spans(Stationery::Path.new.rect(*box), matrix, false), mask(call.clip))
        inverse = Raster.invert(matrix)
        return unless inverse

        wide, high = box[2, 2].map { |length| length * Raster.scale(matrix) }
        pixels = pixels(call.image, wide, high)
        smooth = @antialias && wide < pixels.width * 4 && high < pixels.height * 4
        picture = Picture.new(pixels, inverse, box, @surface.channels, smooth:)
        @surface.paint(spans, call.opacity || 1.0) { |x, y| picture.color_at(x, y) }
      end

      # A bitmap that cannot be read (a JPEG of a kind not decoded): a grey
      # box, crossed.
      def placeholder(rect, call, matrix)
        mask = mask(call.clip)
        fill(fill_spans(rect, matrix, false), mask, PLACEHOLDER[:fill], call.opacity)
        cross = Stationery::Path.new.rect(call.x, call.y, call.width, call.height)
        cross.move_to(call.x, call.y).line_to(call.x + call.width, call.y + call.height)
        cross.move_to(call.x + call.width, call.y).line_to(call.x, call.y + call.height)
        fill(stroke_spans(cross, matrix, 0), mask, PLACEHOLDER[:stroke], call.opacity)
      end

      def fill_spans(path, matrix, even_odd)
        @scanner.spans(Flattener.polylines(path, matrix, TOLERANCE).map(&:first), even_odd:)
      end

      # The spans of `path` stroked `width` wide in user space: at least a
      # pixel without anti-aliasing, and a hairline (0) a pixel always.
      def stroke_spans(path, matrix, width, cap: nil, join: nil, dash: nil)
        scale = Raster.scale(matrix)
        return Spans.new(0, []) if scale.zero?

        width = 1 / scale if width.zero? || (!@antialias && width * scale < 1)
        tolerance = TOLERANCE / scale
        polylines = Flattener.polylines(path, nil, tolerance)
        polygons = Stroker.new(width:, cap:, join:, dash:, tolerance:).polygons(polylines)
        polygons = polygons.map { |polygon| transform(polygon, matrix) }
        @scanner.spans(Adjust.upright?(matrix) ? Adjust.polygons(polygons) : polygons)
      end

      def fill(spans, mask, color, opacity)
        @surface.fill(clipped(spans, mask), samples(color), opacity || 1.0)
      end

      def clipped(spans, mask) = mask ? spans.intersect(mask) : spans

      # The Spans inside a clip and every clip around it.
      def mask(clip)
        return unless clip

        @masks[clip] ||= begin
          matrix = matrix(clip.matrix)
          polygons = clip.paths.flat_map { |path| Flattener.polylines(path, matrix, TOLERANCE).map(&:first) }
          clipped(@scanner.spans(polygons, even_odd: clip.even_odd), mask(clip.parent))
        end
      end

      def matrix(ctm) = ctm ? Raster.compose(@device, ctm) : @device

      def transform(points, matrix)
        a, b, c, d, e, f = matrix
        out = Array.new(points.size)
        i = 0
        while i < points.size
          x = points[i]
          y = points[i + 1]
          out[i] = (a * x) + (c * y) + e
          out[i + 1] = (b * x) + (d * y) + f
          i += 2
        end
        out
      end

      # The surface's samples for a Color, or for [r, g, b] from 0 to 1.
      def samples(color)
        @colors[color] ||= begin
          rgb = color.is_a?(Color) ? Monochrome.rgb(color) : color
          if @surface.channels == 1
            [(((0.299 * rgb[0]) + (0.587 * rgb[1]) + (0.114 * rgb[2])) * 255).round]
          else
            rgb.map { |value| (value * 255).round }
          end
        end
      end

      # The pixels of a bitmap drawn `wide` × `high` pixels: averaged down
      # first when it has more (a JPEG decoded smaller first when it can).
      def pixels(image, wide, high)
        target = [wide.ceil, 1].max
        @cache[[image, target]] ||= begin
          pixels = if image.is_a?(Images::JPEG)
                     Images.pixels(image, target, [high, 1].max)
                   else
                     @cache[image] ||= image.pixels
                   end
          # A one-bit picture's bitmaps are dithered at its dots already.
          @antialias && pixels.width > target ? Images::Resampled.new(pixels, target).pixels : pixels
        end
      end
    end
  end
end
