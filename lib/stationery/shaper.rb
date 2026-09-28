# frozen_string_literal: true

module Stationery
  # The hook for complex-script shaping. Stationery maps characters to glyphs
  # one by one, with the font's ligatures and pair kerning; it does not shape
  # Arabic, Indic or Thai text and does not reorder right-to-left text. An
  # application that has a native shaper (HarfBuzz) plugs it in here:
  #
  #   class Invoice < Stationery::Document
  #     shaper MyShaper
  #   end
  #
  #   Invoice.new.to_pdf(shaper: MyShaper)
  #
  # A shaper is any object answering
  #
  #   call(text, font, size:, features:, language:) # => [Shaper::Glyph, …] or nil
  #
  # and should take `**options`, so an option added later does not break it.
  #
  # `text` is one stretch of a line in one font and style (see below);
  # `font` is a Shaper::Face. `size:` is the size drawn at in points,
  # `features:` a frozen Hash of OpenType feature tags to switches
  # (`{ "kern" => true, "liga" => false, "smcp" => true }`: `kern` and `liga`
  # are always there and follow the style's `kerning:` and `ligatures:`, the
  # rest are its `features:`), `language:` the document's `metadata lang:` or
  # nil. Direction and script are not passed, stationery knows neither: the
  # shaper works them out from the text.
  #
  # The answer is the glyphs in visual order, left to right, each a
  # Shaper::Glyph (or a Hash of its fields). Answering nil declines: the text
  # is then drawn as it is without a shaper.
  #
  # What is shaped: line breaking measures each word and each stretch of
  # spaces on its own, so it needs no more than the advances; every line is
  # then cut where the font or the style changes, and each of those stretches
  # is shaped whole, measured and drawn from that one answer. The shaper
  # reorders within the stretch it is given and nowhere else.
  module Shaper
    # One glyph of a shaper's answer. `gid` is the glyph id in the font,
    # `advance` how far the pen moves after it and `x_offset`/`y_offset` where
    # it is drawn from the pen (to the right and up), all in font units;
    # `cluster` is the index in `text`, in characters, of the first character
    # the glyph stands for. The glyphs of one cluster stand together for its
    # characters: those from `cluster` up to the next cluster in the answer.
    Glyph = Data.define(:gid, :advance, :x_offset, :y_offset, :cluster) do
      def initialize(gid:, advance:, cluster:, x_offset: 0, y_offset: 0)
        super
      end
    end

    # The font a shaper is asked to shape with. `data` is the font program as
    # stationery read it (an sfnt: a WOFF is already unpacked) and `index` the
    # face in it when it is a collection; `path` is the file it came from, or
    # nil when it was not read from one.
    Face = Data.define(:path, :index, :data, :units_per_em, :postscript_name, :glyph_count) do
      def inspect = "#<#{self.class} #{postscript_name} index=#{index} glyphs=#{glyph_count}>"
    end

    METRICS = %i[advance x_offset y_offset].freeze

    module_function

    # `shaper` when it can be called, nil for none.
    def check(shaper)
      return shaper if shaper.nil? || shaper.respond_to?(:call)

      raise ArgumentError, "shaper must answer call(text, font, **options), got #{shaper.inspect}"
    end

    # A shaper's answer for `text` as Glyphs, or a ShaperError naming what is
    # wrong with it.
    def glyphs(answer, text, face)
      return answer.map { |glyph| glyph(glyph, text, face) } if answer.is_a?(Array)

      raise ShaperError, "shaper must answer an Array of glyphs or nil, got #{answer.inspect}"
    end

    def glyph(value, text, face)
      glyph = value.is_a?(Hash) ? from_hash(value) : value
      raise ShaperError, "shaper answered #{value.inspect}, not a Stationery::Shaper::Glyph" unless glyph.is_a?(Glyph)

      within(glyph, :gid, face.glyph_count, "the font has #{face.glyph_count} glyphs")
      within(glyph, :cluster, text.length, "the text has #{text.length} characters")
      METRICS.each { |field| finite(glyph, field) }
      glyph
    end

    def from_hash(fields)
      Glyph.new(**fields)
    rescue ArgumentError => e
      raise ShaperError, "shaper answered #{fields.inspect}: #{e.message}"
    end

    def within(glyph, field, count, limit)
      value = glyph.public_send(field)
      return if value.is_a?(Integer) && value >= 0 && value < count

      raise ShaperError, "shaper answered #{field} #{value.inspect}: #{limit}"
    end

    def finite(glyph, field)
      value = glyph.public_send(field)
      return if value.is_a?(Integer) || (value.is_a?(Float) && value.finite?)

      raise ShaperError, "shaper answered #{field} #{value.inspect}, not a number of font units"
    end
  end
end
