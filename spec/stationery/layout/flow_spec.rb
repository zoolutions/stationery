# frozen_string_literal: true

RSpec.describe Stationery::Layout::Flow do
  it "stacks children and measures their total height, with an optional gap" do
    stack = flow(text_node("a"), spacer(10), text_node("b"))
    gapped = flow(text_node("a"), text_node("b"), gap: 6)

    expect(stack.measure(200)).to be_within(0.001).of((line_height * 2) + 10)
    expect(gapped.measure(200)).to be_within(0.001).of((line_height * 2) + 6)
  end

  it "paints children top to bottom" do
    pdf, = render_layout(flow(text_node("first"), spacer(20), text_node("second")))
    (x1, y1), (x2, y2) = positions_of(pdf)

    expect(x1).to eq(x2)
    expect(y1 - y2).to be_within(0.01).of(line_height + 20)
  end

  it "continues a splittable child on the next page by whole lines" do
    pdf, paginator = render_layout(lines_of(30))

    expect(page_count(pdf)).to be > 1
    expect(strings_of(pdf)).to eq(Array.new(30) { |i| "line #{i + 1}" })
    expect(paginator.warnings).to be_empty
  end

  it "moves an unsplittable child to the next page whole" do
    box = Stationery::Layout::Box.new(flow(lines_of(3, prefix: "boxed")), padding: 4)
    pdf, = render_layout(flow(spacer(120), box))
    reader = reader_for(pdf)

    expect(reader.page_count).to eq(2)
    expect(reader.pages[1].text).to include("boxed 1", "boxed 3")
  end

  it "keeps a splittable child together when it asks to avoid breaking inside" do
    pdf, = render_layout(flow(spacer(120), lines_of(4, prefix: "kept").tap { |t| t.break_inside = :avoid }))

    expect(reader_for(pdf).pages[1].text).to include("kept 1", "kept 4")
  end

  it "keeps a child with the next one when asked" do
    heading = text_node("Heading").tap { |t| t.keep_with_next = true }
    big = Stationery::Layout::Box.new(flow(lines_of(5, prefix: "body")))
    pdf, = render_layout(flow(spacer(110), heading, big))

    expect(reader_for(pdf).pages[1].text).to include("Heading", "body 1")
    expect(reader_for(pdf).pages[0].text).not_to include("Heading")
  end

  it "drops a spacer that falls on a page break" do
    pdf, = render_layout(flow(lines_of(10), spacer(500), text_node("after")))

    expect(page_count(pdf)).to eq(2)
    expect(reader_for(pdf).pages[1].text.strip).to start_with("after")
  end

  it "starts a new page at a page break, ignoring one at the very top" do
    pdf, = render_layout(flow(Stationery::Layout::PageBreak.new, text_node("one"), Stationery::Layout::PageBreak.new,
                              text_node("two")))

    expect(page_count(pdf)).to eq(2)
  end

  it "places a child taller than a page anyway and records a warning" do
    tall = Stationery::Layout::Box.new(flow(lines_of(40)))
    pdf, paginator = render_layout(flow(tall, text_node("after")))

    expect(page_count(pdf)).to eq(2)
    expect(paginator.warnings.first).to be_a(Stationery::Layout::Overflow)
    expect(paginator.warnings.first.page).to eq(1)
  end

  it "aligns fixed-width children" do
    image = Stationery::Layout::Image.new(image_path("rgb.jpg"), width: 40)
    pdf, = render_layout(flow(image, align: :right))

    expect(page_contents(pdf).first).to include("40 0 0 30 240 150 cm")
  end
end
