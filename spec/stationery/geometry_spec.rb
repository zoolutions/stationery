# frozen_string_literal: true

RSpec.describe Stationery::Geometry do
  it "expands CSS-style box shorthands to [top, right, bottom, left]" do
    expect(described_class.box(10)).to eq([10, 10, 10, 10])
    expect(described_class.box([10, 20])).to eq([10, 20, 10, 20])
    expect(described_class.box([10, 20, 30])).to eq([10, 20, 30, 20])
    expect(described_class.box([1, 2, 3, 4])).to eq([1, 2, 3, 4])
    expect(described_class.box(nil)).to eq([0, 0, 0, 0])
  end

  it "accepts a hash with named sides" do
    expect(described_class.box({ top: 5, x: 8 })).to eq([5, 8, 0, 8])
    expect(described_class.box({ y: 4, left: 2 })).to eq([4, 0, 4, 2])
  end

  it "offsets content for an alignment within spare width" do
    expect(described_class.align_offset(:left, 100, 40)).to eq(0)
    expect(described_class.align_offset(:center, 100, 40)).to eq(30)
    expect(described_class.align_offset(:right, 100, 40)).to eq(60)
  end
end
