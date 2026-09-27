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

  it "estimates a cap height for fonts without an OS/2 table" do
    data, = Stationery::Fonts::Subset.build(font, [0, font.glyph_id("A".ord)])
    subset = described_class.new(data, cmap: false)

    expect(subset.cap_height).to eq((subset.ascender * 0.7).round)
    expect(subset.x_height).to eq((subset.ascender * 0.5).round)
    expect { Stationery::Fonts::Font.new(subset).build(Stationery::PDF::Writer.new) }.not_to raise_error
  end

  it "reads a font with a format 12 cmap" do
    inter = described_class.new(File.binread(font_path("Inter-Regular.ttf")))
    expect(inter.glyph_id("A".ord)).to be > 0
  end

  it "reads an OpenType font with CFF outlines, kerned from GPOS" do
    otf = described_class.new(File.binread(font_path("SourceSans3-Latin.otf")))
    a, v, u = %w[A V Ü].map { |c| otf.glyph_id(c.ord) }

    expect(otf).to be_cff
    expect(otf.postscript_name).to eq("SourceSans3-Regular")
    expect([a, v, u]).to eq([2, 23, 80])
    expect(otf.advance(0)).to eq(653)
    expect(otf.kerning).to be_a(Stationery::Fonts::Gpos)
    expect(otf.kerning.adjust(a, v)).to be < 0
    expect(font).not_to be_cff
    expect(font.cff).to be_nil
  end

  it "falls back to a cap height from the ascender when there is no OS/2 table" do
    data, = Stationery::Fonts::Subset.build(font, [font.glyph_id("H".ord)])
    subset = described_class.new(data, cmap: false)

    expect(subset.table?("OS/2")).to be(false)
    expect(subset.cap_height).to eq((subset.ascender * 0.7).round)
    expect { Stationery::Fonts::Font.new(subset).build(Stationery::PDF::Writer.new) }.not_to raise_error
  end

  def sfnt(signature, tags)
    [signature, tags.size, 0, 0, 0].pack("a4nnnn") + tags.map { |tag| [tag, 0, 0, 0].pack("a4NNN") }.join
  end

  it "rejects variable CFF2 fonts and fonts without outlines" do
    expect { described_class.new(sfnt("OTTO", %w[CFF2 head hhea maxp hmtx cmap])) }
      .to raise_error(Stationery::UnsupportedFont, /variable CFF2 fonts are not supported/)
    expect { described_class.new(sfnt("OTTO", %w[head hhea maxp hmtx cmap])) }
      .to raise_error(Stationery::UnsupportedFont, /missing the CFF table/)
    expect { described_class.new(sfnt("true", %w[head hhea maxp hmtx cmap glyf])) }
      .to raise_error(Stationery::UnsupportedFont, /missing the loca table/)
  end

  it "rejects formats it cannot embed, naming them" do
    expect { described_class.new("wOFF#{"\0" * 20}") }
      .to raise_error(Stationery::UnsupportedFont, /WOFF web fonts/)
    expect { described_class.new(File.binread(font_path("not-a-ttf.woff2"))) }
      .to raise_error(Stationery::UnsupportedFont, /WOFF2/)
    expect { described_class.new("junk" * 10) }
      .to raise_error(Stationery::UnsupportedFont, /not a TrueType font/)
  end

  describe "a TrueType collection" do
    let(:collection) { File.binread(font_path("OpenSans-Collection.ttc")) }

    it "counts its faces" do
      expect(described_class.collection?(collection)).to be(true)
      expect(described_class.faces(collection)).to eq(2)
      expect(described_class.collection?(font.data)).to be(false)
      expect(described_class.faces(font.data)).to eq(1)
    end

    it "parses the face at an index, face 0 by default" do
      expect(described_class.new(collection).postscript_name).to eq("OpenSans-Regular")
      expect(described_class.new(collection, index: 0).postscript_name).to eq("OpenSans-Regular")
      bold = described_class.new(collection, index: 1)

      expect(bold.postscript_name).to eq("OpenSans-Bold")
      expect(bold.weight).to eq(700)
      expect(bold.advance(bold.glyph_id("W".ord))).to be > 0
    end

    it "raises for a face index out of range, naming the face count" do
      expect { described_class.new(collection, index: 5) }.to raise_error(ArgumentError, /face 5.*numFonts 2/)
      expect { described_class.new(font.data, index: 1) }.to raise_error(ArgumentError, /face 1.*numFonts 1/)
    end

    it "subsets and embeds a face from the collection" do
      bold = described_class.new(collection, index: 1)
      data, = Stationery::Fonts::Subset.build(bold, "Bold".chars.map { |c| bold.glyph_id(c.ord) })

      expect(described_class.new(data, cmap: false).num_glyphs).to eq(5)
      expect { Stationery::Fonts::Font.new(bold).build(Stationery::PDF::Writer.new) }.not_to raise_error
    end
  end
end
