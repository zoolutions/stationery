# frozen_string_literal: true

require "json"

# Outlines read from every kind of font the gem takes, against fontTools'
# (see spec/fixtures/fonts/README.md for how outlines.json was written).
RSpec.describe "Glyph outlines" do # rubocop:disable RSpec/DescribeClass
  let(:reference) { JSON.parse(File.read(font_path("outlines.json"))) }

  def segments(ttf, char)
    ttf.outline(ttf.glyph_id(char.ord)).each_segment.map { |kind, *numbers| [kind.to_s, *numbers] }
  end

  def expect_same(ours, theirs)
    expect(ours.map(&:first)).to eq(theirs.map(&:first))
    ours.zip(theirs).each do |mine, other|
      mine.drop(1).zip(other.drop(1)).each { |a, b| expect(a).to be_within(1e-9).of(b) }
    end
  end

  {
    "OpenSans-Regular.ttf" => "a TrueType font, quadratic curves and a composite accented letter",
    "OpenSans-Regular.woff" => "a WOFF font",
    "OpenSans-Collection.ttc#1" => "the second face of a collection",
    "SourceSans3-Latin.otf" => "a name-keyed CFF font",
    "NotoSansJP-Subset.otf" => "a CID-keyed CFF font"
  }.each do |key, kind|
    it "reads the outlines of #{kind} as fontTools draws them" do
      name, face = key.split("#")
      ttf = Stationery::Fonts::TrueType.new(File.binread(font_path(name)), index: face&.to_i)

      reference.fetch(key).each { |char, theirs| expect_same(segments(ttf, char), theirs) }
    end
  end

  it "reads nothing for a glyph id the font does not have" do
    %w[OpenSans-Regular.ttf SourceSans3-Latin.otf].each do |name|
      ttf = Stationery::Fonts::TrueType.new(File.binread(font_path(name)))

      expect(ttf.outline(ttf.num_glyphs)).to be_empty
    end
  end

  it "puts a glyph on a path at a size, baseline up the page" do
    ttf = Stationery::Fonts::TrueType.new(File.binread(font_path("OpenSans-Regular.ttf")))
    path = Stationery::Path.new

    ttf.outline(ttf.glyph_id("H".ord)).append_to(path, 100, 200, 20.0 / ttf.units_per_em)
    ys = path.each_segment.filter_map { |kind, _x, y| y unless kind == :close }

    expect(ys.max).to be_within(0.01).of(200)
    expect(ys.min).to be_within(0.2).of(200 - (ttf.cap_height * 20.0 / ttf.units_per_em))
  end
end
