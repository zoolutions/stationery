# frozen_string_literal: true

module Stationery
  class Canvas
    # Single-run text drawing: one font, size and colour at a baseline. The
    # run of glyphs is found here and handed to the canvas's #glyphs.
    module Text
      BOLD_STROKE = 0.03

      # Draws `string` with its baseline at (x, y) in top-left coordinates and
      # returns its advance width. Standard ligatures form unless `ligatures:`
      # is false or letter spacing is set; `features:` are further OpenType
      # feature tags (Strings) to apply. A font with a shaper draws the glyphs
      # the shaper placed (see Shaper).
      def text(string, x:, y:, font:, size:, color: "#000000", letter_spacing: 0, rise: 0, opacity: nil,
               synthetic_bold: false, synthetic_oblique: false, underline: false, strikethrough: false,
               kerning: false, ligatures: true, features: Fonts::Font::NO_FEATURES, word_spacing: 0)
        return 0 if string.empty?

        color = Color.parse(color)
        run = font.shaped(string, size, letter_spacing:, kerning:, ligatures:, features:)&.with(rise:)
        return 0 if run&.glyphs&.empty?

        # A shaped run carries its letter spacing between its clusters.
        letter_spacing = 0 if run
        run ||= font.glyph_run(string, kerning:, ligatures: ligatures && letter_spacing.zero?, features:)
        run = run.with_word_spacing(word_spacing, size) unless word_spacing.zero?
        width = run.width(size, letter_spacing:)
        glyphs(run, x, y, font:, size:, color:, letter_spacing:, rise:, bold: synthetic_bold,
                          oblique: synthetic_oblique, opacity:)
        decorate(x, y, width, font, size, color:, underline:, strikethrough:)
        width
      end

      private

      def decorate(x, y, width, font, size, color:, underline:, strikethrough:)
        fill_rect(x, y - font.underline_position(size), width, font.underline_thickness(size), color:) if underline
        return unless strikethrough

        fill_rect(x, y - font.strikeout_position(size), width, font.strikeout_size(size), color:)
      end
    end
  end
end
