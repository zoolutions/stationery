# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Kerning do
  def load(name) = Stationery::Fonts::TrueType.new(File.binread(font_path(name)))

  it "uses the kern table when the font has one" do
    expect(described_class.for(load("OpenSans-Regular.ttf"))).to be_a(Stationery::Fonts::KernTable)
  end

  it "adjusts nothing for a font without kerning data" do
    expect(described_class.for(load("Inter-Regular.ttf"))).to equal(described_class::NONE)
    expect(described_class::NONE.adjust(1, 2)).to eq(0)
  end

  it "is built once per parsed font and cached on it" do
    ttf = load("OpenSans-Regular.ttf")

    expect(ttf.kerning).to equal(ttf.kerning)
  end
end
