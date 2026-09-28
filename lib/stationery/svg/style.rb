# frozen_string_literal: true

module Stationery
  module SVG
    Selector = CSS::Selector
    Stylesheet = CSS::Stylesheet

    # Presentation attributes an element inherits from its ancestors, and the
    # transform it draws with. An element's own values cascade: presentation
    # attributes, then stylesheet rules, then its inline `style`. `color` sets
    # what `currentColor` means from the element down.
    class Style
      INHERITED = %w[fill stroke stroke-width stroke-linecap stroke-linejoin fill-rule clip-rule opacity fill-opacity
                     stroke-opacity font-family font-size font-weight font-style text-anchor visibility].freeze
      # Properties of the element alone, not handed to its children.
      LOCAL = %w[display clip-path overflow].freeze
      NAMED = { "black" => "#000000", "white" => "#FFFFFF", "red" => "#FF0000", "green" => "#008000",
                "blue" => "#0000FF", "gray" => "#808080", "grey" => "#808080" }.freeze
      DEFAULTS = { "fill" => "black", "stroke" => "none", "stroke-width" => "1" }.freeze
      IDENTITY = [1, 0, 0, 1, 0, 0].freeze
      URL = /\Aurl\(\s*['"]?#([^'")\s]+)['"]?\s*\)\s*(.*)\z/

      # A paint server reference, `url(#id)`, with its fallback colour (or nil).
      Reference = Data.define(:id, :fallback)

      def self.color(value, current)
        value = value.to_s.strip
        return current if value == "currentColor"

        NAMED.fetch(value.downcase, value)
      end

      def self.declarations(style) = CSS.declarations(style)

      attr_reader :values, :matrix, :color

      def initialize(values = DEFAULTS, matrix = IDENTITY, color: "#000000", sheet: Stylesheet::EMPTY, local: {})
        @values = values
        @matrix = matrix
        @color = color
        @sheet = sheet
        @local = local
      end

      def child(element)
        attributes = element.attributes
        own = attributes.merge(@sheet.declarations(element), Style.declarations(attributes["style"]))
        transform = attributes["transform"]
        matrix = transform ? Transform.multiply(@matrix, Transform.parse(transform)) : @matrix
        color = own["color"] ? Style.color(own["color"], @color) : @color
        Style.new(@values.merge(own.slice(*INHERITED)), matrix, color:, sheet: @sheet, local: own.slice(*LOCAL))
      end

      # This style with `matrix` applied inside its transform: what a `use`
      # does with its x and y, a viewport with its viewBox.
      def transformed(matrix) = at(Transform.multiply(@matrix, matrix))

      # This style drawing under another transform altogether.
      def at(matrix, values = @values) = Style.new(values, matrix, color: @color, sheet: @sheet, local: @local)

      def displayed? = @local["display"] != "none"
      def visible? = !%w[hidden collapse].include?(@values["visibility"])
      # Whether a viewport clips what it draws: all but `visible` and `auto` do.
      def clips? = !%w[visible auto].include?(@local["overflow"])
      # The id of the element's `clip-path: url(#id)`, or nil.
      def clip_path = @local["clip-path"].to_s.strip[URL, 1]

      def fill = paint("fill")
      def stroke = paint("stroke")
      def even_odd? = @values["fill-rule"] == "evenodd"
      def clip_even_odd? = @values["clip-rule"] == "evenodd"
      def cap = @values["stroke-linecap"]&.to_sym
      def join = @values["stroke-linejoin"]&.to_sym

      # Stroke width scales with the drawing, by the transform's area factor.
      def line_width = @values["stroke-width"].to_f * Transform.scale(@matrix)

      def opacity
        %w[opacity fill-opacity stroke-opacity].filter_map { |key| @values[key]&.to_f }.reduce(1.0, :*)
      end

      private

      def paint(key)
        value = @values[key].to_s.strip
        return nil if value.empty? || %w[none transparent].include?(value)
        return Style.color(value, @color) unless (url = value.match(URL))

        fallback = url[2]
        Reference.new(url[1], fallback.empty? || fallback == "none" ? nil : Style.color(fallback, @color))
      end
    end
  end
end
