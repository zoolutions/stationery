# frozen_string_literal: true

RSpec.describe Stationery::Layout::Floated do
  let(:block) { Stationery::Layout::Box.new(flow, width: 80, height: 40) }

  def painted_at(node, width: 200)
    calls = []
    allow(node.node).to receive(:paint) { |_canvas, x, y, w| calls << [x, y, w] }
    node.paint(nil, 10, 20, width)
    calls.first
  end

  it "is a float on the side it is given" do
    node = described_class.new(block, side: :right)

    expect(node).to be_float
    expect(node.side).to eq(:right)
    expect(node).not_to be_wraps
    expect(node).not_to be_splittable
  end

  it "rejects any other side" do
    expect { described_class.new(block, side: :center) }
      .to raise_error(ArgumentError, "float: must be :left or :right, got :center")
  end

  it "keeps a number of points towards the text: the inner side and the bottom" do
    expect(described_class.new(block, side: :left, margin: 6).margin).to eq([0, 6, 6, 0])
    expect(described_class.new(block, side: :right, margin: 6).margin).to eq([0, 0, 6, 6])
    expect(described_class.new(block, side: :left).margin).to eq([0, 0, 0, 0])
  end

  it "takes every side from a Hash or an Array, as padding does" do
    expect(described_class.new(block, side: :left, margin: { x: 4, bottom: 8 }).margin).to eq([0, 4, 8, 4])
    expect(described_class.new(block, side: :left, margin: [1, 2, 3, 4]).margin).to eq([1, 2, 3, 4])
  end

  it "measures and paints with its margins around the node" do
    node = described_class.new(block, side: :left, margin: [1, 2, 3, 4])

    expect(node.fixed_width(200)).to eq(86)
    expect(node.measure(86)).to eq(44)
    expect(node.natural_width).to eq(86)
    expect(node.min_width).to eq(86)
    expect(described_class.new(Stationery::Layout::Box.new(flow, width: 0.5), side: :left, margin: 3).min_width)
      .to eq(3)
    expect(painted_at(node, width: 86)).to eq([14, 21, 80])
  end

  it "is at least as wide as the widest word of a node without a width" do
    text = text_node("some words")

    expect(described_class.new(text, side: :left, margin: 2).min_width).to eq(text.min_width + 2)
  end

  it "takes a fraction of the width that its margins leave" do
    node = described_class.new(Stationery::Layout::Box.new(flow, width: 0.5, height: 10), side: :left, margin: 10)

    expect(node.fixed_width(210)).to eq(110)
  end

  it "is never wider than the space it is given" do
    node = described_class.new(Stationery::Layout::Box.new(flow, width: 500, height: 10), side: :left)

    expect(node.fixed_width(200)).to eq(200)
  end

  it "shares the tag of its node" do
    tagged = Stationery::Layout::Box.new(flow, width: 10, role: :note)

    expect(described_class.new(tagged, side: :left).tag).to be(tagged.tag)
  end
end
