# frozen_string_literal: true

RSpec.describe Stationery::Fonts::TrueType do
  subject(:font) { described_class.new(File.binread(font_path("OpenSans-Regular.ttf"))) }

  it "reads the metrics tables" do
    expect(font.units_per_em).to eq(2048)
    expect(font.ascender).to be > 0
    expect(font.descender).to be < 0
    expect(font.bbox.size).to eq(4)
    expect(font.postscript_name).to eq("OpenSans-Regular")
    expect(font.weight).to eq(400)
  end

  it "maps codepoints to glyphs through the Unicode cmap, including non-ASCII" do
    expect(font.glyph_id("A".ord)).to be > 0
    expect(font.glyph_id("ü".ord)).to be > 0
    expect(font.glyph_id("€".ord)).to be > 0
    expect(font.glyph_id(0x1F600)).to eq(0)
  end

  it "answers whether it can draw a character" do
    expect(font.glyph?("ö")).to be(true)
    expect(font.glyph?("😀")).to be(false)
  end

  it "returns advance widths in font units" do
    expect(font.advance(font.glyph_id("W".ord))).to be > font.advance(font.glyph_id("i".ord))
  end

  it "reads a font with a format 12 cmap" do
    inter = described_class.new(File.binread(font_path("Inter-Regular.ttf")))
    expect(inter.glyph_id("A".ord)).to be > 0
  end

  it "rejects formats it cannot embed, naming them" do
    expect { described_class.new("OTTO#{"\0" * 20}") }
      .to raise_error(Stationery::UnsupportedFont, /CFF outlines/)
    expect { described_class.new("ttcf#{"\0" * 20}") }
      .to raise_error(Stationery::UnsupportedFont, /collections/)
    expect { described_class.new(File.binread(font_path("not-a-ttf.woff2"))) }
      .to raise_error(Stationery::UnsupportedFont, /WOFF2/)
    expect { described_class.new("junk" * 10) }
      .to raise_error(Stationery::UnsupportedFont, /not a TrueType font/)
  end
end
