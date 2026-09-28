# frozen_string_literal: true

module Stationery
  # Pictures of a render: the pages `to_pdf` paints, painted on pixels
  # instead (Document#to_png), in pure Ruby. The render paints through
  # Raster::Canvases, whose canvases record what each page is asked to draw;
  # once every page is painted (page numbers come last), each page's
  # recording is replayed by a Painter onto a Surface, one page at a time:
  #
  #   Canvas     records draw, shade_path, image and glyphs with the
  #              transform and the clip they were called under
  #   Flattener  a Path to polylines, curves cut to TOLERANCE of a pixel
  #   Stroker    polylines to the polygons of their stroke
  #   Scanner    polygons to Spans, the pixels covered and by how much
  #   Surface    paints Spans in a colour, a gradient or an image
  #
  # A colour picture is anti-aliased; a monochrome one (see Monochrome) is
  # drawn a pixel in or out by its centre, as a one-bit printer prints.
  module Raster
    # How far a flattened curve may stray from the true one, in pixels.
    TOLERANCE = 0.2

    module_function

    # The affine `inner` applied first, then `outer` ([a, b, c, d, e, f] each).
    def compose(outer, inner) = Monochrome::Painting.compose(outer, inner)

    # The matrix taking back what `matrix` does.
    def invert(matrix)
      a, b, c, d, e, f = matrix
      det = (a * d) - (b * c)
      return if det.abs < 1e-12

      [d / det, -b / det, -c / det, a / det, ((c * f) - (d * e)) / det, ((b * e) - (a * f)) / det]
    end

    # How much a length grows under `matrix`.
    def scale(matrix) = Monochrome::Painting.scale(matrix)

    # Pixels across `points` at `dpi`, as pdftoppm counts them (a part
    # counts as a whole).
    def pixels(points, dpi) = ((points * dpi / 72.0) - 1e-6).ceil
  end
end
