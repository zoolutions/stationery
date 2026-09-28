# frozen_string_literal: true

RSpec.describe Stationery::Monochrome::Grid do
  subject(:grid) { described_class.new(72) }

  def rect(x, y, w, h) = Stationery::Path.new.rect(x, y, w, h).each_segment.to_a

  it "is one dot per 72/dpi points" do
    expect(grid.dot).to eq(1.0)
    expect(described_class.new(203).dot).to be_within(1e-6).of(0.354679)
    expect(grid.dots(2.4)).to eq(2)
    expect(grid.dots(0.4)).to eq(0)
    expect(grid.edge(10.6)).to eq(11)
  end

  it "centres a stroke of an odd number of dots on half a dot, of an even number on a whole one" do
    expect(grid.centre(10.2, 1)).to eq(10.5)
    expect(grid.centre(10.2, 2)).to eq(10)
    expect(grid.centre(10.7, 3)).to eq(10.5)
  end

  describe "#rect" do
    it "rounds the position and the size to whole dots, so a rule is as wide wherever it lands" do
      expect(grid.rect(10.4, 20.6, 50.2, 1.4)).to eq([10, 21, 50, 1])
      expect(grid.rect(10.6, 20.4, 50.2, 1.4)).to eq([11, 20, 50, 1])
    end

    it "never makes a side less than a dot" do
      expect(grid.rect(10, 20, 50, 0.2)).to eq([10, 20, 50, 1])
    end
  end

  describe "#rectangle" do
    it "reads one axis-aligned rectangle back from its segments" do
      expect(grid.rectangle(rect(1, 2, 3, 4))).to eq([1, 2, 3, 4])
      expect(grid.rectangle(rect(4, 6, -3, -4))).to eq([1, 2, 3, 4])
    end

    it "answers nil for anything else" do
      expect(grid.rectangle(Stationery::Path.new.ellipse(5, 5, 2, 2).each_segment.to_a)).to be_nil
      expect(grid.rectangle(rect(0, 0, 1, 1) + rect(2, 2, 1, 1))).to be_nil
      expect(grid.rectangle([[:move, 0, 0], [:line, 5, 1], [:line, 5, 5], [:line, 0, 5], :close])).to be_nil
    end
  end

  describe "#stroke" do
    it "puts a horizontal line's edges on the grid: its ends, and its sides for the width" do
      line = [[:move, 10.3, 20.2], [:line, 60.6, 20.2]]

      expect(grid.stroke(line, 1)).to eq([[:move, 10, 20.5], [:line, 61, 20.5]])
      expect(grid.stroke(line, 2)).to eq([[:move, 10, 20], [:line, 61, 20]])
    end

    it "centres every side of a stroked rectangle" do
      expect(grid.stroke(rect(10.2, 20.2, 30, 10), 1))
        .to eq([[:move, 10.5, 20.5], [:line, 40.5, 20.5], [:line, 40.5, 30.5], [:line, 10.5, 30.5], :close])
    end

    it "answers nil for a path that is not all horizontal and vertical lines" do
      expect(grid.stroke([[:move, 0, 0], [:line, 5, 5]], 1)).to be_nil
      expect(grid.stroke(Stationery::Path.new.ellipse(5, 5, 2, 2).each_segment.to_a, 1)).to be_nil
    end
  end
end
