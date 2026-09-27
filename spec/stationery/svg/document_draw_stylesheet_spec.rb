# frozen_string_literal: true

RSpec.describe Stationery::SVG::Document, "#draw" do
  let(:resources) { Stationery::Resources.new }
  let(:page) { Stationery::Page.new(size: [200, 200]) }
  let(:canvas) { Stationery::Canvas.new(page, resources) }

  def draw(source)
    svg = described_class.parse(source)
    svg.draw(canvas, x: 0, y: 0, width: 100, height: 100)
    svg
  end

  it "styles an Illustrator export by its classes and ids, skipping display:none" do
    svg = draw(File.read(File.expand_path("../../fixtures/svg/styled.svg", __dir__)))
    ops = page.content

    expect(ops).to include("0.0706 0.2039 0.3373 rg\n10 190 m", "0 1 0 rg", "1 0 0 RG\n4 w\n1 J", "/Sh1 sh")
    expect(ops).not_to include("0 200 m\n100 200 l")
    expect(ops.scan(" f\n").size + ops.scan("\nf\n").size).to eq(2)
    expect(ops).to include("12 Tf")
    expect(svg.unsupported).to eq([])
  end

  it "reads style elements in CDATA and lets inline styles beat the sheet, and the sheet attributes" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 100"><style><![CDATA[ .a { fill: #FF0000 } rect > .x { fill: #00FF00 } ]]></style>
        <rect class="a" fill="#00FF00" width="1" height="1"/><rect class="a" style="fill: #0000FF" width="1" height="1"/>
      </svg>
    SVG

    expect(page.content).to include("1 0 0 rg", "0 0 1 rg")
    expect(page.content).not_to include("0 1 0 rg")
  end

  it "skips hidden elements, a visible child of a hidden group drawing again" do
    draw(<<~SVG)
      <svg viewBox="0 0 100 100"><style>.h { visibility: hidden } .v { visibility: visible }</style>
        <rect class="h" fill="#FF0000" width="1" height="1"/>
        <g class="h"><rect fill="#FF0000" width="1" height="1"/><rect class="v" fill="#0000FF" width="1" height="1"/></g>
        <rect display="none" fill="#FF0000" width="1" height="1"/>
      </svg>
    SVG

    expect(page.content).to include("0 0 1 rg")
    expect(page.content).not_to include("1 0 0 rg")
  end

  it "styles gradient stops and text from the sheet" do
    source = <<~SVG
      <svg viewBox="0 0 100 100"><style>
        stop { stop-color: #FF0000 } .end { stop-color: #0000FF } text { font-size: 20px; fill: #00FF00 }
      </style><linearGradient id="g"><stop/><stop class="end" offset="1"/></linearGradient>
        <line x2="10" stroke="url(#g)"/><text y="50">Hi</text></svg>
    SVG
    draw(source)

    expect(page.content).to include("0.502 0 0.502 RG", "0 1 0 rg", "20 Tf")
  end

  it "reports selectors it ignores once, not the style element" do
    svg = described_class.parse(<<~SVG)
      <svg viewBox="0 0 10 10"><style>g rect { fill: red } .a .b { fill: blue } .c { fill: green }</style>
        <style>svg > rect { fill: red }</style></svg>
    SVG

    expect(svg.unsupported).to eq(["style selectors: g rect, .a .b, svg > rect"])
  end
end
