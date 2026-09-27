# frozen_string_literal: true

module Stationery
  module SVG
    # Presentation attributes an element inherits from its ancestors, and the
    # transform it draws with. An element's own values cascade: presentation
    # attributes, then stylesheet rules, then its inline `style`.
    class Style
      INHERITED = %w[fill stroke stroke-width stroke-linecap stroke-linejoin fill-rule opacity fill-opacity
                     stroke-opacity font-family font-size font-weight font-style text-anchor visibility].freeze
      NAMED = { "black" => "#000000", "white" => "#FFFFFF", "red" => "#FF0000", "green" => "#008000",
                "blue" => "#0000FF", "gray" => "#808080", "grey" => "#808080" }.freeze
      DEFAULTS = { "fill" => "black", "stroke" => "none", "stroke-width" => "1" }.freeze
      URL = /\Aurl\(\s*['"]?#([^'")\s]+)['"]?\s*\)\s*(.*)\z/

      # A paint server reference, `url(#id)`, with its fallback colour (or nil).
      Reference = Data.define(:id, :fallback)

      def self.color(value, current)
        value = value.to_s.strip
        return current if value == "currentColor"

        NAMED.fetch(value.downcase, value)
      end

      def self.declarations(style)
        style.to_s.split(";").filter_map do |declaration|
          key, value = declaration.split(":", 2).map(&:strip)
          [key, value] if key && value
        end.to_h
      end

      attr_reader :values, :matrix, :color

      def initialize(values = DEFAULTS, matrix = [1, 0, 0, 1, 0, 0], color: "#000000", sheet: Stylesheet::EMPTY,
                     display: nil)
        @values = values
        @matrix = matrix
        @color = color
        @sheet = sheet
        @display = display
      end

      def child(element)
        attributes = element.attributes
        own = attributes.merge(@sheet.declarations(element), Style.declarations(attributes["style"]))
        values = @values.merge(own.slice(*INHERITED))
        matrix = if attributes["transform"]
                   Transform.multiply(@matrix,
                                      Transform.parse(attributes["transform"]))
                 else
                   @matrix
                 end
        Style.new(values, matrix, color: @color, sheet: @sheet, display: own["display"])
      end

      def displayed? = @display != "none"
      def visible? = !%w[hidden collapse].include?(@values["visibility"])

      def fill = paint("fill")
      def stroke = paint("stroke")
      def even_odd? = @values["fill-rule"] == "evenodd"
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
