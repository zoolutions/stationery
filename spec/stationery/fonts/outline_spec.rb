# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Outline do
  subject(:outline) { described_class.new }

  it "keeps moves, lines, cubic curves and closes in font units" do
    outline.move_to(0, 0).line_to(100, 0).curve_to(100, 50, 50, 100, 0, 100).close

    expect(outline.each_segment.to_a).to eq(
      [[:move, 0, 0], [:line, 100, 0], [:curve, 100, 50, 50, 100, 0, 100], :close]
    )
    expect(outline).not_to be_empty
    expect(described_class.new).to be_empty
  end

  it "raises a quadratic curve to the cubic with its control points two thirds of the way" do
    outline.move_to(0, 0).quad_to(30, 60, 90, 0)

    _, x1, y1, x2, y2, x, y = outline.each_segment.to_a.last
    expect([x1, y1, x2, y2, x, y]).to eq([20.0, 40.0, 50.0, 40.0, 90, 0])
  end

  it "appends itself to a path at a scale and an origin, flipping y into top-left space" do
    outline.move_to(0, 0).line_to(1000, 0).curve_to(1000, 500, 500, 1000, 0, 1000).close
    path = Stationery::Path.new

    outline.append_to(path, 10, 300, 0.25)

    expect(path.each_segment.to_a).to eq(
      [[:move, 10.0, 300.0], [:line, 260.0, 300.0], [:curve, 260.0, 175.0, 135.0, 50.0, 10.0, 50.0], :close]
    )
  end

  it "counts the numbers it holds, for the memo that keeps it" do
    outline.move_to(0, 0).line_to(1, 1).close

    expect(outline.size).to eq(7)
  end
end
