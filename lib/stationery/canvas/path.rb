# frozen_string_literal: true

module Stationery
  class Canvas
    # Collects path segments in top-left coordinates and writes them in PDF
    # space. An optional affine transform (a, b, c, d, e, f), also in top-left
    # space, is applied to every point — how scaled icons are drawn.
    class Path
      KAPPA = 0.5522847498

      def initialize(canvas, transform: nil)
        @canvas = canvas
        @transform = transform
        @ops = []
      end

      def move_to(x, y) = add("#{point(x, y)} m")
      def line_to(x, y) = add("#{point(x, y)} l")
      def curve_to(x1, y1, x2, y2, x, y) = add("#{point(x1, y1)} #{point(x2, y2)} #{point(x, y)} c")
      def close = add("h")

      def rect(x, y, w, h)
        unless @transform
          return add([x, @canvas.page.height - y - h, w, h].map { |v| @canvas.num(v) }.push("re").join(" "))
        end

        move_to(x, y)
        line_to(x + w, y)
        line_to(x + w, y + h)
        line_to(x, y + h)
        close
      end

      def rounded_rect(x, y, w, h, r)
        r = [r, w / 2.0, h / 2.0].min
        return rect(x, y, w, h) if r <= 0

        k = r * KAPPA
        move_to(x + r, y)
        line_to(x + w - r, y)
        curve_to(x + w - r + k, y, x + w, y + r - k, x + w, y + r)
        line_to(x + w, y + h - r)
        curve_to(x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y + h)
        line_to(x + r, y + h)
        curve_to(x + r - k, y + h, x, y + h - r + k, x, y + h - r)
        line_to(x, y + r)
        curve_to(x, y + r - k, x + r - k, y, x + r, y)
        close
      end

      def ellipse(cx, cy, rx, ry)
        kx = rx * KAPPA
        ky = ry * KAPPA
        move_to(cx + rx, cy)
        curve_to(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry)
        curve_to(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy)
        curve_to(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry)
        curve_to(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy)
        close
      end

      def to_s = @ops.join("\n")

      private

      def add(op)
        @ops << op
        self
      end

      def point(x, y)
        x, y = apply(x, y) if @transform
        "#{@canvas.num(x)} #{@canvas.num(@canvas.page.height - y)}"
      end

      def apply(x, y)
        a, b, c, d, e, f = @transform
        [(a * x) + (c * y) + e, (b * x) + (d * y) + f]
      end
    end
  end
end
