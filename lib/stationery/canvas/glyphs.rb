# frozen_string_literal: true

module Stationery
  class Canvas
    # A run of glyphs as a PDF text object.
    module Glyphs
      # Draws `run` (a Fonts::GlyphRun or a Fonts::ShapedRun) with its
      # baseline at (x, y). `bold:` strokes the glyphs as well as filling
      # them and `oblique:` shears them, for a family without the face.
      def glyphs(run, x, y, font:, size:, color:, letter_spacing: 0, rise: 0, bold: false, oblique: false,
                 opacity: nil)
        graphics(opacity:) do |ops|
          ops << color.fill
          ops.push(color.stroke, "#{num(size * Text::BOLD_STROKE)} w") if bold
          ops << text_object(run, x, y, font, size, letter_spacing:, rise:, bold:, oblique:)
        end
      end

      private

      def text_object(run, x, y, font, size, letter_spacing:, rise:, bold:, oblique:)
        skew = oblique ? Fonts::Font::OBLIQUE_SKEW : 0
        ops = ["BT", "/#{@page.use(:Font, @resources.font(font))} #{num(size)} Tf"]
        ops << "#{num(letter_spacing)} Tc" unless letter_spacing.zero?
        ops << "#{num(rise)} Ts" unless rise.zero?
        ops << "2 Tr" if bold
        # Td from the identity text matrix is an absolute position (and what
        # text-extraction tools read positions from); Tm only when shearing.
        ops << if skew.zero?
                 "#{num(x)} #{num(@page.height - y)} Td"
               else
                 "1 0 #{num(skew)} 1 #{num(x)} #{num(@page.height - y)} Tm"
               end
        ops << run.to_operator
        ops << "ET"
        ops.join("\n")
      end
    end
  end
end
