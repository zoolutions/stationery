# frozen_string_literal: true

module Stationery
  module SVG
    # A parsed SVG drawn as vector paths on a canvas. Supports the subset icon
    # sets use: path, rect (with rx), circle, ellipse, line, polyline, polygon
    # and g, with fill, stroke, stroke width/caps/joins, fill-rule, opacity,
    # inline styles, <style> stylesheets, transforms, linear/radial gradients
    # and text/tspan. `currentColor` takes the colour you pass.
    class Document
      SHAPES = %w[path rect circle ellipse line polyline polygon].freeze
      QUIET = (SHAPES + %w[svg g title desc metadata style defs linearGradient radialGradient stop text
                           tspan]).freeze

      def self.parse(source)
        root = Parser.parse(source)
        raise Error, "not an svg document" unless root&.name == "svg"

        new(root)
      end

      attr_reader :view_box, :unsupported

      def initialize(root)
        @root = root
        @view_box = read_view_box
        @sheet = Stylesheet.parse(style_text)
        @gradients = Gradient.collect(root, @sheet)
        @unsupported = (element_names(root).uniq - QUIET).sort + approximations
      end

      def aspect = @view_box[2].to_f / @view_box[3]

      # Scales the viewBox into the box (aspect ratio kept, centred). Text is
      # drawn from `book` (bundled fonts when nil), unknown families in `family`.
      def draw(canvas, x:, y:, width:, height:, color: "#000000", book: nil, family: nil)
        vx, vy, vw, vh = @view_box
        scale = [width.to_f / vw, height.to_f / vh].min
        e = x + ((width - (vw * scale)) / 2.0) - (vx * scale)
        f = y + ((height - (vh * scale)) / 2.0) - (vy * scale)
        style = Style.new(Style::DEFAULTS, [scale, 0, 0, scale, e, f], color:, sheet: @sheet).child(@root)
        painter = Painter.new(canvas, @gradients, @view_box.last(2))
        text = Text.new(canvas, painter, book || Fonts::FontBook.new, family || Fonts::Bundled::DEFAULT)
        shapes(@root, style) do |element, own|
          element.name == "text" ? text.draw(element, own) : painter.paint(element, own)
        end
      end

      private

      def read_view_box
        values = @root.attributes["viewBox"]&.split(/[\s,]+/)&.map { |v| number(v) }
        return values if values&.size == 4

        [0, 0, number(@root.attributes.fetch("width", "100")), number(@root.attributes.fetch("height", "100"))]
      end

      def style_text
        styles = []
        Parser.walk(@root) { |element| styles << element if element.name == "style" }
        styles.flat_map(&:children).join(" ")
      end

      def element_names(element)
        element.children.grep(Parser::Element).flat_map { |child| [child.name, *element_names(child)] }
      end

      def number(value)
        float = value.to_s.to_f
        float == float.round ? float.round : float
      end

      # Yields every drawn shape and text with its resolved style, in paint
      # order, skipping undisplayed subtrees and hidden elements.
      def shapes(parent, parent_style, &)
        parent.children.each do |element|
          style = parent_style.child(element)
          next unless style.displayed?

          if element.name == "g" then shapes(element, style, &)
          elsif (SHAPES.include?(element.name) || element.name == "text") && style.visible? then yield element, style
          end
        end
      end

      # Paint references to missing gradients, gradient spreads drawn as pad
      # and stylesheet selectors ignored.
      def approximations
        missing = []
        shapes(@root, Style.new(sheet: @sheet).child(@root)) do |_element, style|
          [style.fill, style.stroke].grep(Style::Reference).each do |reference|
            missing << "url(##{reference.id})" unless @gradients.key?(reference.id)
          end
        end
        spreads = @gradients.values.filter_map do |gradient|
          "#{gradient.kind}Gradient spreadMethod=#{gradient.approximated_spread}" if gradient.approximated_spread
        end
        selectors = @sheet.unsupported.empty? ? [] : ["style selectors: #{@sheet.unsupported.join(", ")}"]
        (missing + spreads).uniq.sort + selectors
      end
    end
  end
end
