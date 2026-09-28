# frozen_string_literal: true

# Shapers written in Ruby, standing in for a native one (see
# Stationery::Shaper). Each places the glyphs the font's cmap names, then
# changes what it is named after.
module FakeShapers
  Glyph = Stationery::Shaper::Glyph

  # One glyph per character, as the font advances them.
  def self.nominal(text, face)
    ttf = Stationery::Fonts::Registry.load(face.index.zero? ? face.path : "#{face.path}##{face.index}")
    text.each_char.with_index.map do |char, index|
      gid = ttf.glyph_id(char.ord)
      Glyph.new(gid:, advance: ttf.advance(gid), cluster: index)
    end
  end

  # Records every call, and answers what `block` makes of the nominal glyphs.
  class Recording
    attr_reader :calls

    def initialize(&block)
      @block = block || ->(glyphs, _text) { glyphs }
      @calls = []
    end

    def call(text, face, **options)
      @calls << [text, face, options]
      @block.call(FakeShapers.nominal(text, face), text)
    end

    def texts = @calls.map(&:first)
  end

  NOMINAL = ->(text, face, **) { nominal(text, face) }

  # Right to left: the glyphs in reverse, each 100 units wider.
  REVERSED = lambda do |text, face, **|
    nominal(text, face).reverse.map { |glyph| glyph.with(advance: glyph.advance + 100) }
  end

  # Every glyph twice as wide as the font makes it.
  WIDE = ->(text, face, **) { nominal(text, face).map { |glyph| glyph.with(advance: glyph.advance * 2) } }

  # "fi" becomes the glyph of "f" alone, standing for both characters.
  LIGATING = lambda do |text, face, **|
    nominal(text, face).reject.with_index { |_, index| index.positive? && text[index - 1, 2] == "fi" }
  end

  # A combining mark is drawn over the glyph before it: no advance, moved
  # back and up, in the cluster of its base.
  MARKING = lambda do |text, face, **|
    glyphs = nominal(text, face)
    glyphs.each_with_index.map do |glyph, index|
      next glyph unless text[index].match?(/\p{M}/) && index.positive?

      glyph.with(advance: 0, x_offset: -300, y_offset: 120, cluster: glyphs[index - 1].cluster)
    end
  end

  # A combining mark is drawn before its base, over where the base will be:
  # no advance, moved forward and up, in the cluster of its base. HarfBuzz
  # answers this for the marks of a right-to-left script.
  MARK_FIRST = lambda do |text, face, **|
    clusters = nominal(text, face).slice_when { |_, glyph| !text[glyph.cluster].match?(/\p{M}/) }
    clusters.flat_map do |base, *marks|
      marks.map { |mark| mark.with(advance: 0, x_offset: 300, y_offset: 120, cluster: base.cluster) } << base
    end
  end

  # Right to left, every glyph drawn over the one before: no advance at all.
  STACKED = ->(text, face, **) { nominal(text, face).reverse.map { |glyph| glyph.with(advance: 0) } }

  DECLINING = ->(*, **) {}
  EMPTY = ->(*, **) { [] }
end
