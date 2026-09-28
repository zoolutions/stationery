# frozen_string_literal: true

module Stationery
  module Raster
    # A run of glyphs as one Stationery::Path of their outlines (see
    # Fonts::Outline), placed as a PDF viewer places them: the baseline
    # `rise` above `y`, the pen moved after each glyph by its advance, its
    # adjustment and the letter spacing (a Fonts::GlyphRun) or by the
    # shaper's advance and the run's extra (a Fonts::ShapedRun, whose glyphs
    # are also offset), and the whole sheared about `y` for a synthetic
    # oblique. Glyphs do not overlap, so the path is filled nonzero.
    #
    # Each glyph's origin is put on the pixel grid as poppler puts it: the
    # baseline on the pixel edge above, and across to a quarter of a pixel
    # (a whole pixel without anti-aliasing, or for a glyph over GRID_LIMIT
    # pixels tall), so a picture and pdftoppm's agree on where text sits.
    class Glyphs
      QUARTERS = 4
      GRID_LIMIT = 100

      # `call` is a Canvas::Glyphs, `matrix` its user space to pixels.
      def self.path(call, matrix, antialias:) = new(call, matrix, antialias).path

      def initialize(call, matrix, antialias)
        @call = call
        skew = call.oblique ? Fonts::Font::OBLIQUE_SKEW : 0
        @shear = skew.zero? ? nil : [1, 0, -skew, 1, skew * call.y, 0]
        @glyph = @shear ? Raster.compose(matrix, @shear) : matrix
        @inverse = Raster.invert(@glyph)
        @scale = call.size / call.font.ttf.units_per_em.to_f
        @steps = antialias && call.size * Raster.scale(matrix) <= GRID_LIMIT ? QUARTERS : 1
      end

      def path
        path = Stationery::Path.new(transform: @shear)
        baseline = @call.y - @call.rise
        @call.run.is_a?(Fonts::ShapedRun) ? shaped(path, baseline) : plain(path, baseline)
        path
      end

      private

      def plain(path, baseline)
        font = @call.font
        run = @call.run
        size = @call.size
        pen = @call.x
        run.gids.each_with_index do |gid, index|
          place(path, font.outline(gid), pen, baseline)
          pen += (font.ttf.advance(gid) * @scale) + (run.adjust[index] * size / 1000.0) + @call.letter_spacing
        end
      end

      def shaped(path, baseline)
        run = @call.run
        pen = @call.x
        run.glyphs.each_with_index do |glyph, index|
          place(path, @call.font.outline(glyph.gid), pen + (glyph.x_offset * @scale),
                baseline - (glyph.y_offset * @scale))
          pen += (glyph.advance * @scale) + run.extra[index]
        end
      end

      def place(path, outline, x, y)
        return if outline.empty?

        x, y = snapped(x, y) if @inverse
        outline.append_to(path, x, y, @scale)
      end

      # The user-space point whose pixel is (x, y)'s put on the grid.
      def snapped(x, y)
        a, b, c, d, e, f = @glyph
        px = (((a * x) + (c * y) + e) * @steps).floor.fdiv(@steps)
        py = ((b * x) + (d * y) + f).floor
        a, b, c, d, e, f = @inverse
        [(a * px) + (c * py) + e, (b * px) + (d * py) + f]
      end
    end
  end
end
