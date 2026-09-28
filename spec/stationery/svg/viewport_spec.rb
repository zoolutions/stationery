# frozen_string_literal: true

RSpec.describe Stationery::SVG::Viewport do
  def viewport(attributes, parent = [200, 100], **) = described_class.new(attributes, parent, **)

  it "takes its rectangle from x, y, width and height, percentages against the parent viewport" do
    port = viewport({ "x" => "10", "y" => "5%", "width" => "50%", "height" => "40" })

    expect([port.x, port.y, port.width, port.height]).to eq([10, 5, 100, 40])
    expect(port.size).to eq([100, 40])
    expect(port.matrix).to eq([1, 0, 0, 1, 10, 5])
  end

  it "fills the parent viewport without a size and ignores x and y for a symbol" do
    port = viewport({ "x" => "10", "y" => "10" }, origin: false)

    expect([port.x, port.y, port.width, port.height]).to eq([0, 0, 200, 100])
  end

  it "fits the viewBox inside the viewport, centred, by default" do
    port = viewport({ "width" => "40", "height" => "20", "viewBox" => "0 0 10 10" })

    expect(port.matrix).to eq([2, 0, 0, 2, 10, 0])
    expect(port.size).to eq([10, 10])
  end

  it "aligns to the start, middle or end of each axis" do
    box = { "width" => "40", "height" => "20", "viewBox" => "5 5 10 10" }

    expect(viewport(box.merge("preserveAspectRatio" => "xMinYMin")).matrix).to eq([2, 0, 0, 2, -10, -10])
    expect(viewport(box.merge("preserveAspectRatio" => "xMaxYMax meet")).matrix).to eq([2, 0, 0, 2, 10, -10])
    expect(viewport(box.merge("preserveAspectRatio" => "xMidYMax slice")).matrix).to eq([4, 0, 0, 4, -20, -40])
  end

  it "stretches with preserveAspectRatio none" do
    port = viewport({ "x" => "1", "width" => "40", "height" => "20", "viewBox" => "0 0 10 10",
                      "preserveAspectRatio" => "none" })

    expect(port.matrix).to eq([4, 0, 0, 2, 1, 0])
  end

  it "draws nothing for an empty viewport or viewBox" do
    expect(viewport({ "width" => "0", "height" => "10" })).not_to be_drawable
    expect(viewport({ "width" => "10", "height" => "10", "viewBox" => "0 0 0 10" })).not_to be_drawable
    expect(viewport({ "width" => "10", "height" => "10" })).to be_drawable
  end

  it "traces its rectangle for clipping" do
    bounds = Stationery::SVG::Bounds.new
    viewport({ "x" => "1", "y" => "2", "width" => "30", "height" => "40" }).trace(bounds)

    expect(bounds.box).to eq([1, 2, 30, 40])
  end
end
