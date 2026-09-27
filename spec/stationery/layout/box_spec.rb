# frozen_string_literal: true

RSpec.describe Stationery::Layout::Box do
  def box(*children, **) = described_class.new(flow(*children), **)

  it "adds padding and border to its content height" do
    expect(box(text_node("x"), padding: [4, 0, 6, 0]).measure(200)).to be_within(0.001).of(line_height + 10)
    expect(box(text_node("x"), border: { width: 2 }).measure(200)).to be_within(0.001).of(line_height + 4)
  end

  it "uses a fixed height and width when given" do
    fixed = box(text_node("x"), width: 100, height: 50)

    expect(fixed.measure(300)).to eq(50)
    expect(fixed.fixed_width(300)).to eq(100)
    expect(box(width: 0.5).fixed_width(300)).to eq(150)
  end

  it "paints its background before its content, rounded when it has a radius" do
    pdf, = render_layout(box(text_node("inside"), background: "#FF0000", radius: 6, padding: 10))
    content = page_contents(pdf).first

    expect(content.index("1 0 0 rg")).to be < content.index("BT")
    expect(content.scan(" c\n").size).to eq(4)
  end

  it "draws only the requested border sides" do
    pdf, = render_layout(box(text_node("x"), border: { width: 1, color: "#00FF00", sides: %i[top bottom] }))

    expect(page_contents(pdf).first.scan(" l\nS").size).to eq(2)
  end

  it "offsets its content by padding" do
    pdf, = render_layout(box(text_node("x"), padding: [10, 0, 0, 15]))
    x, = positions_of(pdf).first

    expect(x).to be_within(0.01).of(20 + 15)
  end

  it "truncates or shrinks text to a fixed height" do
    long = Array.new(60) { "word" }.join(" ")
    truncated, = render_layout(box(text_node(long), height: 30, overflow: :truncate))
    shrunk, = render_layout(box(text_node(long), height: 30, overflow: :shrink_to_fit))

    expect(text_of(truncated).split.size).to be < 60
    expect(text_of(shrunk).split.size).to eq(60)
  end

  it "links its whole area when given a link" do
    pdf, = render_layout(box(text_node("Apply"), padding: [6, 30], link: "https://example.com/apply"))
    x1, _y1, x2, = link_rects(pdf).first

    expect(pdf).to include("/URI (https://example.com/apply)")
    expect([x1, x2]).to eq([20, 280])
  end

  it "paints its background beyond its own edges by the outset, leaving content in place" do
    pdf, = render_layout(box(text_node("band"), background: "#EEEEEE", outset: [0, 20, 0, 20]))

    expect(page_contents(pdf).first).to include("0 ")
    expect(page_contents(pdf).first).to match(/
0 [\d.]+ 300 [\d.]+ re\nf/)
    expect(positions_of(pdf).first.first).to eq(20)
  end
end
