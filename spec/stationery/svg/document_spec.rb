# frozen_string_literal: true

RSpec.describe Stationery::SVG::Document do
  let(:check) { File.read(File.expand_path("../../fixtures/svg/check.svg", __dir__)) }
  let(:resources) { Stationery::Resources.new }
  let(:page) { Stationery::Page.new(size: [200, 200]) }
  let(:canvas) { Stationery::Canvas.new(page, resources) }

  it "reads the viewBox and the root size" do
    svg = described_class.parse(check)

    expect(svg.view_box).to eq([0, 0, 256, 256])
    expect(svg.aspect).to eq(1.0)
  end

  it "scales the viewBox into the target box and the stroke width with it" do
    described_class.parse(check).draw(canvas, x: 10, y: 20, width: 64, height: 64, color: "#345644")

    ops = page.content
    expect(ops).to include("0.2039 0.3373 0.2667 RG", "4 w", "1 J", "1 j")
    expect(ops).to include("20 144 m") # 40*0.25+10, 200 - (144*0.25+20)
    expect(ops).not_to include(" f\n") # fill="none"
  end

  it "draws rects with rounded corners, circles, lines, polylines and paths" do
    calendar = File.read(File.expand_path("../../fixtures/svg/calendar.svg", __dir__))
    pin = File.read(File.expand_path("../../fixtures/svg/map-pin.svg", __dir__))
    described_class.parse(calendar).draw(canvas, x: 0, y: 0, width: 32, height: 32)
    described_class.parse(pin).draw(canvas, x: 0, y: 0, width: 32, height: 32)

    expect(page.content.scan("\nS\n").size).to eq(8)
    expect(page.content.scan(" c\n").size).to be > 8
  end

  it "fills shapes black by default and honours fill, stroke, opacity and inherited group styles" do
    source = <<~SVG
      <svg viewBox="0 0 10 10"><!-- comment --><g fill="#FF0000" stroke="blue" stroke-width="2">
        <rect width="10" height="10" style="fill-opacity: 0.5"/><circle cx="5" cy="5" r="2" fill="none"/>
      </g><polygon points="0,0 10,0 5,5"/></svg>
    SVG
    described_class.parse(source).draw(canvas, x: 0, y: 0, width: 10, height: 10)
    ops = page.content

    expect(ops).to include("1 0 0 rg", "0 0 1 RG", "B\n")
    expect(ops).to include("/GS1 gs")
    expect(ops).to include("0 0 0 rg")
  end

  it "applies transform attributes" do
    source = '<svg viewBox="0 0 10 10"><line x1="0" y1="0" x2="1" y2="0" stroke="#000" ' \
             'transform="translate(5 5) scale(2)"/></svg>'
    described_class.parse(source).draw(canvas, x: 0, y: 0, width: 10, height: 10)

    expect(page.content).to include("5 195 m\n7 195 l")
  end

  it "keeps the aspect ratio inside a box of a different shape, centred" do
    wide = '<svg viewBox="0 0 20 10"><line x1="0" y1="0" x2="20" y2="0" stroke="#000"/></svg>'
    described_class.parse(wide).draw(canvas, x: 0, y: 0, width: 10, height: 10)

    expect(page.content).to include("0 197.5 m\n10 197.5 l")
  end

  it "lists the elements it cannot draw, ignoring descriptive ones" do
    source = <<~SVG
      <svg viewBox="0 0 10 10"><title>t</title><desc>d</desc><metadata/><defs><path d="M0 0"/></defs>
        <g><text>Hi</text><image href="a.png"/><svg/></g><text>again</text><rect width="1" height="1"/>
        <mask id="m"/><pattern id="p"/><filter id="f"/></svg>
    SVG

    expect(described_class.parse(source).unsupported).to eq(%w[filter image mask pattern])
    expect(described_class.parse(check).unsupported).to eq([])
  end

  it "refuses documents it cannot read" do
    expect { described_class.parse("<html></html>") }.to raise_error(Stationery::SVG::Error, /svg/)
  end
end
