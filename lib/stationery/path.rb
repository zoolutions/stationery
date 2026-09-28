# frozen_string_literal: true

module Stationery
  # The segments of a path in top-left coordinates (points, y grows
  # downwards): what a canvas is handed to fill, stroke or clip to. An
  # optional affine transform (a, b, c, d, e, f), also in top-left space, is
  # applied to every point as it is added — how scaled icons are drawn — so
  # the segments read back are in page space.
  #
  # Segments are kept flat, a kind followed by its numbers, so a path costs
  # no object per segment. #each_segment reads them back as moves, lines,
  # cubic curves and closes.
  class Path
    KAPPA = 0.5522847498
    WIDTHS = { move: 3, line: 3, curve: 7, rect: 5, close: 1 }.freeze
    private_constant :WIDTHS

    def initialize(transform: nil)
      @transform = transform
      @segments = []
    end

    def empty? = @segments.empty?

    def move_to(x, y) = point(:move, x, y)
    def line_to(x, y) = point(:line, x, y)

    def curve_to(x1, y1, x2, y2, x, y)
      if @transform
        x1, y1 = apply(x1, y1)
        x2, y2 = apply(x2, y2)
        x, y = apply(x, y)
      end
      @segments.push(:curve, x1, y1, x2, y2, x, y)
      self
    end

    def close
      @segments << :close
      self
    end

    def rect(x, y, w, h)
      unless @transform
        @segments.push(:rect, x, y, w, h)
        return self
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

    # Yields every segment in order: `:move, x, y`, `:line, x, y`,
    # `:curve, x1, y1, x2, y2, x, y` (a cubic Bézier by its two control
    # points and its end) and `:close`. A rectangle is a move, three lines
    # and a close.
    def each_segment(&)
      return enum_for(:each_segment) unless block_given?

      index = 0
      index = segment(index, &) while index < @segments.size
      self
    end

    private

    def point(kind, x, y)
      x, y = apply(x, y) if @transform
      @segments.push(kind, x, y)
      self
    end

    def segment(index, &)
      s = @segments
      case s[index]
      when :close then yield :close
      when :curve then yield :curve, s[index + 1], s[index + 2], s[index + 3], s[index + 4], s[index + 5], s[index + 6]
      when :rect then corners(s[index + 1], s[index + 2], s[index + 3], s[index + 4], &)
      else yield s[index], s[index + 1], s[index + 2]
      end
      index + WIDTHS.fetch(s[index])
    end

    def corners(x, y, w, h)
      yield :move, x, y
      yield :line, x + w, y
      yield :line, x + w, y + h
      yield :line, x, y + h
      yield :close
    end

    def corner_radii(r, w, h)
      return Array.new(4, [r, w / 2.0, h / 2.0].min) if r.is_a?(Numeric)

      tl, tr, br, bl = r.map { |v| [v, 0].max }
      scale = [[w, tl + tr], [w, bl + br], [h, tl + bl], [h, tr + br]]
              .filter_map { |side, sum| side.fdiv(sum) if sum.positive? }.push(1).min
      [tl, tr, br, bl].map { |v| v * scale }
    end

    def apply(x, y)
      a, b, c, d, e, f = @transform
      [(a * x) + (c * y) + e, (b * x) + (d * y) + f]
    end
  end
end
