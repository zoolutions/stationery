# frozen_string_literal: true

# Floats across pages. The page is 300 × 200 with a 20 pt margin: 160 pt of
# content height, eleven lines of Open Sans at 10 pt.
RSpec.describe Stationery::Layout::Flow do
  let(:words) { Array.new(200) { |i| "word#{i}" }.join(" ") }
  let(:ascent) { open_sans_book.resolve(base_style).first.ascender(10) }

  def block(width, height, **) = Stationery::Layout::Box.new(flow, width:, height:, **)
  def floated(node, side = :left, **) = Stationery::Layout::Floated.new(node, side:, **)
  def black(width, height) = floated(block(width, height, background: "#000000"))

  def boxed(*children, break_inside: :auto, **)
    Stationery::Layout::Box.new(flow(*children), **).tap { |box| box.break_inside = break_inside }
  end

  # Per page, [x, top] of every text drawn, the top from the page's top edge.
  def pages_of(pdf)
    reader_for(pdf).pages.map do |page|
      page.runs.map { |run| [run.origin.x.round(2), (200 - run.origin.y - ascent).round(2)] }
    end
  end

  def floats_of(pdf)
    page_contents(pdf).map { |content| content.scan(/^[\d.]+ [\d.]+ [\d.]+ [\d.]+ re$/).size }
  end

  def nth_line(index) = (20 + (line_height * index)).round(2)

  it "moves a float that does not fit the rest of the page to the next, with what wraps beside it" do
    pdf, paginator = render_layout(flow(lines_of(9), black(80, 60), text_node("beside the float")))

    expect(floats_of(pdf)).to eq([0, 1])
    expect(pages_of(pdf)[0].size).to eq(9)
    expect(pages_of(pdf)[1]).to eq([[100.0, 20.0]])
    expect(paginator.warnings).to be_empty
  end

  it "keeps a float that fits on the page with the first lines beside it" do
    pdf, = render_layout(flow(lines_of(8), black(80, 40), text_node(words)))

    expect(floats_of(pdf).first(2)).to eq([1, 0])
    expect(pages_of(pdf)[0].last(3)).to eq([[100.0, nth_line(8)], [100.0, nth_line(9)], [100.0, nth_line(10)]])
  end

  it "wraps the lines a page break carries over at the full width: the float stayed behind" do
    pdf, = render_layout(flow(lines_of(8), black(80, 40), text_node(words)))
    second = reader_for(pdf).pages[1].runs.map(&:text)

    expect(pages_of(pdf)[1].map(&:first).uniq).to eq([20.0])
    expect(pages_of(pdf)[1].first).to eq([20.0, 20.0])
    expect(second.first.split.size).to be > reader_for(pdf).pages[0].runs.last.text.split.size
    expect(text_of(pdf).split.last(200)).to eq(words.split)
  end

  it "moves the float on when the text beside it cannot start on the page" do
    pdf, = render_layout(flow(spacer(125), black(80, 30), text_node(words, orphans: 3)))

    expect(floats_of(pdf).first(2)).to eq([0, 1])
    expect(pages_of(pdf)[0]).to be_empty
    expect(pages_of(pdf)[1].first).to eq([100.0, 20.0])
  end

  it "moves floats left last on a page with the child that moves on" do
    kept = Stationery::Layout::Box.new(flow(lines_of(4, prefix: "kept")))
    heading = text_node("Heading").tap { |node| node.keep_with_next = true }
    pdf, = render_layout(flow(lines_of(7), black(40, 20), heading, kept))

    expect(floats_of(pdf)).to eq([0, 1])
    expect(reader_for(pdf).pages[1].text).to include("Heading", "kept 1")
    expect(pages_of(pdf)[1].first).to eq([60.0, 20.0])
  end

  it "keeps a heading with the float and the text that follow it" do
    heading = text_node("Heading").tap { |node| node.keep_with_next = true }
    pdf, = render_layout(flow(spacer(100), heading, black(80, 60), text_node("beside")))

    expect(floats_of(pdf)).to eq([0, 1])
    expect(reader_for(pdf).pages[0].text).not_to include("Heading")
    expect(pages_of(pdf)[1]).to eq([[20.0, 20.0], [100.0, nth_line(1)]])
  end

  it "keeps a number of points of what follows with a heading beside a float" do
    heading = text_node("Heading").tap { |node| node.keep_with_next = 40 }
    pdf, = render_layout(flow(black(80, 20), spacer(125), heading, lines_of(6)))

    expect(reader_for(pdf).pages[0].text).not_to include("Heading")
    expect(floats_of(pdf)).to eq([1, 0])
  end

  it "honours orphans and widows beside a float, counting the lines as they are wrapped again" do
    text = text_node(words.split.first(40).join(" "), widows: 3)
    pdf, = render_layout(flow(lines_of(8), black(160, 40), text))
    second = reader_for(pdf).pages[1].runs

    expect(second.size).to be >= 3
    expect(pages_of(pdf)[1].map(&:first).uniq).to eq([20.0])
  end

  it "places a float that is first on a fresh page even when it is taller than the page" do
    pdf, paginator = render_layout(flow(black(80, 300), text_node("beside")))

    expect(page_count(pdf)).to eq(1)
    expect(pages_of(pdf)[0]).to eq([[100.0, 20.0]])
    expect(paginator.warnings.map(&:height)).to eq([300])
  end

  it "places the child after the floats on a fresh page as the first child there" do
    tall = boxed(lines_of(14), break_inside: :avoid)
    pdf, paginator = render_layout(flow(black(80, 20), tall))

    expect(page_count(pdf)).to eq(1)
    expect(floats_of(pdf)).to eq([1])
    expect(paginator.warnings.size).to eq(1)
  end

  it "pushes what follows the flow below a float taller than the text beside it, page after page" do
    inner = flow(black(80, 100), text_node("beside"))
    pdf, = render_layout(flow(inner, lines_of(6, prefix: "after")))

    expect(pages_of(pdf)[0].map(&:last).first(2)).to eq([20.0, 120.0])
    expect(page_count(pdf)).to eq(2)
  end

  it "clears the float at a page break" do
    pdf, = render_layout(flow(black(80, 100), text_node("beside"), Stationery::Layout::PageBreak.new,
                              text_node("next page")))

    expect(floats_of(pdf)).to eq([1, 0])
    expect(pages_of(pdf)).to eq([[[100.0, 20.0]], [[20.0, 20.0]]])
  end

  it "breaks at a page break that follows nothing but floats" do
    pdf, = render_layout(flow(black(80, 100), Stationery::Layout::PageBreak.new, text_node("next page")))

    expect(floats_of(pdf)).to eq([1, 0])
    expect(pages_of(pdf)[1]).to eq([[20.0, 20.0]])
  end

  it "drops a spacer at the break and keeps the floats above it" do
    pdf, = render_layout(flow(black(80, 100), text_node("beside"), spacer(200), text_node("next page")))

    expect(floats_of(pdf)).to eq([1, 0])
    expect(pages_of(pdf)).to eq([[[100.0, 20.0]], [[20.0, 20.0]]])
  end

  it "splits a nested flow beside a float, its text wrapped around the float" do
    nested = flow(text_node("first"), text_node(words))
    pdf, = render_layout(flow(black(80, 60), nested))

    expect(pages_of(pdf)[0].first(5).map(&:first).uniq).to eq([100.0])
    expect(pages_of(pdf)[0].last.first).to eq(20.0)
    expect(pages_of(pdf)[1].map(&:first).uniq).to eq([20.0])
    expect(text_of(pdf).split.drop(1)).to eq(words.split)
  end

  it "splits a box that is a block beside a float and continues it at the full width" do
    box = boxed(text_node(words), border: { width: 0 })
    pdf, = render_layout(flow(black(80, 60), box))

    expect(pages_of(pdf)[0].map(&:first).uniq).to eq([100.0])
    expect(pages_of(pdf)[1].map(&:first).uniq).to eq([20.0])
  end

  it "splits a box that holds a float, the float staying with the first part" do
    box = boxed(black(80, 60), text_node(words), padding: 5)
    pdf, = render_layout(flow(spacer(40), box))

    expect(floats_of(pdf).first(2)).to eq([1, 0])
    expect(pages_of(pdf)[0].first).to eq([105.0, 65.0])
    expect(pages_of(pdf)[1].first).to eq([25.0, 20.0])
  end

  it "moves a box that holds a float too tall for the rest of the page to the next page" do
    box = boxed(black(80, 60), text_node("beside"))
    pdf, = render_layout(flow(spacer(120), box))

    expect(floats_of(pdf)).to eq([0, 1])
    expect(pages_of(pdf)[1]).to eq([[100.0, 20.0]])
  end

  it "splits a flow that lies beside a float of its parent without floats of its own" do
    nested = flow(text_node(words))
    head, tail = flow(floated(block(80, 60)), nested).split(260, 160, fresh: true)

    expect(head.children.last.children.first.send(:paragraph, 260).lines.first.offset).to eq(80)
    expect(tail.children.first.children.first.send(:paragraph, 260).lines.first.offset).to eq(0)
  end

  it "keeps a heading with floats that end the flow, or that a page break follows" do
    heading = -> { text_node("Heading").tap { |node| node.keep_with_next = true } }
    fits, = render_layout(flow(spacer(100), heading.call, black(80, 40)))
    moves, = render_layout(flow(spacer(100), heading.call, black(80, 60)))
    broken, = render_layout(flow(spacer(100), heading.call, black(80, 40), Stationery::Layout::PageBreak.new,
                                 text_node("next")))

    expect(floats_of(fits)).to eq([1])
    expect(floats_of(moves)).to eq([0, 1])
    expect(reader_for(moves).pages[1].text).to include("Heading")
    expect(floats_of(broken)).to eq([1, 0])
    expect(inspect_pdf(broken).page_texts).to eq(%w[Heading next])
  end

  it "wraps the text of a box that was a block beside a float again where the box continues" do
    box = boxed(text_node(words, align: :right), border: { width: 0 })
    pdf, = render_layout(flow(black(80, 60), box))
    ends = reader_for(pdf).pages.map { |page| page.runs.map { |run| (run.x + run.width).round }.uniq }

    expect(pages_of(pdf)[0].map(&:first).min).to be >= 100
    expect(ends.first(2)).to eq([[280], [280]])
    expect(reader_for(pdf).pages[1].runs.first.text.split.size)
      .to be > reader_for(pdf).pages[0].runs.first.text.split.size
    expect(text_of(pdf).split).to eq(words.split)
  end

  it "wraps the rest of a list item whose body is a block beside a float again" do
    body = boxed(text_node(words), border: { width: 0 })
    item = Stationery::Layout::ListItem.new(text_node("1."), body, indent: 20, marker_gap: 4)
    pdf, = render_layout(flow(black(80, 60), item))

    expect(pages_of(pdf)[0].map(&:first).uniq).to eq([100.0, 120.0])
    expect(pages_of(pdf)[1].map(&:first).uniq).to eq([40.0])
    expect(reader_for(pdf).pages[1].runs.first.text.split.size)
      .to be > reader_for(pdf).pages[0].runs.last.text.split.size
  end
end
