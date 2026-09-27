# frozen_string_literal: true

module Stationery
  module SVG
    # SVG `transform` attributes as affine matrices [a, b, c, d, e, f].
    module Transform
      FUNCTION = /(matrix|translate|scale|rotate|skewX|skewY)\s*\(([^)]*)\)/

      module_function

      def parse(source)
        source.scan(FUNCTION).reduce([1, 0, 0, 1, 0, 0]) do |matrix, (name, args)|
          multiply(matrix, function(name, args.split(/[\s,]+/).reject(&:empty?).map(&:to_f)))
        end
      end

      def function(name, args)
        case name
        when "matrix" then args
        when "translate" then [1, 0, 0, 1, args[0], args[1] || 0]
        when "scale" then [args[0], 0, 0, args[1] || args[0], 0, 0]
        when "rotate" then rotate(*args)
        when "skewX" then [1, 0, Math.tan(args[0] * Math::PI / 180), 1, 0, 0]
        else [1, Math.tan(args[0] * Math::PI / 180), 0, 1, 0, 0]
        end
      end

      def rotate(degrees, cx = 0, cy = 0)
        r = degrees * Math::PI / 180
        rotation = [Math.cos(r), Math.sin(r), -Math.sin(r), Math.cos(r), 0, 0]
        multiply(multiply([1, 0, 0, 1, cx, cy], rotation), [1, 0, 0, 1, -cx, -cy])
      end

      def apply(matrix, x, y)
        a, b, c, d, e, f = matrix
        [(a * x) + (c * y) + e, (b * x) + (d * y) + f]
      end

      # The uniform scale a matrix applies to areas, as a length factor.
      def scale(matrix)
        a, b, c, d, = matrix
        Math.sqrt(((a * d) - (b * c)).abs)
      end

      # The transform that applies `inner` first, then `outer`.
      def multiply(outer, inner)
        a, b, c, d, e, f = outer
        ia, ib, ic, id, ie, if_ = inner
        [(a * ia) + (c * ib), (b * ia) + (d * ib), (a * ic) + (c * id), (b * ic) + (d * id),
         (a * ie) + (c * if_) + e, (b * ie) + (d * if_) + f]
      end
    end
  end
end
