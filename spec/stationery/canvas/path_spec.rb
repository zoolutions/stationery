# frozen_string_literal: true

RSpec.describe Stationery::Canvas::Path do
  let(:canvas) { Stationery::Canvas.new(Stationery::Page.new(size: [200, 100]), Stationery::Resources.new) }

  it "is a path, written in PDF space for the page of its canvas" do
    path = described_class.new(canvas).move_to(1, 2).line_to(3, 4.5).curve_to(5, 6, 7, 8, 9, 10).close

    expect(path).to be_a(Stationery::Path)
    expect(path.to_s).to eq("1 98 m\n3 95.5 l\n5 94 7 92 9 90 c\nh")
    expect(path.each_segment.first).to eq([:move, 1, 2])
  end

  it "writes a rectangle as one operator, and as lines under a transform" do
    expect(described_class.new(canvas).rect(10, 20, 30, 40).to_s).to eq("10 40 30 40 re")
    expect(described_class.new(canvas, transform: [1, 0, 0, 1, 5, 5]).rect(0, 0, 10, 10).to_s)
      .to eq("5 95 m\n15 95 l\n15 85 l\n5 85 l\nh")
  end

  it "writes nothing for a path nothing was traced on" do
    expect(described_class.new(canvas).to_s).to eq("")
  end
end
