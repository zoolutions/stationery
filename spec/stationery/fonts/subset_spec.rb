# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Subset do
  let(:ttf) { Stationery::Fonts::TrueType.new(File.binread(font_path("OpenSans-Regular.ttf"))) }
  let(:gids) { "Hello Ü".chars.map { |c| ttf.glyph_id(c.ord) }.uniq }

  it "keeps only the requested glyphs, their components and .notdef, renumbered from zero" do
    data, mapping = described_class.build(ttf, gids)
    subset = Stationery::Fonts::TrueType.new(data, cmap: false)

    expect(mapping[0]).to eq(0)
    expect(mapping.values.sort).to eq((0...mapping.size).to_a)
    expect(mapping.keys).to include(*gids)
    expect(subset.num_glyphs).to eq(mapping.size)
    expect(subset.num_glyphs).to be < ttf.num_glyphs
  end

  it "carries no character map, since the PDF maps glyph ids itself" do
    data, _mapping = described_class.build(ttf, gids)

    expect { Stationery::Fonts::TrueType.new(data) }.to raise_error(Stationery::UnsupportedFont, /cmap/)
  end

  it "includes the components of composite glyphs" do
    u_umlaut = ttf.glyph_id("Ü".ord)
    _data, mapping = described_class.build(ttf, [u_umlaut])

    expect(mapping.size).to be > 2
  end

  it "preserves advance widths for the kept glyphs" do
    data, mapping = described_class.build(ttf, gids)
    subset = Stationery::Fonts::TrueType.new(data, cmap: false)

    gids.each { |gid| expect(subset.advance(mapping.fetch(gid))).to eq(ttf.advance(gid)) }
  end

  it "writes a valid sfnt: every table checksum and the whole-font adjustment agree" do
    data, _mapping = described_class.build(ttf, gids)
    table_count = data.byteslice(4, 2).unpack1("n")

    table_count.times do |i|
      tag, checksum, offset, length = data.byteslice(12 + (i * 16), 16).unpack("a4NNN")
      body = data.byteslice(offset, length)
      body = body.dup.tap { |b| b[8, 4] = "\0\0\0\0" } if tag == "head"
      expect(described_class.checksum(body)).to eq(checksum), "checksum mismatch for #{tag}"
    end
    expect(described_class.checksum(data)).to eq(0xB1B0AFBA)
  end
end
