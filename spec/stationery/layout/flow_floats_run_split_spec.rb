# frozen_string_literal: true

# A run of floats taller together than the page. The page is 300 × 200 with
# a 20 pt margin: 260 × 160 pt of content, so two floats of 150 pt do not fit
# side by side and three of 60 pt in height do not fit one page.
RSpec.describe Stationery::Layout::Flow do
  let(:words) { Array.new(40) { |i| "word#{i}" }.join(" ") }
  let(:ascent) { open_sans_book.resolve(base_style).first.ascender(10) }

  def block(width, height, **) = Stationery::Layout::Box.new(flow, width:, height:, **)
  def floated(node, side = :left, **) = Stationery::Layout::Floated.new(node, side:, **)
  def black(width = 150, height = 60, side = :left) = floated(block(width, height, background: "#000000"), side)
  def run_of(count = 3) = Array.new(count) { black }

  # Per page, [x, top] of every text drawn, the top from the page's top edge.
  def pages_of(pdf)
    reader_for(pdf).pages.map do |page|
      page.runs.map { |run| [run.origin.x.round(2), (200 - run.origin.y - ascent).round(2)] }
    end
  end

  # Per page, [x, top, width, height] of every rectangle filled.
  def rects_of(pdf)
    page_contents(pdf).map do |content|
      content.scan(/^([\d.]+) (-?[\d.]+) ([\d.]+) ([\d.]+) re$/).map do |x, y, width, height|
        [x.to_f, 200 - y.to_f - height.to_f, width.to_f, height.to_f]
      end
    end
  end

  def floats_of(pdf) = rects_of(pdf).map(&:size)

  it "moves the float of a run that does not fit the page to the next, with what wraps beside it" do
    pdf, paginator = render_layout(flow(*run_of, text_node(words)))

    expect(rects_of(pdf)).to eq([[[20, 20, 150, 60], [20, 80, 150, 60]], [[20, 20, 150, 60]]])
    expect(pages_of(pdf)[0]).to be_empty
    expect(pages_of(pdf)[1].first).to eq([170.0, 20.0])
    expect(text_of(pdf).split).to eq(words.split)
    expect(paginator.warnings).to be_empty
  end

  it "takes a run as long as it is a page at a time" do
    pdf, paginator = render_layout(flow(*run_of(7), text_node("beside")))

    expect(floats_of(pdf)).to eq([2, 2, 2, 1])
    expect(pages_of(pdf).last).to eq([[170.0, 20.0]])
    expect(paginator.warnings).to be_empty
  end

  it "cuts a run below other content where it no longer fits what is left of the page" do
    pdf, paginator = render_layout(flow(text_node("A line first."), *run_of, text_node(words)))

    expect(floats_of(pdf)).to eq([2, 1])
    expect(pages_of(pdf)).to match([[[20.0, 20.0]], include([170.0, 20.0])])
    expect(text_of(pdf).split.last(40)).to eq(words.split)
    expect(paginator.warnings).to be_empty
  end

  it "moves floats that fit a page together to the next page together" do
    pdf, paginator = render_layout(flow(lines_of(6), black(100, 60), black(100, 60, :right), black(100, 40),
                                        text_node("between")))

    expect(floats_of(pdf)).to eq([0, 3])
    expect(pages_of(pdf)[1]).to eq([[120.0, 20.0]])
    expect(paginator.warnings).to be_empty
  end

  it "keeps a heading with the first float of a run that is cut" do
    heading = text_node("Heading").tap { |node| node.keep_with_next = true }
    pdf, paginator = render_layout(flow(spacer(30), heading, *run_of, text_node("beside")))

    expect(floats_of(pdf)).to eq([1, 2])
    expect(reader_for(pdf).pages[0].text).to include("Heading")
    expect(paginator.warnings).to be_empty
  end

  it "keeps left and right floats beside each other and moves the one that stacks too low" do
    pdf, paginator = render_layout(flow(black(100, 100), black(100, 100, :right), black(100, 100, :right),
                                        text_node("beside")))

    expect(rects_of(pdf)).to eq([[[20, 20, 100, 100], [180, 20, 100, 100]], [[180, 20, 100, 100]]])
    expect(pages_of(pdf)[1]).to eq([[20.0, 20.0]])
    expect(paginator.warnings).to be_empty
  end

  it "keeps a float that fits beside the floats above it" do
    pdf, paginator = render_layout(flow(black(100, 150), black(100, 150, :right), text_node("between")))

    expect(floats_of(pdf)).to eq([2])
    expect(pages_of(pdf)[0]).to eq([[120.0, 20.0]])
    expect(paginator.warnings).to be_empty
  end

  it "moves a float written after the text beside the floats above it" do
    pdf, paginator = render_layout(flow(black(150, 120), text_node("beside"), black(150, 60), text_node("after")))

    expect(floats_of(pdf)).to eq([1, 1])
    expect(pages_of(pdf)).to eq([[[170.0, 20.0]], [[170.0, 20.0]]])
    expect(paginator.warnings).to be_empty
  end

  it "reports the float taller than a page by itself, and only that one" do
    pdf, paginator = render_layout(flow(black, black(150, 300), black, text_node("beside")))

    expect(floats_of(pdf)).to eq([1, 1, 1])
    expect(pages_of(pdf)[2]).to eq([[170.0, 20.0]])
    expect(paginator.warnings.map { |warning| [warning.page, warning.height] }).to eq([[2, 300]])
  end

  it "moves floated images as it moves floated boxes" do
    image = -> { Stationery::Layout::Image.new(image_path("rgb.jpg"), width: 150, height: 60) }
    pdf, paginator = render_layout(flow(*Array.new(3) { floated(image.call) }, text_node("beside")))

    expect(reader_for(pdf).pages.map { |page| page.raw_content.scan(/ Do$/).size }).to eq([2, 1])
    expect(pages_of(pdf)[1]).to eq([[170.0, 20.0]])
    expect(paginator.warnings).to be_empty
  end

  it "keeps the margins of a float in the height it takes" do
    floats = Array.new(2) { floated(block(150, 60, background: "#000000"), margin: { bottom: 30 }) }
    pdf, paginator = render_layout(flow(*floats, text_node("beside")))

    expect(floats_of(pdf)).to eq([1, 1])
    expect(paginator.warnings).to be_empty
  end

  it "moves a block that does not fit below the floats of a fresh page on and leaves the floats" do
    whole = Stationery::Layout::Box.new(flow(lines_of(6))).tap { |box| box.break_inside = :avoid }
    pdf, paginator = render_layout(flow(black(260, 100), whole))

    expect(floats_of(pdf)).to eq([1, 0])
    expect(pages_of(pdf)[0]).to be_empty
    expect(pages_of(pdf)[1].first).to eq([20.0, 20.0])
    expect(paginator.warnings).to be_empty
  end

  it "moves a flow on whose first part would run over the page below the floats" do
    whole = Stationery::Layout::Box.new(flow(lines_of(6))).tap { |box| box.break_inside = :avoid }
    pdf, paginator = render_layout(flow(black(260, 100), flow(whole, text_node("after"))))

    expect(floats_of(pdf)).to eq([1, 0])
    expect(pages_of(pdf)[1].size).to eq(7)
    expect(paginator.warnings).to be_empty
  end

  it "measures each part of a flow cut in a run as its page holds it" do
    head, tail = flow(*run_of, text_node("beside")).split(260, 160, fresh: true)

    expect(head.measure(260)).to eq(120)
    expect(tail.measure(260)).to eq(60)
    expect(head.children.size).to eq(2)
  end

  it "places nothing of a run that does not fit below other content" do
    head, tail = flow(*run_of, text_node("beside")).split(260, 160, fresh: false)

    expect(head).to be_nil
    expect(tail.children.size).to eq(4)
  end
end
