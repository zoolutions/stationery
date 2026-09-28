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

  describe "a box that stays a block" do
    let(:content) { flow(text_node("text")) }

    it "is one with something of its own to paint, a size of its own or a place for its content" do
      blocks = [{ background: "#EEEEEE" }, { border: { width: 1 } }, { shadow: true }, { link: "https://example.test" },
                { width: 100 }, { width: 0.5 }, { width: :auto }, { height: 40 }, { rotate: 5 },
                { overflow: :hidden }, { valign: :middle }]

      expect(blocks.map { |options| Stationery::Layout::Box.new(content, **options).wraps? }).to all(be(false))
      expect(Stationery::Layout::Box.new(content, padding: 4, min_height: 30, role: :section).wraps?).to be(true)
      expect(Stationery::Layout::Box.new(block(10, 10)).wraps?).to be(false)
    end

    it "keeps the width the floats leave all the way down, its background beside the float" do
      tall = boxed(text_node(words.split.first(20).join(" ")), background: "#000000")
      pdf, = render_layout(flow(floated(block(80, 20)), tall))

      expect(page_contents(pdf).first).to match(/^100 [\d.]+ 180 [\d.]+ re$/)
      expect(tops_of(pdf).map(&:first).uniq).to eq([100.0])
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
