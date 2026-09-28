# frozen_string_literal: true

# Boxes and list items beside floats: those that wrap, and those that stay
# blocks. The page is 300 × 200 with a 20 pt margin: the content box starts
# at x 20 and is 260 wide.
RSpec.describe Stationery::Layout::Flow do
  let(:words) { Array.new(60) { |i| "word#{i}" }.join(" ") }
  let(:ascent) { open_sans_book.resolve(base_style).first.ascender(10) }

  def block(width, height, **) = Stationery::Layout::Box.new(flow, width:, height:, **)
  def floated(node, side = :left, **) = Stationery::Layout::Floated.new(node, side:, **)
  def boxed(*children, **) = Stationery::Layout::Box.new(flow(*children), **)

  def item(*children, marker: text_node("1."))
    Stationery::Layout::ListItem.new(marker, flow(*children), indent: 20, marker_gap: 4)
  end

  # [x, top] of every text drawn on the first page, the top from the page's top edge.
  def tops_of(pdf) = positions_of(pdf).map { |x, y| [x.round(2), (200 - y - ascent).round(2)] }

  # Where every line drawn ends.
  def ends_of(pdf)
    font = open_sans_book.resolve(base_style).first
    positions_of(pdf).zip(strings_of(pdf)).map { |(x, _), text| (x + font.width_of(text, 10, kerning: true)).round(1) }
  end

  def nth_line(index) = (20 + (line_height * index)).round(2)

  describe "a box that paints nothing of its own" do
    it "keeps the full width: its text wraps beside the float and takes the full width below it" do
      text = words.split.first(30).join(" ")
      pdf, = render_layout(flow(floated(block(80, line_height * 2), margin: 10), boxed(text_node(text)),
                                text_node("after")))
      lines = strings_of(pdf).size - 1

      expect(tops_of(pdf).first(4)).to eq([[110.0, nth_line(0)], [110.0, nth_line(1)], [110.0, nth_line(2)],
                                           [20.0, nth_line(3)]])
      expect(tops_of(pdf).last).to eq([20.0, nth_line(lines)])
      expect(strings_of(pdf).join(" ")).to eq("#{text} after")
    end

    it "is as tall as the lines it paints" do
      box = boxed(text_node(words), padding: 5)
      beside = flow(floated(block(80, line_height * 2)), box)
      pdf, = render_layout(beside)

      expect(beside.measure(260)).to be_within(0.001).of((strings_of(pdf).size * line_height) + 10)
      expect(beside.measure(260)).to be < flow(floated(block(80, 20)), boxed(text_node(words), width: 170)).measure(260)
    end

    it "meets the float inside its padding: the padding under the float is not added to it" do
      left, = render_layout(flow(floated(block(80, line_height * 2)), boxed(text_node(words), padding: [0, 0, 0, 12])))
      right, = render_layout(flow(floated(block(80, line_height * 2), :right),
                                  boxed(text_node(words, align: :right), padding: [0, 12, 0, 0])))

      expect(tops_of(left).map(&:first).first(3)).to eq([100.0, 100.0, 32.0])
      expect(ends_of(right).first(3)).to eq([200.0, 200.0, 268.0])
    end

    it "keeps its padding beside a float narrower than the padding" do
      pdf, = render_layout(flow(floated(block(8, line_height * 2)), boxed(text_node(words), padding: [0, 0, 0, 12])))

      expect(tops_of(pdf).map(&:first).uniq).to eq([32.0])
    end

    it "counts its top padding: the lines start further down beside the float" do
      box = boxed(text_node(words), padding: [line_height, 0])
      pdf, = render_layout(flow(floated(block(80, line_height * 3)), box))

      expect(tops_of(pdf).first(3)).to eq([[100.0, nth_line(1)], [100.0, nth_line(2)], [20.0, nth_line(3)]])
    end

    it "hands the floats on to the boxes and the flows inside it" do
      inner = boxed(flow(text_node(words)), padding: [0, 0, 0, 5])
      pdf, = render_layout(flow(floated(block(80, line_height * 2)), boxed(inner, padding: [0, 0, 0, 5])))

      expect(tops_of(pdf).map(&:first).first(3)).to eq([100.0, 100.0, 30.0])
    end

    it "wraps when it is a link target too" do
      marked = Stationery::Layout::Mark.new(boxed(text_node(words)), ["here"])
      pdf, = render_layout(flow(floated(block(80, line_height * 2)), marked))

      expect(tops_of(pdf).map(&:first).first(3)).to eq([100.0, 100.0, 20.0])
    end

    it "starts below the floats that leave less than its widest word and its padding" do
      long = boxed(text_node("Supercalifragilisticexpialidocious and more"), padding: [0, 10])
      pdf, = render_layout(flow(floated(block(100, 30)), long))

      expect(tops_of(pdf).first).to eq([30.0, 50.0])
    end

    it "keeps a floor of its own and is cleared by what follows it" do
      pdf, = render_layout(flow(floated(block(80, line_height * 2)), boxed(text_node("short"), min_height: 50),
                                text_node("after")))

      expect(tops_of(pdf)).to eq([[100.0, 20.0], [20.0, 70.0]])
    end
  end

  describe "a box that paints something of its own" do
    let(:content) { flow(text_node("text")) }

    # [x, width] of every rectangle filled on the first page, in the order painted.
    def fills_of(pdf)
      page_contents(pdf).first.scan(/^([\d.]+) [\d.]+ ([\d.]+) [\d.]+ re$/).map { |x, w| [x.to_f, w.to_f] }
    end

    it "wraps as a plain box does; a size of its own or a place for its content makes a block" do
      wrapping = [{ background: "#EEEEEE" }, { border: { width: 1 } }, { shadow: true }, { link: "https://a.test" }]
      blocks = [{ width: 100 }, { width: 0.5 }, { width: :auto }, { height: 40 }, { rotate: 5 }, { overflow: :hidden },
                { valign: :middle }]

      expect(wrapping.map { |options| Stationery::Layout::Box.new(content, **options).wraps? }).to all(be(true))
      expect(blocks.map { |options| Stationery::Layout::Box.new(content, **options).wraps? }).to all(be(false))
      expect(Stationery::Layout::Box.new(block(10, 10)).wraps?).to be(false)
    end

    it "keeps the full width: its background runs under the float, its lines wrap beside it and widen below it" do
      tall = boxed(text_node(words.split.first(20).join(" ")), background: "#000000")
      pdf, = render_layout(flow(floated(block(80, 20)), tall))

      expect(page_contents(pdf).first).to match(/^20 [\d.]+ 260 [\d.]+ re$/)
      expect(tops_of(pdf).map(&:first).first(3)).to eq([100.0, 100.0, 20.0])
    end

    it "is painted before the floats beside it, which sit on top of its background" do
      pdf, = render_layout(flow(floated(block(80, 20, background: "#000000")),
                                floated(block(40, 20, background: "#000000"), :right),
                                boxed(text_node(words), background: "#EEEEEE")))

      expect(fills_of(pdf)).to eq([[20.0, 260.0], [20.0, 80.0], [240.0, 40.0]])
    end

    it "keeps its padding under the float: beside it the lines are the float's margin away" do
      box = boxed(text_node(words), padding: 12, background: "#EEEEEE", border: { width: 1 })
      pdf, = render_layout(flow(floated(block(80, line_height * 2), margin: 10), box))

      expect(tops_of(pdf).map(&:first).first(3)).to eq([110.0, 110.0, 33.0])
      expect(tops_of(pdf).first.last).to eq(33.0)
    end

    it "wraps between a left and a right float, and takes the full width below both" do
      box = boxed(text_node(words), background: "#EEEEEE")
      pdf, = render_layout(flow(floated(block(80, line_height * 3)), floated(block(60, line_height), :right), box))

      expect(tops_of(pdf).map(&:first).first(4)).to eq([100.0, 100.0, 100.0, 20.0])
      expect(ends_of(pdf).first).to be <= 220
      expect(ends_of(pdf)[1]).to be > 220
    end

    it "wraps inside another box with a background, and inside a list item, beside the float" do
      inner = boxed(text_node(words), background: "#FFFFFF", padding: [0, 0, 0, 5])
      outer = boxed(inner, background: "#EEEEEE", padding: 5)
      nested, = render_layout(flow(floated(block(80, line_height * 2)), outer))
      listed, = render_layout(flow(floated(block(80, line_height * 2)), item(inner)))

      expect(tops_of(nested).map(&:first).first(3)).to eq([100.0, 100.0, 30.0])
      expect(fills_of(nested)).to eq([[20.0, 260.0], [25.0, 250.0]])
      expect(tops_of(listed).sort_by { |x, top| [top, x] }.map(&:first).first(4)).to eq([100.0, 120.0, 120.0, 45.0])
      expect(fills_of(listed)).to eq([[40.0, 240.0]])
    end

    it "is a float itself" do
      float = floated(boxed(text_node("text"), width: 80))

      expect(float.wraps?).to be(false)
    end
  end

  describe "a list item" do
    it "wraps its body beside the float, the marker beside its first line, and widens below the float" do
      pdf, = render_layout(flow(floated(block(80, line_height * 2)), item(text_node(words))))

      expect(tops_of(pdf).first(4)).to eq([[100.0, nth_line(0)], [120.0, nth_line(0)], [120.0, nth_line(1)],
                                           [40.0, nth_line(2)]])
      expect(strings_of(pdf).drop(1).join(" ")).to eq(words)
    end

    it "keeps the marker at the edge beside a right float, and its lines out of the float" do
      pdf, = render_layout(flow(floated(block(80, line_height * 2), :right), item(text_node(words, align: :right))))

      expect(tops_of(pdf).first.first).to eq(20.0)
      expect(ends_of(pdf).drop(1).first(3)).to eq([200.0, 200.0, 280.0])
    end

    it "is as tall as the lines it paints, and the next item starts below it" do
      list = flow(item(text_node(words.split.first(30).join(" "))), item(text_node("second"), marker: text_node("2.")))
      beside = flow(floated(block(80, line_height * 2)), list)
      pdf, = render_layout(beside)
      lines = strings_of(pdf).size - 3

      expect(tops_of(pdf).last(2)).to eq([[20.0, nth_line(lines)], [40.0, nth_line(lines)]])
      expect(beside.measure(260)).to be_within(0.001).of((lines + 1) * line_height)
    end

    it "paints its marker after the background of its body, which it lies over beside the float" do
      float = floated(block(80, line_height * 2))
      plain, = render_layout(flow(float, item(boxed(text_node(words)))))
      pdf, = render_layout(flow(float, item(boxed(text_node(words), background: "#EEEEEE"))))
      content = page_contents(pdf).first
      by_line = ->(tops) { tops.sort_by { |x, top| [top, x] }.first(2) }

      expect(by_line.call(tops_of(pdf))).to eq(by_line.call(tops_of(plain)))
      expect(by_line.call(tops_of(pdf))).to eq([[100.0, nth_line(0)], [120.0, nth_line(0)]])
      expect(content.index(/^100 [\d.]+ Td$/)).to be > content.index(/^120 [\d.]+ Td$/)
      expect(content.index(/^100 [\d.]+ Td$/)).to be > content.index(/ re$/)
    end

    it "wraps without a marker, as the rest of a split item does" do
      pdf, = render_layout(flow(floated(block(80, line_height * 2)), item(text_node(words), marker: nil)))

      expect(tops_of(pdf).map(&:first).first(3)).to eq([120.0, 120.0, 40.0])
    end

    it "indents the items of a list inside it from the float as well" do
      nested = flow(text_node("outer"), flow(item(text_node(words), marker: text_node("a."))))
      pdf, = render_layout(flow(floated(block(80, line_height * 3)), item(nested)))

      expect(tops_of(pdf).map(&:first).first(6)).to eq([100.0, 120.0, 120.0, 140.0, 140.0, 60.0])
    end
  end
end
