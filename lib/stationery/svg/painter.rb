# frozen_string_literal: true

module Stationery
  module SVG
    # Paints one shape element. Solid fills and strokes are one path; a
    # gradient fill is a shading clipped to the shape, drawn under the
    # stroke. A gradient stroke is drawn in the gradient's middle colour.
    class Painter
      def initialize(canvas, gradients, viewport)
        @canvas = canvas
        @gradients = gradients
        @viewport = viewport
      end

      def paint(element, style)
        fill = resolve(style.fill)
        stroke = resolve(style.stroke)
        stroke = stroke.color_at(0.5, style.color) if stroke.is_a?(Gradient)
        if fill.is_a?(Gradient)
          shade(element, style, fill)
          fill = nil
        end
        return if fill.nil? && stroke.nil?

        @canvas.path(fill:, stroke:, line_width: style.line_width, cap: style.cap || :butt, join: style.join || :miter,
                     even_odd: style.even_odd?, opacity: translucent(style.opacity),
                     transform: style.matrix) { |path| Shapes.trace(path, element) }
      end

      private

      def resolve(paint)
        return paint unless paint.is_a?(Style::Reference)

        gradient = @gradients[paint.id]
        return paint.fallback unless gradient
        return nil if gradient.stops.empty?

        gradient
      end

      # Stops with differing opacities are approximated by the first one's.
      def shade(element, style, gradient)
        opacity = translucent(style.opacity * gradient.stops.first.opacity)
        return solid(element, style, gradient, opacity) if gradient.stops.one?

        box = Bounds.new.tap { |bounds| Shapes.trace(bounds, element) }.box
        return if gradient.bounding_box? && box.nil?

        shading = Shading.dictionary(gradient, gradient.coords(@viewport), style.color)
        matrix = Transform.multiply(style.matrix, gradient.matrix(box))
        @canvas.shade(shading, matrix:, transform: style.matrix, even_odd: style.even_odd?, opacity:) do |path|
          Shapes.trace(path, element)
        end
      end

      def solid(element, style, gradient, opacity)
        @canvas.path(fill: gradient.color_at(0, style.color), even_odd: style.even_odd?, opacity:,
                     transform: style.matrix) { |path| Shapes.trace(path, element) }
      end

      def translucent(opacity) = opacity < 1 ? opacity : nil
    end
  end
end
