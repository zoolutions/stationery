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

  describe "across pages" do
    def top_y(pdf, page) = reader_for(pdf).pages[page].runs.map(&:y).max
    def lines_on(pdf, page, op = " l\nS") = page_contents(pdf)[page].scan(op).size

    it "moves whole to the next page when it fits there but not in the space left" do
      pdf, paginator = render_layout(flow(spacer(120), box(lines_of(5), background: "#EEEEEE")))
      reader = reader_for(pdf)

      expect(reader.page_count).to eq(2)
      expect(reader.pages[0].text).not_to include("line")
      expect(reader.pages[1].text).to include("line 1", "line 5")
      expect(top_y(pdf, 1)).to eq(top_y(render_layout(lines_of(1)).first, 0))
      expect(paginator.warnings).to be_empty
    end

    it "continues on the next page when it is taller than a page" do
      pdf, paginator = render_layout(box(lines_of(20), background: "#EEEEEE", padding: 6))
      reader = reader_for(pdf)

      expect(reader.page_count).to eq(2)
      expect(paginator.warnings).to be_empty
      expect(page_contents(pdf)).to all(match(/re\nf/))
      expect(reader.pages[0].text).to include("line 1")
      expect(reader.pages[1].text).to include("line 20")
      expect(strings_of(pdf)).to eq(Array.new(20) { |i| "line #{i + 1}" })
    end

    it "splits below existing content with break_inside: :auto" do
      auto = box(lines_of(8)).tap { |b| b.break_inside = :auto }
      pdf, = render_layout(flow(spacer(100), auto))

      expect(reader_for(pdf).pages[0].text).to include("line 1")
      expect(reader_for(pdf).pages[1].text).to include("line 8")
    end

    it "overflows with a warning under break_inside: :avoid" do
      avoid = box(lines_of(20)).tap { |b| b.break_inside = :avoid }
      pdf, paginator = render_layout(avoid)

      expect(page_count(pdf)).to eq(1)
      expect(paginator.warnings.size).to eq(1)
    end

    it "never splits a fixed-height or overflow-controlled box" do
      expect(box(lines_of(20), height: 300).splittable?).to be(false)
      expect(box(lines_of(20), overflow: :truncate).splittable?).to be(false)
      expect(box(lines_of(20)).splittable?).to be(true)
      expect(render_layout(box(lines_of(20), height: 300)).last.warnings.size).to eq(1)
    end

    it "leaves the bottom border off the head and the top border off the tail" do
      pdf, = render_layout(box(lines_of(20), border: { width: 1, sides: %i[top bottom] }))

      expect([lines_on(pdf, 0), lines_on(pdf, 1)]).to eq([1, 1])
      expect(page_contents(pdf)[0].index(" l\nS")).to be < page_contents(pdf)[0].index("BT")
    end

    it "drops padding and border at the cut with decoration: :slice" do
      plain, = render_layout(lines_of(20))
      pdf, = render_layout(box(lines_of(20), padding: 10, border: { width: 2 }))

      expect(top_y(pdf, 0)).to be_within(0.01).of(top_y(plain, 0) - 12)
      expect(top_y(pdf, 1)).to be_within(0.01).of(top_y(plain, 0))
    end

    it "keeps padding but not the border at the cut with decoration: :clone" do
      plain, = render_layout(lines_of(20))
      pdf, = render_layout(box(lines_of(20), padding: 10, border: { width: 2 }, decoration: :clone))

      expect(top_y(pdf, 1)).to be_within(0.01).of(top_y(plain, 0) - 10)
    end

    it "cuts rounded corners square by clipping the fragment" do
      pdf, paginator = render_layout(box(lines_of(20), background: "#EEEEEE", radius: 6, border: { width: 1 }))

      expect(page_contents(pdf)).to all(include("W n"))
      expect(page_contents(pdf).first).to match(/ c\n/)
      expect(paginator.warnings).to be_empty
    end

    it "runs the shape past a cut edge by radius and stroke and bleeds the outset only on closed edges" do
      pdf, = render_layout(box(lines_of(20), background: "#EEEEEE", radius: 6, outset: 10, border: { width: 1 }))
      head, tail = page_contents(pdf).map { |content| content.match(/(\S+) (\S+) 280 (\S+) re\nW n/) }
      head_shape_bottom = page_contents(pdf).first[/\n16 (\S+) l\n/, 1].to_f

      expect(head[1].to_f).to eq(10)
      expect(head[2].to_f + head[3].to_f).to be_within(0.01).of(190)
      expect(head[2].to_f - head_shape_bottom).to be_within(0.01).of(6 + 1)
      expect(tail[2].to_f + tail[3].to_f).to be_within(0.01).of(180)
    end

    it "splits a nested box at the top of a fresh outer box" do
      pdf, paginator = render_layout(box(box(lines_of(20)), padding: 4))

      expect(page_count(pdf)).to eq(2)
      expect(paginator.warnings).to be_empty
    end

    it "stays whole when its content finishes on the page" do
      pdf, paginator = render_layout(box(lines_of(10), spacer(40), padding: 4, border: { width: 1 }))

      expect(page_count(pdf)).to eq(1)
      expect(page_contents(pdf).first.scan(" l\nS").size).to eq(4)
      expect(paginator.warnings).to be_empty
    end

    it "hands keep_with_next to the tail" do
      tall = box(lines_of(20)).tap { |b| b.keep_with_next = true }
      head, tail = tall.split(260, 100)

      expect(head.keep_with_next).to be_nil
      expect(tail.keep_with_next).to be(true)
    end

    it "moves whole when none of its content fits and forces it on a fresh page" do
      image = Stationery::Layout::Image.new(image_path("rgb.jpg"), width: 100, height: 300)
      tall = box(image)
      pdf, paginator = render_layout(tall)

      expect(tall.split(260, 100)).to eq([nil, tall])
      expect(page_count(pdf)).to eq(1)
      expect(paginator.warnings.size).to eq(1)
    end
  end
end
