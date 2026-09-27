# frozen_string_literal: true

RSpec.describe Stationery::SVG::Shading do
  def gradient(markup) = Stationery::SVG::Gradient.collect(Stationery::SVG::Parser.parse("<svg>#{markup}</svg>"))["g"]

  it "writes two stops as one exponential function over an axial shading" do
    linear = gradient('<linearGradient id="g"><stop stop-color="red"/><stop offset="1" stop-color="blue"/>' \
                      "</linearGradient>")

    expect(described_class.dictionary(linear, [0, 0, 1, 0], "#000000")).to eq(
      ShadingType: 2, ColorSpace: :DeviceRGB, Coords: [0, 0, 1, 0], Extend: [true, true],
      Function: { FunctionType: 2, Domain: [0, 1], C0: [1.0, 0.0, 0.0], C1: [0.0, 0.0, 1.0], N: 1 }
    )
  end

  it "stitches more stops, padding the ends so colours hold before the first and after the last" do
    linear = gradient(<<~SVG)
      <linearGradient id="g"><stop offset="0.2" stop-color="red"/><stop offset="0.5" stop-color="#00FF00"/>
        <stop offset="0.8" stop-color="blue"/></linearGradient>
    SVG
    function = described_class.dictionary(linear, [0, 0, 1, 0], "#000000")[:Function]

    expect(function).to include(FunctionType: 3, Domain: [0, 1], Bounds: [0.2, 0.5, 0.8], Encode: [0, 1] * 4)
    expect(function[:Functions].map { |f| [f[:C0], f[:C1]] }).to eq(
      [[[1.0, 0.0, 0.0], [1.0, 0.0, 0.0]], [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0]],
       [[0.0, 1.0, 0.0], [0.0, 0.0, 1.0]], [[0.0, 0.0, 1.0], [0.0, 0.0, 1.0]]]
    )
  end

  it "writes radial gradients as radial shadings" do
    radial = gradient('<radialGradient id="g"><stop stop-color="red"/><stop offset="1" stop-color="red"/>' \
                      "</radialGradient>")

    expect(described_class.dictionary(radial, [0.5, 0.5, 0, 0.5, 0.5, 0.5], "#000000"))
      .to include(ShadingType: 3, Coords: [0.5, 0.5, 0, 0.5, 0.5, 0.5])
  end
end
