# frozen_string_literal: true

module Stationery
  module SVG
    # A parsed SVG drawn as vector paths on a canvas. Supports the subset icon
    # sets use: path, rect (with rx), circle, ellipse, line, polyline, polygon
    # and g, with fill, stroke, stroke width/caps/joins, fill-rule, opacity,
    # inline styles and transforms. `currentColor` takes the colour you pass.
    class Document
      SHAPES = %w[path rect circle ellipse line polyline polygon].freeze

      def self.parse(source)
        root = Parser.parse(source)
        raise Error, "not an svg document" unless root&.name == "svg"

        new(root)
      end

      attr_reader :view_box

      def initialize(root)
        @root = root
        @view_box = read_view_box
      end

      def aspect = @view_box[2].to_f / @view_box[3]

      # Scales the viewBox into the box (aspect ratio kept, centred).
      def draw(canvas, x:, y:, width:, height:, color: "#000000")
        vx, vy, vw, vh = @view_box
        scale = [width.to_f / vw, height.to_f / vh].min
        e = x + ((width - (vw * scale)) / 2.0) - (vx * scale)
        f = y + ((height - (vh * scale)) / 2.0) - (vy * scale)
        style = Style.new(Style::DEFAULTS, [scale, 0, 0, scale, e, f], color:).child(@root.attributes)
        @root.children.each { |element| draw_element(canvas, element, style) }
      end

      private

      def read_view_box
        values = @root.attributes["viewBox"]&.split(/[\s,]+/)&.map { |v| number(v) }
        return values if values&.size == 4

        [0, 0, number(@root.attributes.fetch("width", "100")), number(@root.attributes.fetch("height", "100"))]
      end

      def number(value)
        float = value.to_s.to_f
        float == float.round ? float.round : float
      end

      def draw_element(canvas, element, parent)
        style = parent.child(element.attributes)
        return element.children.each { |child| draw_element(canvas, child, style) } if element.name == "g"
        return unless SHAPES.include?(element.name)

        fill = style.fill
        stroke = style.stroke
        return if fill.nil? && stroke.nil?

        canvas.path(fill:, stroke:, line_width: style.line_width, cap: style.cap || :butt, join: style.join || :miter,
                    even_odd: style.even_odd?, opacity: style.opacity < 1 ? style.opacity : nil,
                    transform: style.matrix) { |path| Shapes.trace(path, element) }
      end
    end
  end
end
