# frozen_string_literal: true

module Stationery
  module SVG
    # A parsed SVG drawn as vector paths on a canvas. Supports the subset icon
    # sets and exports use: path, rect (with rx), circle, ellipse, line,
    # polyline, polygon and g, with fill, stroke, stroke width/caps/joins,
    # fill-rule, opacity, inline styles, <style> stylesheets, transforms,
    # linear/radial gradients and text/tspan; `use` (of shapes, groups, text,
    # symbols and other uses), `symbol` and nested `svg` viewports with
    # `preserveAspectRatio`, and `clipPath`. `currentColor` takes the colour
    # you pass, or the `color` an element sets.
    class Document
      SHAPES = Shapes::NAMES
      QUIET = (SHAPES + %w[svg g title desc metadata style defs linearGradient radialGradient stop text
                           tspan use symbol clipPath]).freeze

      def self.parse(source)
        nesting = nil
        root = Parser.parse(source) { |depth| nesting = depth }
        raise Error, "not an svg document" unless root&.name == "svg"

        new(root, nesting:)
      end

      # `nesting` is how deep the source nested when that was deeper than
      # Parser::MAX_DEPTH (and was flattened there), else nil.
      attr_reader :view_box, :unsupported, :nesting

      def initialize(root, nesting: nil)
        @root = root
        @nesting = nesting
        @view_box = read_view_box
        @sheet = Stylesheet.parse(style_text)
        @gradients = Gradient.collect(root, @sheet)
        @ids = index
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
        walker(painter.method(:clip)).children(@root, style) do |element, own|
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

      # Every element with an id, the first of a repeated id.
      def index
        ids = {}
        Parser.walk(@root) { |element| ids[element.attributes["id"]] ||= element }
        ids.delete(nil)
        ids
      end

      def element_names(element)
        element.children.grep(Parser::Element).flat_map { |child| [child.name, *element_names(child)] }
      end

      def number(value)
        float = value.to_s.to_f
        float == float.round ? float.round : float
      end

      # Yields every drawn shape and text with its resolved style, in paint
      # order; `clipper` paints what is clipped (see Walker).
      def walker(clipper = nil) = Walker.new(@ids, @view_box.last(2), clipper:)

      # Paint references to missing gradients, gradient spreads drawn as pad,
      # uses and clip paths that lead nowhere, and stylesheet selectors ignored.
      def approximations
        walker = self.walker
        missing = []
        walker.children(@root, Style.new(sheet: @sheet).child(@root)) do |_element, style|
          [style.fill, style.stroke].grep(Style::Reference).each do |reference|
            missing << "url(##{reference.id})" unless @gradients.key?(reference.id)
          end
        end
        spreads = @gradients.values.filter_map do |gradient|
          "#{gradient.kind}Gradient spreadMethod=#{gradient.approximated_spread}" if gradient.approximated_spread
        end
        selectors = @sheet.unsupported.empty? ? [] : ["style selectors: #{@sheet.unsupported.join(", ")}"]
        (missing + spreads + walker.issues).uniq.sort + selectors
      end
    end
  end
end
