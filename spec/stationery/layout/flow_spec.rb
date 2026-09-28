# frozen_string_literal: true

RSpec.describe Stationery::Layout::Flow do
  it "stacks children and measures their total height, with an optional gap" do
    stack = flow(text_node("a"), spacer(10), text_node("b"))
    gapped = flow(text_node("a"), text_node("b"), gap: 6)

    expect(stack.measure(200)).to be_within(0.001).of((line_height * 2) + 10)
    expect(gapped.measure(200)).to be_within(0.001).of((line_height * 2) + 6)
  end

  it "measures its children once per width and again after a child is added" do
    child = spacer(10)
    allow(child).to receive(:measure).and_call_original
    stack = flow(child)
    2.times { stack.measure(200) }
    stack.measure(100)
    stack << spacer(5)

    expect(stack.measure(200)).to eq(15)
    expect(child).to have_received(:measure).exactly(3).times
  end

  it "cuts the page at a page break inside a nested flow, even when the flow would fit" do
    nested = flow(text_node("one"), Stationery::Layout::PageBreak.new, text_node("two"), gap: 4)
    deep = flow(flow(Stationery::Layout::PageBreak.new, text_node("three")))
    pdf, = render_layout(flow(text_node("top"), nested, text_node("after"), deep, text_node("last")))

    expect(inspect_pdf(pdf).page_texts).to eq(%W[top\none two\nafter three\nlast])
    expect(flow(text_node("a")).breaks?).to be(false)
    expect(flow(flow(spacer(1), Stationery::Layout::PageBreak.new)).breaks?).to be(true)
  end

  it "knows about a page break added after it was asked" do
    stack = flow(text_node("a"))
    stack.breaks?
    stack << Stationery::Layout::PageBreak.new

    expect(stack.breaks?).to be(true)
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
    tall = Stationery::Layout::Box.new(flow(lines_of(40))).tap { |b| b.break_inside = :avoid }
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

  it "keeps a child with at least a given amount of what follows" do
    heading = text_node("Heading").tap { |t| t.keep_with_next = 60 }
    pdf, = render_layout(flow(spacer(100), heading, lines_of(10, prefix: "body")))
    first, second = reader_for(pdf).pages

    expect(first.text).not_to include("Heading")
    expect(second.text).to include("Heading", "body 1")
  end

  it "counts every following sibling toward a numeric keep_with_next" do
    heading = text_node("Heading").tap { |t| t.keep_with_next = 50 }
    pdf, = render_layout(flow(spacer(80), heading, text_node("one"), text_node("two"), text_node("three"),
                              text_node("four")))

    expect(reader_for(pdf).pages.first.text).to include("Heading", "one")
  end

  it "asks a long table for no more of its height than the page or a keep_with_next needs" do
    rows = Array.new(60) { |index| ["row #{index}"] }
    table = Stationery::Layout::Table.new(rows, context: ctx)
    marked = Stationery::Layout::Mark.new(Stationery::Layout::Table.new(rows, context: ctx), ["rows"])
    heading = text_node("Heading").tap { |t| t.keep_with_next = 40 }
    late = [table, marked.child].map { |node| node.cell(59, 0) }
    late.each { |cell| allow(cell).to receive(:measure).and_call_original }

    head, tail = flow(heading, table).split(260, 160)
    marked_head, = flow(marked).split(260, 160)

    expect(head.children.map(&:class)).to eq([Stationery::Layout::Text, Stationery::Layout::Table])
    expect([head.children.last, marked_head.children.first.child].map(&:row_count)).to eq([6, 6])
    expect(late).to all(have_received(:measure).exactly(0).times)
    expect(tail.measure(260)).to be > 160
    expect(late.first).to have_received(:measure).once
  end

  it "keeps a numeric keep_with_next satisfied when enough follows on the same page" do
    heading = text_node("Heading").tap { |t| t.keep_with_next = 30 }
    pdf, = render_layout(flow(spacer(60), heading, lines_of(10, prefix: "body")))

    expect(reader_for(pdf).pages.first.text).to include("Heading", "body 1", "body 2")
  end

  it "splits a nested group whose trailing spacer lands on the page break" do
    group = flow(lines_of(10, prefix: "grouped"), spacer(40))
    pdf, = render_layout(flow(spacer(20), group, text_node("after")))

    expect(page_count(pdf)).to eq(2)
    expect(reader_for(pdf).pages[1].text).to include("after")
  end

  it "moves a default box below other content to a fresh page before splitting it" do
    tall = Stationery::Layout::Box.new(flow(lines_of(20)))
    pdf, paginator = render_layout(flow(text_node("above"), tall))
    pages = reader_for(pdf).pages

    expect(pages.size).to eq(3)
    expect(pages[0].text.strip).to eq("above")
    expect(pages[1].text).to include("line 1")
    expect(paginator.warnings).to be_empty
  end

  it "keeps a child with a next one that avoids breaking inside and moves" do
    heading = text_node("Heading").tap { |t| t.keep_with_next = true }
    kept = lines_of(5, prefix: "kept").tap { |t| t.break_inside = :avoid }
    pdf, = render_layout(flow(spacer(100), heading, kept))

    expect(reader_for(pdf).pages[1].text).to include("Heading", "kept 1")
  end

  describe "a fixed-width child" do
    let(:narrow) { Stationery::Layout::Box.new(flow(text_node("word " * 20)), width: 100) }

    it "measures at its own width" do
      expect(narrow.measure(100)).to be > narrow.measure(260)
      expect(flow(narrow).measure(260)).to be_within(0.001).of(narrow.measure(100))
    end

    it "advances the cursor by its height at its own width" do
      pdf, = render_layout(flow(narrow, text_node("after")))
      positions = positions_of(pdf)

      expect(positions.first[1] - positions.last[1]).to be_within(0.5).of(narrow.measure(100))
    end

    it "moves to the next page when it only fits at the flow's width" do
      pdf, paginator = render_layout(flow(spacer(100), narrow))

      expect(page_count(pdf)).to eq(2)
      expect(reader_for(pdf).pages[1].text).to include("word")
      expect(paginator.warnings).to be_empty
    end

    it "counts toward a numeric keep_with_next at its own width" do
      heading = text_node("Heading").tap { |t| t.keep_with_next = 25 }
      short = Stationery::Layout::Box.new(flow(text_node("word " * 6)), width: 100)
      pdf, = render_layout(flow(spacer(126), heading, short))

      expect(reader_for(pdf).pages[1].text).to include("Heading", "word")
    end
  end

  describe "fresh: on nested splits" do
    let(:inner) { flow(lines_of(30, prefix: "inner")) }

    before { allow(inner).to receive(:split).and_call_original }

    it "tells a child at the top of a fresh page that it is fresh" do
      render_layout(flow(inner))

      expect(inner).to have_received(:split).with(260, 160, fresh: true)
    end

    it "tells a child below placed content that it is not fresh" do
      render_layout(flow(text_node("above"), inner))

      expect(inner).to have_received(:split).with(260, a_value < 160, fresh: false)
    end
  end

  describe "orphans and widows across pages" do
    # A 300×200 page with a 20pt margin holds 160pt of 10pt Open Sans lines.
    def pages_of(root) = inspect_pdf(render_layout(root).first).page_texts.map { |t| t.scan(/[a-z]+ \d+/).size }
    let(:per_page) { (160 / line_height).floor }

    it "moves a paragraph that would leave too few lines behind" do
      root = flow(lines_of(per_page - 2, prefix: "a"), lines_of(6, prefix: "b", orphans: 3))

      expect(pages_of(root)).to eq([per_page - 2, 6])
    end

    it "carries extra lines so the widows are met" do
      root = flow(lines_of(per_page - 4, prefix: "a"), lines_of(6, prefix: "b", widows: 3))

      expect(pages_of(root)).to eq([per_page - 1, 3])
    end

    it "splits a long paragraph that starts a page, honouring the widows only" do
      root = flow(lines_of(per_page + 7, orphans: 5, widows: 5))

      expect(pages_of(root)).to eq([per_page, 7])
    end

    it "breaks anywhere at the defaults" do
      root = flow(lines_of(per_page - 2, prefix: "a"), lines_of(6, prefix: "b"))

      expect(pages_of(root)).to eq([per_page, 4])
    end
  end
end
