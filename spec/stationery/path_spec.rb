# frozen_string_literal: true

RSpec.describe Stationery::Path do
  subject(:path) { described_class.new }

  it "keeps its segments in top-left space and reads them back in order" do
    path.move_to(1, 2).line_to(3, 4).curve_to(5, 6, 7, 8, 9, 10).close

    expect(path.each_segment.to_a).to eq([[:move, 1, 2], [:line, 3, 4], [:curve, 5, 6, 7, 8, 9, 10], :close])
  end

  it "is empty until something is traced" do
    expect(path).to be_empty
    expect(path.rect(0, 0, 1, 1)).not_to be_empty
    expect(described_class.new.each_segment.to_a).to eq([])
  end

  it "reads a rectangle back as a move, three lines and a close" do
    path.rect(10, 20, 30, 40)

    expect(path.each_segment.to_a).to eq([[:move, 10, 20], [:line, 40, 20], [:line, 40, 60], [:line, 10, 60], :close])
  end

  it "applies its transform to every point as it is added" do
    path = described_class.new(transform: [2, 0, 0, 3, 10, 20])
    path.rect(1, 1, 2, 2)
    path.curve_to(0, 0, 1, 0, 1, 1)

    expect(path.each_segment.to_a).to eq([[:move, 12, 23], [:line, 16, 23], [:line, 16, 29], [:line, 12, 29], :close,
                                          [:curve, 10, 20, 12, 20, 12, 23]])
  end

  it "rounds the corners of a rectangle with curves, a circle with four" do
    rounded = described_class.new.rounded_rect(0, 0, 20, 10, [5, 0, 0, 0]).each_segment.map { Array(it).first }
    circle = described_class.new.ellipse(10, 10, 5, 5).each_segment.map { Array(it).first }

    expect(rounded).to eq(%i[move line line line line curve close])
    expect(circle).to eq(%i[move curve curve curve curve close])
  end

  it "hands the segments to a block without an Array for each" do
    path.move_to(1, 2).line_to(3, 4)
    seen = []
    path.each_segment { |kind, x, y| seen.push(kind, x, y) }

    expect(seen).to eq([:move, 1, 2, :line, 3, 4])
  end
end
