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
      NO_FEATURES = [].freeze
      # The bytes of text the shape and metrics memos hold before they start
      # over. They exist for the words and lines a document repeats; without a
      # limit a long document would keep every line it ever drew.
      MEMO_BYTES = 1 << 16
      REPLACEMENT = "\uFFFD"
      # What is drawn for a character no font has when the render replaces
      # missing glyphs (`missing_glyphs: :replace`): the first of these the
      # font has a glyph for.
      STAND_INS = [REPLACEMENT, "\u25A1", "?"].freeze
      StandIn = Data.define(:char, :gid)

      attr_reader :ttf

      # `shaper:` places this font's glyphs instead of the font itself (see
      # Shaper); `path:` is the file the font was read from and `language:`
      # the document's, both for the shaper. `stand_ins:` draws a character
      # the font lacks as its #stand_in instead of .notdef.
      def initialize(ttf, shaper: nil, path: nil, language: nil, stand_ins: false)
        @ttf = ttf
        @stand_in = stand_ins ? find_stand_in : nil
        @shaping = shaper && Shaping.new(self, shaper, path:, language:)
        @loose = nil
        @used = {}
        @pairs = {}
        @glyphs = {}
        @blanks = {}
        @shapes = {}.compare_by_identity
        @metrics = {}.compare_by_identity
        @memoised = 0
        @keys = { true => {}, false => {} }
        @frozen_keys = { true => {}.compare_by_identity, false => {}.compare_by_identity }
        @cid_keyed = ttf.cff? && ttf.cff.cid_keyed?
      end

      def inspect = "#<#{self.class} #{@ttf.postscript_name} used=#{@used.size}>"

      # Advances and kerning are remembered per string, so measuring the same
      # word again (wrapping, then laying out the line) allocates nothing.
      # Letter spacing is added per glyph, so a ligature counts once; any
      # letter spacing turns ligatures off, as it does when drawing.
      # `features:` are OpenType feature tags applied on top of `liga`.
      # With a shaper the width is its glyphs'; `shape: false` measures what
      # #glyph_run draws.
      def width_of(text, size, letter_spacing: 0, kerning: false, ligatures: true, features: NO_FEATURES,
                   shape: true)
        if @shaping && shape && (run = shaped(text, size, letter_spacing:, kerning:, ligatures:, features:))
          return run.width
        end

        ligatures &&= letter_spacing.zero?
        key = shape_key(ligatures, features)
        advance, kern = metrics(text, key)
        width = scale(advance, size)
        width += letter_spacing * shape(text, key).first.size unless letter_spacing.zero?
        return width unless kerning

        width + (kern * size / 1000.0)
      end

      # The GSUB feature tags this font can apply.
      def features = @ttf.ligatures.features

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

      # `ligatures:` substitutes the font's standard ligatures and `features:`
      # any further OpenType features; `kerning:` then fills the adjustments
      # with pair kerning between the glyphs.
      def glyph_run(text, kerning: false, ligatures: true, features: NO_FEATURES)
        gids, chars, blanks = shape(text, shape_key(ligatures, features))
        gids.each { |gid| @used.delete(gid) if @loose.delete(gid) } if @loose
        gids.each_with_index { |gid, i| @used[gid] ||= blanks[i] ? " " : chars[i] }
        @used[@stand_in.gid] = @stand_in.char if @stand_in && @used.key?(@stand_in.gid)
        adjust = gids.each_with_index.map do |gid, i|
          kern = kerning && i + 1 < gids.size ? pair(gid, gids[i + 1]) : 0
          blanks[i] ? kern + (blanks[i] * 1000.0 / @ttf.units_per_em) : kern
        end
        GlyphRun.new(font: self, gids:, adjust:, chars:)
      end

      # The text as the document's shaper placed it, a ShapedRun with its
      # letter spacing; nil without a shaper and when the shaper declines.
      def shaped(text, size, letter_spacing: 0, kerning: false, ligatures: true, features: NO_FEATURES)
        return unless @shaping

        @shaping.run(text, size, kerning:, ligatures: ligatures && letter_spacing.zero?, features:)
                &.with_letter_spacing(letter_spacing)
      end

      # Remembers a glyph a shaper placed and the text it stands for, and
      # answers the text the ToUnicode map gives it: the first it stood for.
      # `loosely:` is for a glyph that shares its text with others (it is
      # shown inside a Span): the next text the glyph stands for replaces it.
      def use(gid, text, loosely: false)
        if @used.key?(gid)
          return @used[gid] if loosely || !@loose&.delete(gid)
        elsif loosely
          (@loose ||= {})[gid] = true
        end
        @used[gid] = text
      end

      # The glyph drawn in place of one the font lacks, and the character it
      # is the glyph of (a StandIn); nil when missing glyphs are not replaced
      # and when the font has none of STAND_INS, which a symbol font may not.
      attr_reader :stand_in

      # Whether `gid`, drawn for `text`, stands in for a glyph the font lacks.
      def stands_in?(gid, text)
        return false if @stand_in.nil? || gid != @stand_in.gid || text == @stand_in.char

        !text.each_char.all? { |char| glyph?(char) }
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
      # every character it stands for. Glyph 0, .notdef, stands for every
      # character the font lacks, so it maps to the replacement character
      # and the run's ActualText carries the real ones (see GlyphRun).
      def used_codes
        @used.to_h { |gid, char| [code(gid), gid.zero? ? REPLACEMENT : char] }
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

      # The feature tags to substitute with: `liga` when ligatures are on, plus
      # the requested features. One Array per set of tags, so the memos are
      # keyed by its identity: measuring a word hashes the word and nothing
      # else. A style's frozen tags are looked up by identity too; any other
      # Array is normalised first.
      def shape_key(ligatures, features)
        return ligatures ? Gsub::LIGA : NO_FEATURES if features.empty?

        ligatures = ligatures ? true : false
        return @frozen_keys[ligatures][features] ||= tags_for(ligatures, features) if features.frozen?

        tags_for(ligatures, features)
      end

      def tags_for(ligatures, features)
        features = Text::Style.features(features)
        @keys[ligatures][features] ||= (ligatures ? (features + Gsub::LIGA).sort : features).freeze
      end

      # [gids, source text of each glyph, extra advance in font units after
      # each blank or nil], remembered per string and feature tags.
      def shape(text, tags)
        (@shapes[tags] ||= {})[text] ||= begin
          forget if (@memoised += text.bytesize) > MEMO_BYTES
          gids = text.each_char.map { |char| glyph_for(char) }
          gids, chars = tags.empty? ? [gids, text.chars] : substitute(gids, text, tags)
          [gids, chars, chars.map { |char| blank_units(char) }].each(&:freeze).freeze
        end
      end

      def forget
        @shapes.each_value(&:clear)
        @metrics.each_value(&:clear)
        @memoised = 0
      end

      def substitute(gids, text, tags)
        start = 0
        glyphs = @ttf.ligatures.substitute(gids, tags)
        chars = glyphs.map { |_gid, count| text[start, count].tap { start += count } }
        [glyphs.map(&:first), chars]
      end

      def glyph_for(char)
        return @ttf.glyph_id(" ".ord) if blank?(char)

        gid = @ttf.glyph_id(char.ord)
        gid.zero? && @stand_in ? @stand_in.gid : gid
      end

      def find_stand_in
        char = STAND_INS.find { |candidate| @ttf.glyph?(candidate) }
        char && StandIn.new(char:, gid: @ttf.glyph_id(char.ord))
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

      # [advance in font units, kerning in thousandths of an em] of a string,
      # remembered together so a measurement is one lookup.
      def metrics(text, tags)
        (@metrics[tags] ||= {})[text] ||= begin
          gids, _, blanks = shape(text, tags)
          [gids.sum { |gid| @ttf.advance(gid) } + blanks.sum { |units| units || 0 },
           gids.each_cons(2).sum { |left, right| pair(left, right) }].freeze
        end
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
