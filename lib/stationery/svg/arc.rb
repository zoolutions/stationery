# frozen_string_literal: true

module Stationery
  module SVG
    # An SVG elliptical arc as cubic Bezier segments (SVG 1.1 appendix F.6.5:
    # endpoint to centre parameterisation, then at most 90 degrees a segment).
    class Arc
      def initialize(x1, y1, rx, ry, rotation, large, sweep, x2, y2)
        @x1 = x1.to_f
        @y1 = y1.to_f
        @x2 = x2
        @y2 = y2
        @rx = rx.to_f
        @ry = ry.to_f
        @phi = rotation * Math::PI / 180
        @large = large == 1
        @sweep = sweep == 1
      end

      def curves
        centre
        count = [(@delta.abs / (Math::PI / 2)).ceil, 1].max
        step = @delta / count
        curves = Array.new(count) { |i| segment(@theta + (i * step), step) }
        curves.last[4] = @x2
        curves.last[5] = @y2
        curves
      end

      private

      def centre
        cos = Math.cos(@phi)
        sin = Math.sin(@phi)
        dx = (@x1 - @x2) / 2.0
        dy = (@y1 - @y2) / 2.0
        x1p = (cos * dx) + (sin * dy)
        y1p = (-sin * dx) + (cos * dy)
        scale_radii(x1p, y1p)
        cxp, cyp = centre_prime(x1p, y1p)
        @cx = (cos * cxp) - (sin * cyp) + ((@x1 + @x2) / 2.0)
        @cy = (sin * cxp) + (cos * cyp) + ((@y1 + @y2) / 2.0)
        angles(x1p, y1p, cxp, cyp)
      end

      def scale_radii(x1p, y1p)
        lambda = ((x1p**2) / (@rx**2)) + ((y1p**2) / (@ry**2))
        return unless lambda > 1

        @rx *= Math.sqrt(lambda)
        @ry *= Math.sqrt(lambda)
      end

      def centre_prime(x1p, y1p)
        rx2 = @rx**2
        ry2 = @ry**2
        numerator = (rx2 * ry2) - (rx2 * (y1p**2)) - (ry2 * (x1p**2))
        denominator = (rx2 * (y1p**2)) + (ry2 * (x1p**2))
        coefficient = Math.sqrt([numerator, 0].max / denominator) * (@large == @sweep ? -1 : 1)
        [coefficient * @rx * y1p / @ry, -coefficient * @ry * x1p / @rx]
      end

      def angles(x1p, y1p, cxp, cyp)
        ux = (x1p - cxp) / @rx
        uy = (y1p - cyp) / @ry
        vx = (-x1p - cxp) / @rx
        vy = (-y1p - cyp) / @ry
        @theta = Math.atan2(uy, ux)
        @delta = Math.atan2((ux * vy) - (uy * vx), (ux * vx) + (uy * vy))
        @delta -= 2 * Math::PI if !@sweep && @delta.positive?
        @delta += 2 * Math::PI if @sweep && @delta.negative?
      end

      def segment(start, step)
        t = 4.0 / 3 * Math.tan(step / 4)
        a1 = start
        a2 = start + step
        p1 = point(Math.cos(a1) - (t * Math.sin(a1)), Math.sin(a1) + (t * Math.cos(a1)))
        p2 = point(Math.cos(a2) + (t * Math.sin(a2)), Math.sin(a2) - (t * Math.cos(a2)))
        p3 = point(Math.cos(a2), Math.sin(a2))
        [*p1, *p2, *p3]
      end

      def point(ux, uy)
        x = @rx * ux
        y = @ry * uy
        [(Math.cos(@phi) * x) - (Math.sin(@phi) * y) + @cx, (Math.sin(@phi) * x) + (Math.cos(@phi) * y) + @cy]
      end
    end
  end
end
