# frozen_string_literal: true

module Stationery
  module Fonts
    # One font as used by one document: measures text, encodes it as
    # character codes and remembers which glyphs were drawn so only those are
    # embedded (TrueType) or so the widths and ToUnicode cover them (CFF).
    #
    # Embedded as a Type0 font with Identity-H encoding and a ToUnicode map, so
    # text extracts and searches correctly; the descendant CIDFont comes from
    # Embedding::TrueType or Embedding::CFF.
    class Font
      OBLIQUE_SKEW = Math.tan(12 * Math::PI / 180)

      # Whitespace the font lacks draws as its space glyph advanced to the
      # character's conventional width: a fraction of the em for the fixed
      # spaces, a digit's or a period's advance for the figure and
      # punctuation spaces, the space's own width for the rest (no-break,
      # line and paragraph separators, ogham mark, …). Nothing is painted,
      # nothing is .notdef.
      WHITESPACE = /\A\p{Space}\z/
      SPACE_FRACTIONS = { 0x2000 => 0.5, 0x2001 => 1.0, 0x2002 => 0.5, 0x2003 => 1.0, 0x2004 => 1.0 / 3,
                          0x2005 => 0.25, 0x2006 => 1.0 / 6, 0x2009 => 0.2, 0x200A => 0.125, 0x205F => 4.0 / 18,
                          0x3000 => 1.0 }.freeze
      SPACE_LIKE = { 0x2007 => "0", 0x2008 => "." }.freeze

      attr_reader :ttf

      def initialize(ttf)
        @ttf = ttf
        @used = {}
        @pairs = {}
        @glyphs = {}
        @blanks = {}
        @shapes = { true => {}, false => {} }
        @advances = { true => {}, false => {} }
        @kerns = { true => {}, false => {} }
        @cid_keyed = ttf.cff? && ttf.cff.cid_keyed?
      end

      def inspect = "#<#{self.class} #{@ttf.postscript_name} used=#{@used.size}>"

      # Advances and kerning are remembered per string, so measuring the same
      # word again (wrapping, then laying out the line) allocates nothing.
      # Letter spacing is added per glyph, so a ligature counts once; any
      # letter spacing turns ligatures off, as it does when drawing.
      def width_of(text, size, letter_spacing: 0, kerning: false, ligatures: true)
        ligatures &&= letter_spacing.zero?
        width = scale(advance_units(text, ligatures), size) + (letter_spacing * shape(text, ligatures).first.size)
        return width unless kerning

        width + (kerning_units(text, ligatures) * size / 1000.0)
      end

      def ascender(size) = scale(@ttf.ascender, size)
      def descender(size) = -scale(@ttf.descender, size)
      def line_gap(size) = scale(@ttf.line_gap, size)
      def line_height(size) = ascender(size) + descender(size) + line_gap(size)
      def x_height(size) = scale(@ttf.x_height, size)
      def underline_position(size) = scale(@ttf.underline_position, size)
      def underline_thickness(size) = scale(@ttf.underline_thickness, size)
      def strikeout_position(size) = scale(@ttf.strikeout_position, size)
      def strikeout_size(size) = scale(@ttf.strikeout_size, size)
      def glyph?(char) = @glyphs.fetch(char) { @glyphs[char] = @ttf.glyph?(char) }

      def bold?
        @ttf.weight >= 600
      end

      def encode(text) = glyph_run(text).gids.map { |gid| code(gid) }.pack("n*")

      # `ligatures:` substitutes the font's standard ligatures; `kerning:`
      # then fills the adjustments with pair kerning between the glyphs.
      def glyph_run(text, kerning: false, ligatures: true)
        gids, chars, blanks = shape(text, ligatures)
        gids.each_with_index { |gid, i| @used[gid] ||= blanks[i] ? " " : chars[i] }
        adjust = gids.each_with_index.map do |gid, i|
          kern = kerning && i + 1 < gids.size ? pair(gid, gids[i + 1]) : 0
          blanks[i] ? kern + (blanks[i] * 1000.0 / @ttf.units_per_em) : kern
        end
        GlyphRun.new(font: self, gids:, adjust:, chars:)
      end

      # Whether a character the font lacks is drawn as a blank (see WHITESPACE).
      def blank?(char)
        @blanks.fetch(char) { @blanks[char] = WHITESPACE.match?(char) && !glyph?(char) && glyph?(" ") }
      end

      def used?
        @used.any?
      end

      # The two-byte character code a glyph is written as: its CID in a
      # CID-keyed CFF font, otherwise the glyph id itself.
      def code(gid)
        @cid_keyed ? @ttf.cff.cid_for(gid) : gid
      end

      # { code => text } for every glyph drawn so far; a ligature's text is
      # every character it stands for.
      def used_codes
        @used.to_h { |gid, char| [code(gid), char] }
      end

      def build(writer)
        embedding = (@ttf.cff? ? Embedding::CFF : Embedding::TrueType).new(self)
        gids = @used.keys.sort
        name, cid_font = Stationery.instrument("font.stationery", font: @ttf.postscript_name, action: :subset,
                                                                  glyphs: gids.size) do
          embedding.build(writer, gids)
        end

        writer.add(
          Type: :Font, Subtype: :Type0, BaseFont: name, Encoding: :"Identity-H",
          DescendantFonts: [cid_font], ToUnicode: writer.add(PDF::Stream.new(ToUnicode.cmap(used_codes)))
        )
      end

      private

      # [gids, source text of each glyph, extra advance in font units after
      # each blank or nil], remembered per string.
      def shape(text, ligatures)
        @shapes[ligatures][text] ||= begin
          gids = text.each_char.map { |char| glyph_for(char) }
          gids, chars = ligatures ? ligate(gids, text) : [gids, text.chars]
          [gids, chars, chars.map { |char| blank_units(char) }].each(&:freeze).freeze
        end
      end

      def ligate(gids, text)
        start = 0
        glyphs = @ttf.ligatures.substitute(gids)
        chars = glyphs.map { |_gid, count| text[start, count].tap { start += count } }
        [glyphs.map(&:first), chars]
      end

      def glyph_for(char)
        blank?(char) ? @ttf.glyph_id(" ".ord) : @ttf.glyph_id(char.ord)
      end

      # How much wider (or narrower) than a space a blank's advance is.
      def blank_units(char)
        return unless blank?(char)

        space = @ttf.advance(@ttf.glyph_id(" ".ord))
        like = SPACE_LIKE[char.ord]
        width = if (fraction = SPACE_FRACTIONS[char.ord]) then @ttf.units_per_em * fraction
                elsif like && glyph?(like) then @ttf.advance(@ttf.glyph_id(like.ord))
                else space
                end
        width - space
      end

      def advance_units(text, ligatures)
        @advances[ligatures][text] ||= begin
          gids, _, blanks = shape(text, ligatures)
          gids.sum { |gid| @ttf.advance(gid) } + blanks.sum { |units| units || 0 }
        end
      end

      def kerning_units(text, ligatures)
        @kerns[ligatures][text] ||= shape(text, ligatures).first.each_cons(2).sum { |left, right| pair(left, right) }
      end

      # Kerning between two glyphs in thousandths of an em.
      def pair(left, right)
        @pairs[(left << 16) | right] ||= @ttf.kerning.adjust(left, right) * 1000.0 / @ttf.units_per_em
      end

      def scale(units, size)
        units * size / @ttf.units_per_em.to_f
      end
    end
  end
end
