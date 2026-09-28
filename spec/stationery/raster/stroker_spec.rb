# frozen_string_literal: true

RSpec.describe Stationery::Raster::Stroker do
  let(:scanner) { Stationery::Raster::Scanner.new(100, 100, antialias: true) }
  let(:line) { [[[10, 20, 50, 20], false]] }

  def area(polylines, **)
    polygons = described_class.new(tolerance: 0.05, **).polygons(polylines)
    scanner.spans(polygons).to_a.sum { |_, x0, x1, coverage| (x1 - x0) * coverage }
  end

  it "strokes a line as wide as the line width, square at its ends with butt caps" do
    expect(area(line, width: 4)).to be_within(0.01).of(160)
  end

  it "extends each end by half the width with square caps" do
    expect(area(line, width: 4, cap: :square)).to be_within(0.01).of(176)
  end

  it "rounds each end with round caps" do
    expect(area(line, width: 4, cap: :round)).to be_within(0.3).of(160 + (Math::PI * 4))
  end

  it "joins a corner with a miter, as one outline with no seam" do
    corner = [[[10, 10, 50, 10, 50, 50], false]]

    expect(area(corner, width: 4)).to be_within(0.01).of((42 * 4) + (38 * 4))
    expect(area(corner, width: 4, join: :bevel)).to be_within(0.01).of((42 * 4) + (38 * 4) - 2)
    expect(area(corner, width: 4, join: :round)).to be_within(0.2).of((42 * 4) + (38 * 4) - 4 + Math::PI)
  end

  it "bevels a miter longer than the limit, as PDF's default limit of 10 does" do
    sharp = [[[10, 50, 50, 52, 10, 54], false]]
    mitered = area(sharp, width: 2, miter_limit: 1000)

    expect(area(sharp, width: 2)).to be < mitered - 10
  end

  it "closes a closed path with a join and no caps" do
    box = [[[10, 10, 50, 10, 50, 50, 10, 50], true]]

    expect(area(box, width: 2, cap: :round)).to be_within(0.01).of((42 * 42) - (38 * 38))
  end

  it "draws the dashes of a dash pattern, the pattern repeating" do
    expect(area(line, width: 2, dash: [5, 5])).to be_within(0.01).of(40)
    expect(area(line, width: 2, dash: [5])).to be_within(0.01).of(40)
    expect(area(line, width: 2, dash: [10, 5, 5, 5])).to be_within(0.01).of(50)
  end

  it "draws a dot for a line of no length with round caps, and nothing with butt caps" do
    dot = [[[30, 30, 30, 30], false]]

    expect(area(dot, width: 4, cap: :round)).to be_within(0.3).of(Math::PI * 4)
    expect(area(dot, width: 4)).to eq(0)
  end
end
