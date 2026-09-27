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

      # r is one radius for every corner or [top_left, top_right, bottom_right,
      # bottom_left]; radii are scaled down together until each side fits.
      def rounded_rect(x, y, w, h, r)
        tl, tr, br, bl = corner_radii(r, w, h)
        return rect(x, y, w, h) if [tl, tr, br, bl].none?(&:positive?)

        move_to(x + tl, y)
        line_to(x + w - tr, y)
        curve_to(x + w - tr + (tr * KAPPA), y, x + w, y + tr - (tr * KAPPA), x + w, y + tr) if tr.positive?
        line_to(x + w, y + h - br)
        curve_to(x + w, y + h - br + (br * KAPPA), x + w - br + (br * KAPPA), y + h, x + w - br, y + h) if br.positive?
        line_to(x + bl, y + h)
        curve_to(x + bl - (bl * KAPPA), y + h, x, y + h - bl + (bl * KAPPA), x, y + h - bl) if bl.positive?
        line_to(x, y + tl)
        curve_to(x, y + tl - (tl * KAPPA), x + tl - (tl * KAPPA), y, x + tl, y) if tl.positive?
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

      def corner_radii(r, w, h)
        return Array.new(4, [r, w / 2.0, h / 2.0].min) if r.is_a?(Numeric)

        tl, tr, br, bl = r.map { |v| [v, 0].max }
        scale = [[w, tl + tr], [w, bl + br], [h, tl + bl], [h, tr + br]]
                .filter_map { |side, sum| side.fdiv(sum) if sum.positive? }.push(1).min
        [tl, tr, br, bl].map { |v| v * scale }
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
