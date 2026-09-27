# frozen_string_literal: true

RSpec.describe Stationery::SVG::Text do
  # 100x50 viewBox drawn 200 wide at the page's top-left margin (20, 20): scale 2.
  def render(body, attributes: "")
    markup = %(<svg viewBox="0 0 100 50" #{attributes}>#{body}</svg>)
    document = SpecDocument.build { svg markup, width: 200 }
    [document.to_pdf, document]
  end

  def width_of(text, size, face = "OpenSans-Regular.ttf")
    Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(font_path(face))).width_of(text, size)
  end

  it "draws text at its scaled position and size, in the document's default family" do
    pdf, document = render('<text x="10" y="20" font-size="10" fill="#FF0000">Hi</text>')

    expect(positions_of(pdf)).to eq([[40, 140]])
    expect(page_contents(pdf).first).to include("20 Tf", "1 0 0 rg")
    expect(pdf).to include("+OpenSans")
    expect(document.warnings.to_a).to eq([])
  end

  it "anchors text at its middle or end by its measured width" do
    pdf, = render('<text x="50" y="10" font-size="10" text-anchor="middle">Hi</text>' \
                  '<text x="50" y="30" font-size="10" text-anchor="end">Hi</text>')
    (middle,), (right,) = positions_of(pdf)

    expect(middle).to be_within(0.01).of(20 + ((50 - (width_of("Hi", 10) / 2)) * 2))
    expect(right).to be_within(0.01).of(20 + ((50 - width_of("Hi", 10)) * 2))
  end

  it "positions tspans relative with dx/dy and absolute with x/y, inheriting the style" do
    pdf, = render('<text x="0" y="10" font-size="10">A<tspan dx="5" dy="1">B</tspan>' \
                  '<tspan x="30" y="40">C</tspan></text>')
    a, b, c = positions_of(pdf)

    expect(a).to eq([20, 160])
    expect(b[0]).to be_within(0.01).of(20 + ((width_of("A", 10) + 5) * 2))
    expect(b[1]).to eq(158)
    expect(c).to eq([80, 100])
    expect(page_contents(pdf).first.scan("20 Tf").size).to eq(3)
  end

  it "resolves bold and italic faces and falls back from unknown families without a warning" do
    pdf, document = render('<text y="10" font-family="\'Nope\', serif" font-weight="700">Bold</text>' \
                           '<text y="30" style="font-style: italic; font-family: Nope">Slanted</text>')

    expect(pdf).to include("+OpenSans-Bold", "+OpenSans-Italic")
    expect(document.warnings.to_a).to eq([])
  end

  it "uses the first family of the list the book knows: registered, bundled or installed" do
    pdf, = render('<text y="10" font-family="Missing, Inter, sans-serif">Inter</text>')

    expect(pdf).to include("+Inter")
  end

  it "keeps text extractable, whitespace collapsed across tspans" do
    pdf, = render(%(<text y="10">\n  Hello\n  <tspan font-weight="bold"> world </tspan>  </text>))

    expect(text_of(pdf)).to eq("Hello world")
  end

  it "paints the middle colour of a gradient fill, skips unfilled text and applies opacity" do
    pdf, = render('<linearGradient id="g"><stop stop-color="#000"/><stop offset="1" stop-color="#fff"/>' \
                  '</linearGradient><text y="10" fill="url(#g)" opacity="0.5">Grey</text>' \
                  '<text y="20" fill="none">Hidden</text>')

    expect(page_contents(pdf).first).to include("/GS1 gs", "0.502 0.502 0.502 rg")
    expect(text_of(pdf)).to eq("Grey")
  end

  it "moves transformed text's origin through the matrix and scales its size uniformly" do
    pdf, = render('<text x="10" y="0" font-size="10" transform="translate(5 10) rotate(90) scale(2)">R</text>')

    expect(positions_of(pdf)).to eq([[30, 120]])
    expect(page_contents(pdf).first).to include("40 Tf")
  end

  it "draws with the bundled default family when no font book is given" do
    page = Stationery::Page.new(size: [100, 100])
    canvas = Stationery::Canvas.new(page, Stationery::Resources.new)
    Stationery::SVG::Document.parse('<svg viewBox="0 0 10 10"><text y="5">x</text></svg>')
                             .draw(canvas, x: 0, y: 0, width: 10, height: 10)

    expect(page.content).to include("BT", "16 Tf")
  end
end
