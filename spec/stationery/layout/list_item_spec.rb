# frozen_string_literal: true

RSpec.describe Stationery::Layout::ListItem do
  def bullet(shape = :disc) = Stationery::Layout::Bullet.new(shape, style: base_style, context: ctx)

  def item(*children, marker: bullet)
    Stationery::Layout::ListItem.new(marker, flow(*children), indent: 18, marker_gap: 6)
  end

  def curves(content) = content.scan(/ c$/).size

  it "measures the taller of its marker and its body" do
    expect(item(lines_of(3)).measure(260)).to be_within(0.001).of(line_height * 3)
    expect(item.measure(260)).to be_within(0.001).of(line_height)
  end

  it "reports its widths as the indent plus the body's" do
    node = item(text_node("word word"))

    expect(node.natural_width).to be_within(0.001).of(18 + text_node("word word").natural_width)
    expect(node.min_width).to be_within(0.001).of(18 + text_node("word").natural_width)
  end

  it "paints the body at the indent and the marker right-aligned in its column" do
    pdf, = render_layout(item(text_node("body")))
    content = page_contents(pdf).first

    expect(positions_of(pdf).first.first).to be_within(0.01).of(38)
    expect(content).to match(/^32 [\d.]+ m$/)
    expect(curves(content)).to eq(4)
  end

  it "draws a text marker right-aligned in its column" do
    marker = Stationery::Layout::Text.new([Stationery::Text::Run.new("1.", base_style)], context: ctx, align: :right)
    pdf, = render_layout(item(text_node("body"), marker:))
    marker_x, body_x = positions_of(pdf).map(&:first)

    expect(marker_x + text_node("1.").natural_width).to be_within(0.01).of(32)
    expect(body_x).to be_within(0.01).of(38)
  end

  it "splits across pages with the marker on the first page only" do
    pdf, paginator = render_layout(flow(spacer(100), item(lines_of(10))))
    first, second = page_contents(pdf)

    expect([curves(first), curves(second)]).to eq([4, 0])
    expect(strings_of(pdf)).to eq(Array.new(10) { |i| "line #{i + 1}" })
    expect(positions_of(pdf).map(&:first).uniq).to eq([38])
    expect(paginator.warnings).to be_empty
  end

  it "moves to the next page whole when its first line does not fit" do
    pdf, = render_layout(flow(spacer(155), item(lines_of(3, prefix: "item"))))
    first, second = page_contents(pdf)

    expect([curves(first), curves(second)]).to eq([0, 4])
    expect(reader_for(pdf).pages[1].text).to include("item 1", "item 3")
  end

  it "moves an unsplittable body whole, and places one taller than a page at the top" do
    picture = -> { Stationery::Layout::Image.new(image_path("rgb.jpg"), height: 60) }
    moved, = render_layout(flow(spacer(120), item(picture.call)))
    tall, paginator = render_layout(item(Stationery::Layout::Image.new(image_path("rgb.jpg"), height: 300)))

    expect(page_contents(moved).map { |c| curves(c) }).to eq([0, 4])
    expect(page_count(tall)).to eq(1)
    expect(paginator.warnings.size).to eq(1)
  end

  it "keeps with next on its last fragment only and forwards break_inside to the body" do
    node = item(lines_of(10))
    node.keep_with_next = true
    head, tail = node.split(260, 40)
    node.break_inside = :avoid

    expect([head.marker, tail.marker]).to eq([node.marker, nil])
    expect([head.keep_with_next, tail.keep_with_next]).to eq([nil, true])
    expect([node.break_inside, node.body.break_inside, node.avoid_break?]).to eq([:avoid, :avoid, true])
  end

  it "accumulates the indent of nested items" do
    pdf, = render_layout(item(text_node("outer"), item(text_node("inner"))))

    expect(positions_of(pdf).map(&:first)).to eq([38, 56])
  end

  describe Stationery::Layout::Bullet do
    it "is a line tall and a fixed fraction of an em wide" do
      expect(bullet.measure(100)).to be_within(0.001).of(line_height)
      expect([bullet.fixed_width(100), bullet.natural_width]).to all(be_within(0.001).of(3.6))
    end

    it "strokes a circle and fills a square" do
      circle, = render_layout(item(text_node("a"), marker: bullet(:circle)))
      square, = render_layout(item(text_node("a"), marker: bullet(:square)))

      expect(page_contents(circle).first).to include("0.6 w").and match(/ c\nh\nS$/)
      expect(page_contents(square).first).to match(/ re\nf$/)
    end
  end
end
