# frozen_string_literal: true

module Stationery
  module SVG
    # Traces one SVG shape element onto a canvas path.
    module Shapes
      NAMES = %w[path rect circle ellipse line polyline polygon].freeze

      module_function

      def trace(path, element)
        a = element.attributes
        case element.name
        when "path" then trace_data(path, PathData.parse(a["d"]))
        when "rect" then path.rounded_rect(f(a, "x"), f(a, "y"), f(a, "width"), f(a, "height"), f(a, "rx", f(a, "ry")))
        when "circle" then path.ellipse(f(a, "cx"), f(a, "cy"), f(a, "r"), f(a, "r"))
        when "ellipse" then path.ellipse(f(a, "cx"), f(a, "cy"), f(a, "rx"), f(a, "ry"))
        when "line" then trace_points(path, [[f(a, "x1"), f(a, "y1")], [f(a, "x2"), f(a, "y2")]], close: false)
        else trace_points(path, points(a["points"]), close: element.name == "polygon")
        end
      end

      def trace_data(path, segments)
        segments.each do |kind, *args|
          case kind
          when :move then path.move_to(*args)
          when :line then path.line_to(*args)
          when :curve then path.curve_to(*args)
          else path.close
          end
        end
      end

      def trace_points(path, points, close:)
        return if points.empty?

        path.move_to(*points.first)
        points.drop(1).each { |point| path.line_to(*point) }
        path.close if close
      end

      def points(source)
        source.to_s.scan(PathData::NUMBER).map { |v| v.match?(/[.eE]/) ? v.to_f : v.to_i }.each_slice(2)
              .select { |pair| pair.size == 2 }
      end

      def f(attributes, key, default = 0)
        value = attributes[key]
        return default if value.nil? || value.empty?

        number = value.to_f
        number == number.round ? number.round : number
      end
    end
  end
end
