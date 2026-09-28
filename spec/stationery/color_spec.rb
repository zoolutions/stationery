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

  # Objects made by the block; the first block measured in a process makes one of its own.
  def allocations
    GC.disable
    before = GC.stat(:total_allocated_objects)
    yield
    GC.stat(:total_allocated_objects) - before
  ensure
    GC.enable
  end

  it "parses a String once and hands the same frozen Color over again, without allocating" do
    first = described_class.parse("#1A2B3C")

    expect(described_class.parse(+"#1A2B3C")).to equal(first)
    expect(first).to be_frozen
    expect(allocations { 1000.times { described_class.parse("#1A2B3C") } }).to be <= 1
  end

  it "is not fooled by a String changed after it was parsed" do
    value = +"#000000"
    black = described_class.parse(value)
    value.replace("#FFFFFF")

    expect(described_class.parse(value).components).to eq([1.0, 1.0, 1.0])
    expect(described_class.parse("#000000")).to equal(black)
  end

  it "remembers a bounded number of colours" do
    (described_class::MEMO + 10).times { |index| described_class.parse(format("#%06X", index)) }

    expect(described_class.instance_variable_get(:@parsed).size).to be <= described_class::MEMO
    expect(described_class.parse("#000001").components).to eq([0.0, 0.0, 1 / 255.0])
  end

  it "does not remember what it cannot parse" do
    expect { described_class.parse("#12345") }.to raise_error(ArgumentError, /colour/)
    expect(described_class.instance_variable_get(:@parsed)).not_to have_key("#12345")
  end

  it "parses the same colour from many threads" do
    colors = Array.new(8) { Thread.new { Array.new(200) { |i| described_class.parse(format("#%06X", i)) } } }
                  .map(&:value)

    expect(colors.uniq.size).to eq(1)
  end

  it "writes its fill and stroke operators once, as frozen Strings" do
    color = described_class.parse([12, 34, 56])

    expect(color.fill).to equal(color.fill)
    expect(color.stroke).to equal(color.stroke)
    expect([color.fill, color.stroke]).to all(be_frozen)
    expect(color.fill).to eq("0.0471 0.1333 0.2196 rg")
    expect(color.stroke).to eq("0.0471 0.1333 0.2196 RG")
    expect(allocations { 1000.times { color.fill && color.stroke } }).to be <= 1
  end

  it "passes a Color through and rejects nonsense with a clear message" do
    color = described_class.parse("#000")

    expect(described_class.parse(color)).to equal(color)
    expect { described_class.parse("red!") }.to raise_error(ArgumentError, /colour/)
    expect { described_class.parse([1, 2]) }.to raise_error(ArgumentError, /colour/)
  end
end
