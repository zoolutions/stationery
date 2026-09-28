# frozen_string_literal: true

# A shaper for Stationery::Shaper built on HarfBuzz, through the harfbuzz-ruby
# gem (https://github.com/ydah/harfbuzz, `require "harfbuzz"`). Stationery
# does not depend on it: copy this file into the application that needs
# Arabic, Hebrew, Indic or Thai text and add to its Gemfile
#
#   gem "harfbuzz-ruby"
#
# with the HarfBuzz library installed (`brew install harfbuzz`,
# `apt-get install libharfbuzz-dev`). Then
#
#   class Invoice < Stationery::Document
#     shaper HarfBuzzShaper.new
#     font_family "Noto Sans Arabic", regular: "NotoSansArabic-Regular.ttf"
#   end
#
# Run it to write examples/shaping/harfbuzz_shaper.pdf with a font that has
# the Arabic script:
#
#   ruby -Ilib examples/shaping/harfbuzz_shaper.rb NotoSansArabic-Regular.ttf
#
# What it does not do: the Unicode bidirectional algorithm. A stretch of text
# is cut into runs of one direction by its letters alone (digits read left to
# right, spaces and punctuation go with their neighbours), which places
# "فاتورة 2024" and "Total: ٤٠ ريال" as a reader expects and gets nested
# quotations, brackets and explicit embeddings wrong. An application that
# needs those resolves the levels itself and shapes each run as #shape does.
require "harfbuzz"
require "stationery"

class HarfBuzzShaper
  RIGHT_TO_LEFT = /[\p{Arabic}\p{Hebrew}\p{Syriac}\p{Thaana}\p{Nko}]/
  STRONG = /[\p{L}\p{Nd}]/
  Run = Data.define(:direction, :start, :length)

  def initialize
    @fonts = {}
    @mutex = Mutex.new
  end

  # The glyphs of `text` in visual order; see Stationery::Shaper.
  def call(text, font, features:, language: nil, **)
    hb_font = font_for(font)
    switches = HarfBuzz::Feature.from_hash(features)
    codepoints = text.codepoints
    runs(text).flat_map { |run| shape(hb_font, codepoints, run, switches, language) }
  end

  private

  # One HarfBuzz font per font file and face, kept between renders. The
  # default scale of a HarfBuzz font is its units per em, so what it answers
  # is in font units, as stationery asks.
  def font_for(font)
    @mutex.synchronize do
      @fonts[[font.path || font.postscript_name, font.index]] ||=
        HarfBuzz::Font.new(HarfBuzz::Face.new(HarfBuzz::Blob.new(font.data), font.index))
    end
  end

  # The whole text is given to HarfBuzz with the run marked in it, so a run
  # is shaped in its context and the clusters count characters of the text.
  def shape(font, codepoints, run, features, language)
    buffer = HarfBuzz::Buffer.new
    buffer.add_codepoints(codepoints, item_offset: run.start, item_length: run.length)
    buffer.direction = run.direction
    buffer.language = HarfBuzz.language(language) if language
    buffer.guess_segment_properties # the script, from the text
    HarfBuzz.shape(font, buffer, features)
    glyphs = []
    buffer.each_glyph do |gid, cluster, x_advance, _y_advance, x_offset, y_offset|
      glyphs << Stationery::Shaper::Glyph.new(gid:, cluster:, advance: x_advance, x_offset:, y_offset:)
    end
    glyphs
  end

  # The runs of one direction in visual order: from the right when the text
  # starts right to left.
  def runs(text)
    directions = resolve(text.each_char.map { |char| direction_of(char) })
    start = 0
    runs = directions.chunk_while { |left, right| left == right }.map do |run|
      Run.new(run.first, start, run.size).tap { start += run.size }
    end
    directions.first == :rtl ? runs.reverse : runs
  end

  def direction_of(char)
    return unless STRONG.match?(char)

    RIGHT_TO_LEFT.match?(char) && !char.match?(/\p{Nd}/) ? :rtl : :ltr
  end

  # Spaces and punctuation take the direction both their neighbours have,
  # else the direction the text starts in.
  def resolve(directions)
    base = directions.compact.first || :ltr
    directions.each_with_index.map do |direction, index|
      next direction if direction

      before = directions[0...index].compact.last || base
      after = directions[(index + 1)..].compact.first || base
      before == after ? before : base
    end
  end
end

if $PROGRAM_NAME == __FILE__
  font = ARGV.fetch(0) { abort "usage: ruby -Ilib #{__FILE__} path/to/NotoSansArabic-Regular.ttf" }

  class ExampleShaping < Stationery::Document
    page size: :a5, margin: 36
    metadata title: "فاتورة", lang: "ar"
    shaper HarfBuzzShaper.new

    def view_template
      text "فاتورة ضريبية", size: 22, align: :right
      text "مرحبا بالعالم، هذه فاتورة رقم 2024 بقيمة ٤٠ ريال.", size: 14, align: :right
      text "السَّلَامُ عَلَيْكُمْ", size: 18, align: :right
    end
  end

  ExampleShaping.font_family "Arabic", regular: font
  ExampleShaping.default_text font: "Arabic"
  out = File.expand_path("harfbuzz_shaper.pdf", __dir__)
  document = ExampleShaping.new
  document.to_pdf(out)
  document.warnings.each { |warning| warn warning.message }
  puts "wrote #{out}"
end
