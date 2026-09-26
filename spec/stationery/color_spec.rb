# frozen_string_literal: true

RSpec.describe Stationery::Color do
  it "parses hex with or without a hash, and three-digit hex" do
    expect(described_class.parse("#FF8000").components).to eq([1.0, 128 / 255.0, 0.0])
    expect(described_class.parse("ff8000").components).to eq([1.0, 128 / 255.0, 0.0])
    expect(described_class.parse("#f80").components).to eq([1.0, 136 / 255.0, 0.0])
  end

  it "parses 0-255 RGB and 0-100 CMYK arrays" do
    expect(described_class.parse([255, 0, 51]).components).to eq([1.0, 0.0, 0.2])
    expect(described_class.parse([0, 50, 100, 10])).to have_attributes(space: :cmyk, components: [0.0, 0.5, 1.0, 0.1])
  end

  it "never mutates the value it was given" do
    value = +"#123456"
    described_class.parse(value)

    expect(value).to eq("#123456")
  end

  it "emits fill and stroke operators" do
    expect(described_class.parse("#000000").fill).to eq("0 0 0 rg")
    expect(described_class.parse("#FFFFFF").stroke).to eq("1 1 1 RG")
    expect(described_class.parse([0, 0, 0, 100]).fill).to eq("0 0 0 1 k")
  end

  it "passes a Color through and rejects nonsense with a clear message" do
    color = described_class.parse("#000")

    expect(described_class.parse(color)).to equal(color)
    expect { described_class.parse("red!") }.to raise_error(ArgumentError, /colour/)
    expect { described_class.parse([1, 2]) }.to raise_error(ArgumentError, /colour/)
  end
end
