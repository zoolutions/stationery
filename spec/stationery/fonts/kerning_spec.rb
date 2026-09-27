# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Kerning do
  def load(name) = Stationery::Fonts::TrueType.new(File.binread(font_path(name)))

  it "falls back to the kern table when GPOS has no kern feature" do
    expect(described_class.for(load("OpenSans-Regular.ttf"))).to be_a(Stationery::Fonts::KernTable)
  end

  it "prefers a GPOS kern feature over the kern table" do
    ttf = load("OpenSans-Regular.ttf")
    gpos = Stationery::Fonts::Gpos.parse(load("Inter-Regular.ttf"))
    allow(Stationery::Fonts::Gpos).to receive(:parse).and_call_original
    allow(Stationery::Fonts::Gpos).to receive(:parse).with(ttf).and_return(gpos)

    expect(described_class.for(ttf)).to equal(gpos)
    expect(described_class.for(load("Inter-Regular.ttf"))).to be_a(Stationery::Fonts::Gpos)
  end

  it "adjusts nothing for a font without kerning data" do
    ttf = load("Inter-Regular.ttf")
    allow(ttf).to receive(:table_offset).and_call_original
    allow(ttf).to receive(:table_offset).with("GPOS").and_return(nil)

    expect(described_class.for(ttf)).to equal(described_class::NONE)
    expect(described_class::NONE.adjust(1, 2)).to eq(0)
  end

  it "is built once per parsed font and cached on it" do
    ttf = load("OpenSans-Regular.ttf")

    expect(ttf.kerning).to equal(ttf.kerning)
  end
end
