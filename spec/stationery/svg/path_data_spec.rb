# frozen_string_literal: true

RSpec.describe Stationery::SVG::PathData do
  def segments(d) = described_class.parse(d)

  it "reads absolute and relative moves, lines and closes, with implicit repeats" do
    expect(segments("M10 20 L30 40 l5 5 H0 v10 Z")).to eq(
      [[:move, 10, 20], [:line, 30, 40], [:line, 35, 45], [:line, 0, 45], [:line, 0, 55], [:close]]
    )
    expect(segments("m1,1 2,2 3,3")).to eq([[:move, 1, 1], [:line, 3, 3], [:line, 6, 6]])
  end

  it "reads compact numbers: signs and dots as separators, exponents" do
    expect(segments("M.5-1.5L1e1.5")).to eq([[:move, 0.5, -1.5], [:line, 10.0, 0.5]])
  end

  it "reads cubic and smooth cubic curves, reflecting the previous control point" do
    result = segments("M0 0 C10 0 20 10 20 20 S30 40 40 40")

    expect(result[1]).to eq([:curve, 10, 0, 20, 10, 20, 20])
    expect(result[2]).to eq([:curve, 20, 30, 30, 40, 40, 40])
  end

  it "turns quadratic curves into cubics" do
    result = segments("M0 0 Q30 30 60 0")

    expect(result[1]).to eq([:curve, 20.0, 20.0, 40.0, 20.0, 60, 0])
  end

  it "turns arcs into cubic segments that end on the arc's endpoint" do
    result = segments("M138.14,128a16,16,0,1,1,26.64,17.63")
    curves = result.drop(1)

    expect(curves).to all(satisfy { |segment| segment.first == :curve })
    expect(curves.last.last(2).map { |v| v.round(2) }).to eq([164.78, 145.63])
    expect(curves.size).to be_between(2, 4)
  end

  it "reads arc flags written without separators" do
    expect(segments("M0 0 a5 5 0 017 7").last.last(2).map(&:round)).to eq([7, 7])
  end

  it "drops a zero-radius arc to a straight line" do
    expect(segments("M0 0 A0 5 0 0 1 10 10").last).to eq([:line, 10, 10])
  end

  it "refuses path data it cannot read" do
    expect { segments("M0 0 X10") }.to raise_error(Stationery::SVG::Error, /path data/)
  end
end
