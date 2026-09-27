# frozen_string_literal: true

RSpec.describe Stationery::SVG::Document, "#draw" do
  let(:resources) { Stationery::Resources.new }
  let(:page) { Stationery::Page.new(size: [200, 200]) }
  let(:canvas) { Stationery::Canvas.new(page, resources) }
  let(:linear) do
    '<defs><linearGradient id="g"><stop stop-color="red"/><stop offset="1" stop-color="blue"/></linearGradient></defs>'
  end

  def draw(markup, size: 100)
    svg = described_class.parse(%(<svg viewBox="0 0 #{size} #{size}">#{markup}</svg>))
    svg.draw(canvas, x: 0, y: 0, width: 100, height: 100)
    svg
  end

  def shadings = resources.build(Stationery::PDF::Writer.new)[:Shading]

  it "fills a shape with a gradient: clipped to the shape, mapped onto its bounding box, then shaded" do
    draw("#{linear}<rect x=\"10\" width=\"20\" height=\"10\" fill=\"url(#g)\"/>")

    expect(page.content).to include("10 200 m\n30 200 l\n30 190 l\n10 190 l\nh\nW n\n20 0 0 -10 10 200 cm\n/Sh1 sh")
    expect(page.resource_names[:Shading]).to eq([:Sh1])
    expect(shadings.keys).to eq([:Sh1])
  end

  it "fills through style attributes, clips by the fill rule and keeps the stroke solid on top" do
    draw("#{linear}<path d=\"M0 0 L10 0 L10 10 Z\" fill-rule=\"evenodd\" style=\"fill: url(#g)\" stroke=\"#000\"/>")

    expect(page.content).to include("W* n", "/Sh1 sh", "0 0 0 RG")
    expect(page.content.index("/Sh1 sh")).to be < page.content.index("0 0 0 RG")
  end

  it "draws radial gradients in user space through their transform, scaled with the drawing" do
    draw('<radialGradient id="r" gradientUnits="userSpaceOnUse" gradientTransform="translate(5 5)" r="5">' \
         '<stop stop-color="#fff"/><stop offset="1" stop-color="#000"/></radialGradient>' \
         '<circle cx="5" cy="5" r="5" fill="url(#r)"/>', size: 10)

    expect(page.content).to include("10 0 0 -10 50 150 cm")
    expect(shadings.values).to all(be_a(Stationery::PDF::Reference))
  end

  it "paints a gradient stroke in the gradient's middle colour" do
    svg = draw("#{linear}<line x2=\"10\" stroke=\"url(#g)\"/>")

    expect(page.content).to include("0.502 0 0.502 RG")
    expect(page.content).not_to include(" sh")
    expect(svg.unsupported).to eq([])
  end

  it "applies the first stop's opacity with the shape's own" do
    draw('<linearGradient id="g"><stop stop-color="#fff" stop-opacity="0.5"/></linearGradient>' \
         '<linearGradient id="h"><stop stop-opacity="0.5"/><stop offset="1"/></linearGradient>' \
         '<rect width="10" height="10" fill="url(#g)"/><rect width="10" height="10" fill="url(#h)" opacity="0.5"/>')

    expect(page.content).to include("/GS1 gs\n1 1 1 rg", "/GS2 gs")
    expect(resources.build(Stationery::PDF::Writer.new)[:ExtGState].keys).to eq(%i[GS1 GS2])
  end

  it "skips gradient fills on shapes with an empty bounding box and gradients without stops" do
    draw('<linearGradient id="e"/>' \
         "#{linear}<line x2=\"10\" fill=\"url(#g)\" stroke=\"#000\"/><rect width=\"5\" height=\"5\" fill=\"url(#e)\"/>")

    expect(page.content).not_to include(" sh", "\nf\n")
    expect(page.content).to include("0 0 0 RG")
  end

  it "paints the fallback colour of a missing gradient, or nothing, and reports the reference" do
    svg = draw('<rect width="5" height="5" fill="url(#missing) #FF0000"/><rect width="5" height="5" ' \
               'fill="url(\'#gone\')"/><g><circle r="1" fill="none" stroke="url(#gone)"/></g>')

    expect(page.content.scan("\nf\n").size).to eq(1)
    expect(page.content).to include("1 0 0 rg")
    expect(svg.unsupported).to eq(%w[url(#gone) url(#missing)])
  end

  it "approximates reflect and repeat spreads with pad and reports them" do
    svg = draw('<linearGradient id="g" spreadMethod="repeat"><stop/><stop offset="1"/></linearGradient>' \
               '<rect width="5" height="5" fill="url(#g)"/>')

    expect(page.content).to include("/Sh1 sh")
    expect(svg.unsupported).to eq(["linearGradient spreadMethod=repeat"])
  end

  it "renders the Figma-style fixture into a PDF with axial and radial shadings" do
    source = File.read(File.expand_path("../../fixtures/svg/gradient.svg", __dir__))
    document = SpecDocument.build { svg source, width: 120 }
    pdf = document.to_pdf

    expect(pdf).to include("/ShadingType 2", "/ShadingType 3", "/Bounds [0.5]", "/Extend [true true]")
    expect(pdf).to match(%r{/Shading <</Sh1 \d+ 0 R /Sh2 \d+ 0 R /Sh3 \d+ 0 R>>})
    expect(page_contents(pdf).first.scan(/ sh$/).size).to eq(3)
    expect(document.warnings.to_a).to eq([])
  end
end
