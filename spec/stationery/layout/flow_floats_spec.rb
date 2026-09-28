# frozen_string_literal: true

# Floats in a flow. The page is 300 × 200 with a 20 pt margin: the content
# box starts at x 20 and is 260 wide; PDF y runs bottom-up from 180.
RSpec.describe Stationery::Layout::Flow do
  let(:words) { Array.new(60) { |i| "word#{i}" }.join(" ") }
  let(:ascent) { open_sans_book.resolve(base_style).first.ascender(10) }

  def block(width, height, **) = Stationery::Layout::Box.new(flow, width:, height:, **)
  def floated(node, side = :left, **) = Stationery::Layout::Floated.new(node, side:, **)

  # [x, top] of every text drawn on the first page, the top from the page's top edge.
  def tops_of(pdf) = positions_of(pdf).map { |x, y| [x.round(2), (200 - y - ascent).round(2)] }

  # [x, y, width, height] of every rectangle filled on a page, from the page's top edge.
  def rects_of(pdf, page = 0)
    page_contents(pdf)[page].scan(/^([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) re$/).map do |rect|
      x, y, width, height = rect.map(&:to_f)
      [x, (200 - y - height).round(2), width, height]
    end
  end

  # Where every line drawn ends.
  def ends_of(pdf)
    font = open_sans_book.resolve(base_style).first
    positions_of(pdf).zip(strings_of(pdf)).map { |(x, _), text| (x + font.width_of(text, 10, kerning: true)).round(1) }
  end

  def nth_line(index) = (20 + (line_height * index)).round(2)

  describe "measure" do
    it "starts what follows a float at the float's top and covers the float" do
      short = flow(floated(block(80, 100)), text_node("short"))
      long = flow(floated(block(80, 20)), text_node(words))

      expect(short.measure(260)).to eq(100)
      expect(long.measure(260)).to be > 20
      expect(long.measure(260)).to be > flow(text_node(words)).measure(260)
    end

    it "counts the float's margins" do
      expect(flow(floated(block(80, 100), margin: 6), text_node("short")).measure(260)).to eq(106)
      expect(flow(floated(block(80, 100), margin: { top: 4 }), text_node("short")).measure(260)).to eq(104)
    end

    it "puts the gap between the children in the flow, not around the float" do
      stack = flow(text_node("a"), floated(block(80, 10)), text_node("b"), gap: 6)

      expect(stack.measure(260)).to be_within(0.001).of((line_height * 2) + 6)
    end

    it "remembers its height per width, floats or not" do
      float = floated(block(80, 100))
      allow(float).to receive(:measure).and_call_original
      stack = flow(float, text_node("short"))
      2.times { stack.measure(260) }

      expect(float).to have_received(:measure).once
    end

    it "knows about a float added after it was asked" do
      stack = flow(text_node("a"))
      expect(stack.floats?).to be(false)
      stack << floated(block(80, 100))

      expect(stack.floats?).to be(true)
      expect(stack.measure(260)).to be_within(0.001).of(line_height + 100)
    end

    it "leaves a page break out, as a flow without floats does" do
      broken = flow(floated(block(80, 30)), Stationery::Layout::PageBreak.new, text_node("after"))
      canvas = Stationery::Canvas.new(Stationery::Page.new(size: [300, 200]), Stationery::Resources.new)
      allow(canvas).to receive(:text).and_call_original
      broken.paint(canvas, 0, 0, 260)

      expect(broken.measure(260)).to eq(30)
      expect(canvas).to have_received(:text).with("after", hash_including(x: 80))
    end

    it "is as wide as its floats and the widest child beside them" do
      text = text_node("some words")

      expect(flow(floated(block(80, 20), margin: 5), text).natural_width).to eq(85 + text.natural_width)
      expect(flow(floated(block(80, 20)), text).min_width).to eq([80, text.min_width].max)
    end
  end

  describe "text" do
    it "wraps beside a left float and takes the full width below it" do
      pdf, = render_layout(flow(floated(block(80, line_height * 2, background: "#000000"), margin: 10),
                                text_node(words)))

      expect(rects_of(pdf)).to eq([[20.0, 20.0, 80.0, (line_height * 2).round(4)]])
      expect(tops_of(pdf).first(4)).to eq([[110.0, nth_line(0)], [110.0, nth_line(1)], [110.0, nth_line(2)],
                                           [20.0, nth_line(3)]])
      expect(strings_of(pdf).join(" ")).to eq(words)
    end

    it "wraps beside a right float, which sits at the right edge" do
      pdf, = render_layout(flow(floated(block(80, line_height * 2, background: "#000000"), :right, margin: 10),
                                text_node(words, align: :right)))

      expect(rects_of(pdf).first.first(3)).to eq([200.0, 20.0, 80.0])
      expect(ends_of(pdf).first(4)).to eq([190.0, 190.0, 190.0, 280.0])
    end

    it "flows between a left and a right float" do
      floats = [floated(block(60, line_height * 2)), floated(block(70, line_height), :right)]
      left, = render_layout(flow(*floats, text_node(words)))
      right, = render_layout(flow(*floats, text_node(words, align: :right)))

      expect(tops_of(left).map(&:first).first(3)).to eq([80.0, 80.0, 20.0])
      expect(ends_of(right).first(3)).to eq([210.0, 280.0, 280.0])
    end

    it "clears below the floats that leave less than its widest word" do
      long = "Supercalifragilisticexpialidocious"
      pdf, = render_layout(flow(floated(block(200, 30)), text_node("#{long} and more")))

      expect(tops_of(pdf).first).to eq([20.0, 50.0])
    end

    it "wraps a second paragraph beside what is left of the float" do
      pdf, = render_layout(flow(floated(block(80, line_height * 3)), text_node("one"), text_node(words)))

      expect(tops_of(pdf).first(4)).to eq([[100.0, nth_line(0)], [100.0, nth_line(1)], [100.0, nth_line(2)],
                                           [20.0, nth_line(3)]])
    end

    it "wraps text marked as a link target and text inside a nested flow" do
      marked = Stationery::Layout::Mark.new(text_node("marked"), ["here"])
      pdf, = render_layout(flow(floated(block(80, line_height * 4)), marked,
                                flow(spacer(line_height), text_node(words))))

      expect(tops_of(pdf).first(4)).to eq([[100.0, nth_line(0)], [100.0, nth_line(2)], [100.0, nth_line(3)],
                                           [20.0, nth_line(4)]])
    end

    it "leaves the text above a float alone" do
      pdf, = render_layout(flow(text_node("above"), floated(block(80, 40)), text_node("beside")))

      expect(tops_of(pdf)).to eq([[20.0, nth_line(0)], [100.0, nth_line(1)]])
    end
  end

  describe "other children" do
    it "places a block that fills the width beside the float, in the width that is left" do
      pdf, = render_layout(flow(floated(block(80, 50), margin: 10),
                                Stationery::Layout::Box.new(flow(text_node("boxed")), background: "#000000"),
                                Stationery::Layout::Rule.new(height: 2)))

      expect(rects_of(pdf)).to eq([[110.0, 20.0, 170.0, line_height.round(4)],
                                   [110.0, nth_line(1), 170.0, 2.0]])
    end

    it "keeps a block at that width all the way down, also below the float" do
      tall = Stationery::Layout::Box.new(flow(text_node(words.split.first(20).join(" "))), background: "#000000")
      pdf, = render_layout(flow(floated(block(80, 20)), tall))

      expect(rects_of(pdf).first.first(3)).to eq([100.0, 20.0, 180.0])
      expect(tops_of(pdf).map(&:first).uniq).to eq([100.0])
    end

    it "places a block with a width of its own beside the float when it fits, else below it" do
      beside, = render_layout(flow(floated(block(80, 50)), block(100, 10, background: "#000000")))
      below, = render_layout(flow(floated(block(80, 50), margin: 5), block(200, 10, background: "#000000")))

      expect(rects_of(beside)).to eq([[100.0, 20.0, 100.0, 10.0]])
      expect(rects_of(below)).to eq([[20.0, 75.0, 200.0, 10.0]])
    end

    it "aligns a block with a width of its own in the full width below the floats" do
      pdf, = render_layout(flow(floated(block(60, 10)), spacer(10), block(100, 10, background: "#000000"),
                                align: :right))

      expect(rects_of(pdf)).to eq([[180.0, 30.0, 100.0, 10.0]])
    end

    it "aligns a block with a width of its own in the width that is left" do
      pdf, = render_layout(flow(floated(block(60, 50)), block(100, 10, background: "#000000"), align: :right))

      expect(rects_of(pdf)).to eq([[180.0, 20.0, 100.0, 10.0]])
    end

    it "moves a block below the float when its narrowest content does not fit beside it" do
      long = Stationery::Layout::Box.new(flow(text_node("Supercalifragilisticexpialidocious")))
      pdf, = render_layout(flow(floated(block(200, 30)), long))

      expect(tops_of(pdf)).to eq([[20.0, 50.0]])
    end

    it "places a table beside the float when its columns fit there" do
      table = Stationery::Layout::Table.new([%w[a b], %w[c d]], context: ctx)
      wide = Stationery::Layout::Table.new([%w[a b]], context: ctx, width: 250)
      pdf, = render_layout(flow(floated(block(80, 60)), table, wide))

      expect(tops_of(pdf).map(&:first).first(4).min).to be >= 100
      expect(tops_of(pdf).last(2).map(&:last).uniq.first).to be >= 80
      expect(tops_of(pdf).last(2).map(&:first).min).to be < 100
    end

    it "lets a spacer take its height beside the float without clearing it" do
      pdf, = render_layout(flow(floated(block(80, 60)), spacer(10), text_node("after")))

      expect(tops_of(pdf)).to eq([[100.0, 30.0]])
    end

    it "is cleared by whatever follows the flow it is in" do
      inner = Stationery::Layout::Box.new(flow(floated(block(80, 60)), text_node("inside")))
      pdf, = render_layout(flow(inner, text_node("after")))

      expect(tops_of(pdf)).to eq([[100.0, 20.0], [20.0, 80.0]])
    end
  end

  describe "several floats" do
    it "puts a second float on the same side beside the first when it fits" do
      pdf, = render_layout(flow(floated(block(80, 40, background: "#000000"), margin: 5),
                                floated(block(60, 20, background: "#000000"), margin: 5), text_node(words)))

      expect(rects_of(pdf)).to eq([[20.0, 20.0, 80.0, 40.0], [105.0, 20.0, 60.0, 20.0]])
      expect(tops_of(pdf).first).to eq([170.0, 20.0])
    end

    it "puts it below the first when it does not fit beside it" do
      pdf, = render_layout(flow(floated(block(150, 40, background: "#000000"), margin: 5),
                                floated(block(150, 20, background: "#000000"), margin: 5), text_node(words)))

      expect(rects_of(pdf)).to eq([[20.0, 20.0, 150.0, 40.0], [20.0, 65.0, 150.0, 20.0]])
      expect(tops_of(pdf).first).to eq([175.0, 20.0])
    end

    it "stacks right floats from the right edge" do
      pdf, = render_layout(flow(floated(block(80, 40, background: "#000000"), :right),
                                floated(block(60, 20, background: "#000000"), :right)))

      expect(rects_of(pdf)).to eq([[200.0, 20.0, 80.0, 40.0], [140.0, 20.0, 60.0, 20.0]])
    end

    it "never places a float above one placed before it" do
      pdf, = render_layout(flow(floated(block(200, 30, background: "#000000")),
                                floated(block(100, 10, background: "#000000"), :right),
                                floated(block(40, 10, background: "#000000"))))

      expect(rects_of(pdf)).to eq([[20.0, 20.0, 200.0, 30.0], [180.0, 50.0, 100.0, 10.0],
                                   [20.0, 50.0, 40.0, 10.0]])
    end

    it "places a float wider than the flow at the edge, below the others" do
      pdf, = render_layout(flow(floated(block(80, 30, background: "#000000")),
                                floated(block(400, 10, background: "#000000"), :right)))

      expect(rects_of(pdf).last.first(3)).to eq([20.0, 50.0, 260.0])
    end

    it "moves text down to where the room between the floats takes its widest word" do
      pdf, = render_layout(flow(floated(block(120, 30)), floated(block(120, 50), :right),
                                text_node("Supercalifragilistic")))

      expect(tops_of(pdf)).to eq([[20.0, 50.0]])
    end
  end
end
