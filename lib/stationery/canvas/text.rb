# frozen_string_literal: true

module Stationery
  class Canvas
    # Single-run text drawing: one font, size and colour at a baseline.
    module Text
      BOLD_STROKE = 0.03

      # Draws `string` with its baseline at (x, y) in top-left coordinates and
      # returns its advance width. Standard ligatures form unless `ligatures:`
      # is false or letter spacing is set.
      def text(string, x:, y:, font:, size:, color: "#000000", letter_spacing: 0, rise: 0, opacity: nil,
               synthetic_bold: false, synthetic_oblique: false, underline: false, strikethrough: false,
               kerning: false, ligatures: true, word_spacing: 0)
        return 0 if string.empty?

        color = Color.parse(color)
        run = font.glyph_run(string, kerning:, ligatures: ligatures && letter_spacing.zero?)
        run = run.with_word_spacing(word_spacing, size) unless word_spacing.zero?
        width = run.width(size, letter_spacing:)
        graphics(opacity:) do |ops|
          ops << color.fill
          ops.push(color.stroke, "#{num(size * BOLD_STROKE)} w") if synthetic_bold
          ops << text_object(run, x, y, font, size,
                             letter_spacing:, rise:, bold: synthetic_bold, oblique: synthetic_oblique)
        end
        decorate(x, y, width, font, size, color:, underline:, strikethrough:)
        width
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

      def decorate(x, y, width, font, size, color:, underline:, strikethrough:)
        fill_rect(x, y - font.underline_position(size), width, font.underline_thickness(size), color:) if underline
        return unless strikethrough

        fill_rect(x, y - font.strikeout_position(size), width, font.strikeout_size(size), color:)
      end
    end
  end
end
