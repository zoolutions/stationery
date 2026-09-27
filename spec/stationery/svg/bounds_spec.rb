# frozen_string_literal: true

RSpec.describe Stationery::SVG::Bounds do
  def box_of(markup)
    element = Stationery::SVG::Parser.parse(markup)
    described_class.new.tap { |bounds| Stationery::SVG::Shapes.trace(bounds, element) }.box
  end

  it "measures rects, circles and ellipses by their extent" do
    expect(box_of('<rect x="1" y="2" width="3" height="4" rx="1"/>')).to eq([1, 2, 3, 4])
    expect(box_of('<circle cx="5" cy="5" r="2"/>')).to eq([3, 3, 4, 4])
    expect(box_of('<ellipse cx="5" cy="5" rx="2" ry="1"/>')).to eq([3, 4, 4, 2])
  end

  it "measures curves by their extrema, not their control points" do
    x, y, w, h = box_of('<path d="M0 0 C0 10 10 10 10 0 Z"/>')

    expect([x, y, w]).to eq([0, 0, 10])
    expect(h).to be_within(0.001).of(7.5)
  end

  it "handles curves whose derivative is linear or has no real roots" do
    expect(box_of('<path d="M0 0 C5 5 5 5 10 0"/>')[3]).to be_within(0.001).of(3.75)
    expect(box_of('<path d="M0 0 C1 1 2 2 3 3"/>')).to eq([0, 0, 3, 3])
    expect(box_of('<path d="M0 0 C1 3 2 3 3 3"/>')).to eq([0, 0, 3, 3])
  end

  it "has no box without area" do
    expect(box_of('<line x1="0" y1="0" x2="10" y2="0"/>')).to be_nil
    expect(box_of('<path d=""/>')).to be_nil
  end
end
