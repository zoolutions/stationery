# frozen_string_literal: true

module Stationery
  module SVG
    # A linearGradient or radialGradient paint server, with the stops and
    # attributes it inherits through `href`. Coordinates are in gradient
    # space; `matrix` maps them into the painted element's user space.
    class Gradient
      KINDS = %w[linearGradient radialGradient].freeze
      INHERITED = %w[x1 y1 x2 y2 cx cy r fx fy gradientUnits gradientTransform spreadMethod].freeze
      SPREADS = %w[reflect repeat].freeze

      Stop = Data.define(:offset, :color, :opacity)

      # A gradient as a canvas is handed it to paint with (see
      # Canvas::Interface#shade): its `kind` (:linear or :radial), its
      # `coords` in gradient space (see #coords) and its `stops`, the colour
      # `current` standing for `currentColor`.
      Fill = Data.define(:gradient, :coords, :current) do
        def kind = gradient.kind

        # [[offset, [r, g, b]], …] from offset 0 to offset 1, each colour's
        # components from 0 to 1. The ends extend (spread `pad`).
        def stops = Shading.padded(gradient.stops).map { |stop| [stop.offset, gradient.rgb(stop, current)] }
      end

      # Every gradient in the document, by id; stops take `sheet` rules.
      def self.collect(root, sheet = Stylesheet::EMPTY)
        elements = {}
        Parser.walk(root) { |element| elements[element.attributes["id"]] = element if KINDS.include?(element.name) }
        elements.delete(nil)
        elements.transform_values { |element| new(element, elements, sheet) }
      end

      attr_reader :kind, :attributes, :stops

      def initialize(element, elements, sheet = Stylesheet::EMPTY)
        @sheet = sheet
        @kind = element.name == "radialGradient" ? :radial : :linear
        chain = lineage(element, elements)
        @attributes = chain.reverse.map { |link| link.attributes.slice(*INHERITED) }.reduce({}, :merge)
        @stops = read_stops(chain.find { |link| stop_elements(link).any? })
      end

      def bounding_box? = @attributes["gradientUnits"] != "userSpaceOnUse"

      def approximated_spread
        spread = @attributes["spreadMethod"]
        spread if SPREADS.include?(spread)
      end

      # Gradient space to user space, for a shape whose box is [x, y, w, h].
      def matrix(box)
        own = Transform.parse(@attributes["gradientTransform"].to_s)
        return own unless bounding_box?

        x, y, w, h = box
        Transform.multiply([w, 0, 0, h, x, y], own)
      end

      # Axial [x1 y1 x2 y2] or radial [fx fy 0 cx cy r] coordinates; user
      # space percentages resolve against the viewport [width, height].
      def coords(viewport)
        width, height = viewport
        if @kind == :linear
          return [length("x1", 0, width), length("y1", 0, height), length("x2", "100%", width), length("y2", 0, height)]
        end

        cx = length("cx", "50%", width)
        cy = length("cy", "50%", height)
        [length("fx", cx, width), length("fy", cy, height), 0, cx, cy,
         length("r", "50%", Math.sqrt(((width**2) + (height**2)) / 2.0))]
      end

      # The interpolated colour at `offset` as "#RRGGBB".
      def color_at(offset, current)
        before = @stops.reverse.find { |stop| stop.offset <= offset } || @stops.first
        after = @stops.find { |stop| stop.offset >= offset } || @stops.last
        span = after.offset - before.offset
        t = span.positive? ? (offset - before.offset) / span : 0
        from, to = [before, after].map { |stop| rgb(stop, current) }
        "##{from.zip(to).map { |a, b| format("%02X", ((a + ((b - a) * t)) * 255).round) }.join}"
      end

      def rgb(stop, current) = Color.parse(Style.color(stop.color, current)).components

      private

      def lineage(element, elements)
        chain = [element]
        while (id = reference(chain.last)) && (parent = elements[id]) && !chain.include?(parent)
          chain << parent
        end
        chain
      end

      def reference(element)
        (element.attributes["href"] || element.attributes["xlink:href"]).to_s[/\A#(.+)/, 1]
      end

      def stop_elements(element)
        element.children.select { |child| child.is_a?(Parser::Element) && child.name == "stop" }
      end

      def read_stops(element)
        return [] unless element

        floor = 0.0
        stop_elements(element).map do |stop|
          values = stop.attributes.merge(@sheet.declarations(stop), Style.declarations(stop.attributes["style"]))
          floor = [floor, fraction(values.fetch("offset", "0")).clamp(0.0, 1.0)].max
          Stop.new(floor, values.fetch("stop-color", "black"), values.fetch("stop-opacity", "1").to_f)
        end
      end

      def length(key, default, reference)
        value = @attributes.fetch(key, default)
        return value.to_f if value.is_a?(Numeric)
        return value.to_f unless value.strip.end_with?("%")

        bounding_box? ? value.to_f / 100 : value.to_f * reference / 100
      end

      def fraction(value) = value.strip.end_with?("%") ? value.to_f / 100 : value.to_f
    end
  end
end
