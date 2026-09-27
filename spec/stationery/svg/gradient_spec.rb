# frozen_string_literal: true

RSpec.describe Stationery::SVG::Gradient do
  def gradients(markup) = described_class.collect(Stationery::SVG::Parser.parse("<svg>#{markup}</svg>"))

  let(:fixture) do
    root = Stationery::SVG::Parser.parse(File.read(File.expand_path("../../fixtures/svg/gradient.svg", __dir__)))
    described_class.collect(root)
  end

  it "collects linear and radial gradients by id, wherever they are, with their stops" do
    expect(fixture.keys).to contain_exactly("brand", "paint0_linear_12_4", "paint1_radial_12_4", "paint2_linear_12_4")
    expect(fixture["brand"].kind).to eq(:linear)
    expect(fixture["paint1_radial_12_4"].kind).to eq(:radial)
    expect(fixture["brand"].stops.map(&:deconstruct)).to eq([[0.0, "#6D28D9", 1.0], [0.5, "#DB2777", 1.0],
                                                             [1.0, "#F59E0B", 1.0]])
    expect(fixture["paint1_radial_12_4"].stops.last.opacity).to eq(0.2)
  end

  it "inherits stops and attributes through xlink:href and href, its own attributes winning" do
    chained = gradients(<<~SVG)["c"]
      <linearGradient id="a" x1="5" spreadMethod="pad"><stop offset="0" stop-color="red"/></linearGradient>
      <linearGradient id="b" xlink:href="#a" x1="7" gradientUnits="userSpaceOnUse"/>
      <radialGradient id="c" href="#b" x1="9"/>
    SVG

    expect(chained.kind).to eq(:radial)
    expect(chained.stops.map(&:color)).to eq(["red"])
    expect(chained.attributes).to include("x1" => "9", "gradientUnits" => "userSpaceOnUse", "spreadMethod" => "pad")
    expect(fixture["paint0_linear_12_4"].stops.size).to eq(3)
  end

  it "stops following an href cycle" do
    looped = gradients('<linearGradient id="a" href="#b"/><linearGradient id="b" href="#a"/>')

    expect(looped["a"].stops).to eq([])
  end

  it "reads offsets as fractions or percentages, clamped and never decreasing, and styled stop colours" do
    stops = gradients(<<~SVG)["g"].stops
      <linearGradient id="g"><stop offset="40%" style="stop-color: blue; stop-opacity: .5"/>
        <stop offset="0.2" stop-color="#123"/><stop offset="2"/></linearGradient>
    SVG

    expect(stops.map(&:deconstruct)).to eq([[0.4, "blue", 0.5], [0.4, "#123", 1.0], [1.0, "black", 1.0]])
  end

  it "places objectBoundingBox gradients in the shape's box and userSpaceOnUse ones by their transform" do
    boxed = gradients('<linearGradient id="g" gradientTransform="scale(2)"/>')["g"]
    user = gradients('<linearGradient id="g" gradientUnits="userSpaceOnUse" gradientTransform="scale(2)"/>')["g"]

    expect(boxed.matrix([10, 20, 30, 40])).to eq([60, 0, 0, 80, 10, 20])
    expect(user.matrix([10, 20, 30, 40])).to eq([2.0, 0, 0, 2.0, 0, 0])
  end

  it "reads linear coordinates with SVG defaults, percentages against the box or the viewport" do
    boxed = gradients('<linearGradient id="g" y2="50%"/>')["g"]
    user = gradients('<linearGradient id="g" gradientUnits="userSpaceOnUse" x1="10%" x2="40"/>')["g"]

    expect(boxed.coords([200, 100])).to eq([0.0, 0.0, 1.0, 0.5])
    expect(user.coords([200, 100])).to eq([20.0, 0.0, 40.0, 0.0])
  end

  it "reads radial coordinates as focus, zero radius, centre and radius" do
    centred = gradients('<radialGradient id="g"/>')["g"]
    focused = gradients('<radialGradient id="g" cx="10" cy="10" r="5" fx="8" gradientUnits="userSpaceOnUse"/>')["g"]

    expect(centred.coords([100, 100])).to eq([0.5, 0.5, 0, 0.5, 0.5, 0.5])
    expect(focused.coords([100, 100])).to eq([8.0, 10.0, 0, 10.0, 10.0, 5.0])
  end

  it "interpolates the colour at an offset, resolving named colours and currentColor" do
    gradient = gradients(<<~SVG)["g"]
      <linearGradient id="g"><stop offset="0.2" stop-color="black"/><stop offset="0.6" stop-color="currentColor"/>
      </linearGradient>
    SVG

    expect(gradient.color_at(0.4, "#FFFFFF")).to eq("#808080")
    expect(gradient.color_at(0, "#FFFFFF")).to eq("#000000")
    expect(gradient.color_at(1, "#FFFFFF")).to eq("#FFFFFF")
  end

  it "reports a spread it approximates" do
    expect(gradients('<linearGradient id="g" spreadMethod="reflect"/>')["g"].approximated_spread).to eq("reflect")
    expect(gradients('<radialGradient id="g" spreadMethod="pad"/>')["g"].approximated_spread).to be_nil
  end
end
