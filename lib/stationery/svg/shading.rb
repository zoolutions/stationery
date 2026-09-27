# frozen_string_literal: true

module Stationery
  module SVG
    # A gradient as a PDF shading dictionary: axial (type 2) or radial
    # (type 3) in DeviceRGB, its stops as one exponential function or a
    # stitching of one per pair. The ends always extend (spread `pad`).
    module Shading
      module_function

      def dictionary(gradient, coords, current)
        {
          ShadingType: gradient.kind == :radial ? 3 : 2, ColorSpace: :DeviceRGB, Coords: coords,
          Function: function(padded(gradient.stops), gradient, current), Extend: [true, true]
        }
      end

      def function(stops, gradient, current)
        colors = stops.map { |stop| gradient.rgb(stop, current).map { |v| v.round(4) } }
        segments = colors.each_cons(2).map { |c0, c1| { FunctionType: 2, Domain: [0, 1], C0: c0, C1: c1, N: 1 } }
        return segments.first if segments.one?

        { FunctionType: 3, Domain: [0, 1], Functions: segments, Bounds: stops[1..-2].map(&:offset),
          Encode: [0, 1] * segments.size }
      end

      def padded(stops)
        stops = [stops.first.with(offset: 0.0), *stops] if stops.first.offset.positive?
        stops = [*stops, stops.last.with(offset: 1.0)] if stops.last.offset < 1
        stops
      end
    end
  end
end
