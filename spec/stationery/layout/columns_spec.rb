# frozen_string_literal: true

RSpec.describe Stationery::Layout::Columns do
  # The spec page holds 260 x 160 points: two columns of 120 with a gap of 20,
  # eleven lines tall.
  def columns(*children, gap: 20, **) = described_class.new(flow(*children), gap:, **)

  def lines_in(fragment, width = 260)
    fragment.columns.map { |column| (column.measure(fragment.column_width(width)) / line_height).round }
  end

  def texts(pdf) = reader_for(pdf).pages.map(&:text)

  # { text => [x, y from the top of the page] } of the page's first runs.
  def places(pdf, page = 0)
    reader_for(pdf).pages[page].runs.to_h { |run| [run.text, [run.origin.x.round(2), (200 - run.origin.y).round(2)]] }
  end

  describe "arguments" do
    it "takes a count of at least one" do
      [0, -1, 1.5, "2", nil].each do |count|
        expect { columns(count:) }.to raise_error(ArgumentError, /count: must be an Integer of at least 1/)
      end
    end

    it "takes a gap of zero or more" do
      [-1, "12", nil].each do |gap|
        expect { columns(gap:) }.to raise_error(ArgumentError, /gap: must be a number of at least 0/)
      end
    end

    it "takes true or false for balance" do
      expect { columns(balance: nil) }.to raise_error(ArgumentError, /balance: must be true or false/)
    end

    it "takes true or a Hash for the rule" do
      expect { columns(rule: "red") }.to raise_error(ArgumentError, /rule: must be true or/)
      expect { columns(rule: false) }.not_to raise_error
    end
  end

  describe "widths" do
    it "shares the width left by the gaps" do
      expect(columns.column_width(260)).to eq(120)
      expect(columns(count: 3, gap: 10).column_width(260)).to eq(80)
      expect(columns(count: 1).column_width(260)).to eq(260)
      expect(columns(gap: 400).column_width(260)).to eq(0)
    end

    it "is as wide as its columns and gaps" do
      node = columns(text_node("wide words"), count: 3, gap: 10)
      paragraph = text_node("wide words")

      expect(node.natural_width).to be_within(0.001).of((paragraph.natural_width * 3) + 20)
      expect(node.min_width).to be_within(0.001).of((paragraph.min_width * 3) + 20)
    end
  end

  describe "balancing" do
    it "is as tall as its tallest column" do
      expect(columns(lines_of(7)).measure(260)).to be_within(0.001).of(4 * line_height)
      expect(lines_in(columns(lines_of(7)).fragment(260))).to eq([4, 3])
    end

    it "behaves like a group with one column" do
      node = columns(lines_of(3), text_node("more"), count: 1)

      expect(node.measure(260)).to be_within(0.001).of(4 * line_height)
      expect(lines_in(node.fragment(260))).to eq([4])
    end

    it "keeps a heading with the start of what follows it" do
      heading = text_node("Heading").tap { |node| node.keep_with_next = true }
      node = columns(lines_of(3), heading, lines_of(4, prefix: "body"))
      first, second = node.fragment(260).columns

      expect(first.children[1]).to equal(heading)
      expect(first.children.size).to eq(3)
      expect(second.children.size).to eq(1)
      expect(lines_in(node.fragment(260))).to eq([5, 3])
    end

    it "moves a heading to the next column when what follows cannot start below it" do
      heading = text_node("Heading").tap { |node| node.keep_with_next = true }
      node = columns(lines_of(3), heading, lines_of(4, prefix: "body", orphans: 2))
      first, second = node.fragment(260).columns

      expect(first.children.size).to eq(1)
      expect(second.children.first).to equal(heading)
      expect(lines_in(node.fragment(260))).to eq([3, 5])
    end

    it "moves a box that avoids breaking to the next column whole" do
      box = Stationery::Layout::Box.new(flow(lines_of(4, prefix: "boxed"))).tap { |node| node.break_inside = :avoid }
      node = columns(lines_of(3), box, lines_of(1, prefix: "last"))

      expect(lines_in(node.fragment(260))).to eq([3, 5])
      expect(node.fragment(260).columns.last.children.first).to equal(box)
    end

    it "honours orphans and widows at a column break" do
      paragraph = lines_of(6, orphans: 2, widows: 4)
      node = columns(paragraph)

      expect(lines_in(node.fragment(260))).to eq([2, 4])
    end

    it "moves a paragraph whole when its orphans do not fit" do
      node = columns(lines_of(3), lines_of(4, prefix: "kept", orphans: 3, widows: 1))

      expect(lines_in(node.fragment(260))).to eq([3, 4])
    end

    it "fills one column when balance is off" do
      node = columns(lines_of(7), balance: false)

      expect(lines_in(node.fragment(260))).to eq([7])
      expect(node.measure(260)).to be_within(0.001).of(7 * line_height)
    end

    it "estimates the height of content no page can hold" do
      node = columns(spacer(40_000), lines_of(2))
      allow(Stationery::Layout::Columns::Balancer).to receive(:new).and_call_original

      expect(node.measure(260)).to be_within(0.001).of((40_000 + (2 * line_height)) / 2)
      expect(Stationery::Layout::Columns::Balancer).not_to have_received(:new)
    end
  end

  describe "painting" do
    it "places the columns side by side, in reading order" do
      pdf, = render_layout(columns(lines_of(5)))
      placed = places(pdf)

      expect(placed["line 1"].first).to eq(20)
      expect(placed["line 4"].first).to eq(160)
      expect(placed["line 4"].last).to eq(placed["line 1"].last)
      expect(placed["line 5"].last).to eq(placed["line 2"].last)
    end

    it "puts what follows below the tallest column" do
      pdf, = render_layout(flow(text_node("above"), columns(lines_of(5)), text_node("below")))
      placed = places(pdf)

      expect(placed["below"].first).to eq(20)
      expect(placed["below"].last - placed["line 3"].last).to be_within(0.01).of(line_height)
      expect(placed["line 1"].last - placed["above"].last).to be_within(0.01).of(line_height)
    end

    it "draws a rule in the middle of each gap between columns with content" do
      pdf, = render_layout(columns(lines_of(2), count: 3, gap: 10, rule: { color: "#FF0000", width: 2 }))
      content = page_contents(pdf).first
      rules = content.scan(/^([\d.]+) ([\d.]+) m\n([\d.]+) ([\d.]+) l\nS/).map { |match| match.map(&:to_f) }

      expect(rules.size).to eq(1)
      expect(rules.first.values_at(0, 2)).to all(be_within(0.01).of(20 + 80 + 5))
      expect(rules.first[1] - rules.first[3]).to be_within(0.01).of(line_height)
      expect(content).to include("1 0 0 RG", "2 w")
    end

    it "draws no rule without the option" do
      pdf, = render_layout(columns(lines_of(4)))

      expect(page_contents(pdf).first).not_to match(/ l\nS/)
    end

    it "outlines the columns in debug mode" do
      resources = Stationery::Resources.new
      page = { size: [300, 200], margin: 20 }
      paginator = Stationery::Layout::Paginator.new(resources:, page:, debug: [:column])
      pdf = Stationery::PDF::Assembler.new(pages: paginator.paginate(columns(lines_of(4))), resources:).render

      expect(page_contents(pdf).first.scan(" re\nS").size).to eq(2)
    end
  end

  describe "across pages" do
    it "fills the page and balances the last one" do
      pdf, paginator = render_layout(columns(lines_of(50)))
      pages = texts(pdf)

      expect(pages.size).to eq(3)
      expect(pages[0]).to include("line 1", "line 22")
      expect(pages[0]).not_to include("line 23")
      expect(pages[1]).to include("line 23", "line 44")
      expect(pages[1]).not_to include("line 45")
      expect(places(pdf, 2)["line 45"]).to eq(places(pdf, 2)["line 48"].then { |x, y| [x - 140, y] })
      expect(places(pdf, 2)["line 47"].last).to eq(places(pdf, 2)["line 50"].last)
      expect(paginator.warnings).to be_empty
    end

    it "fills every column of the last page when balance is off" do
      pdf, = render_layout(columns(lines_of(36), balance: false))

      expect(page_count(pdf)).to eq(2)
      expect(places(pdf, 1).count { |_, (x, _)| x == 20 }).to eq(11)
      expect(places(pdf, 1).count { |_, (x, _)| x == 160 }).to eq(3)
    end

    it "hands the rest to a block with the same options" do
      node = columns(lines_of(50), count: 3, gap: 10, balance: false, rule: true).tap { |n| n.keep_with_next = true }
      head, tail = node.split(260, 160, fresh: true)

      expect(lines_in(head)).to eq([11, 11, 11])
      expect([tail.count, tail.gap, tail.keep_with_next]).to eq([3, 10, true])
      expect(lines_in(tail.fragment(260))).to eq([17])
    end

    it "returns itself when it fits" do
      node = columns(lines_of(6))

      expect(node.split(260, 160)).to eq([node, nil])
    end

    it "fills the height left below other content, then continues" do
      pdf, paginator = render_layout(flow(spacer(160 - (3 * line_height)), columns(lines_of(12))))

      expect(texts(pdf)[0]).to include("line 1", "line 6")
      expect(texts(pdf)[0]).not_to include("line 7")
      expect(places(pdf, 1)["line 7"].last).to eq(places(pdf, 1)["line 10"].last)
      expect(places(pdf, 1)["line 10"].first).to eq(160)
      expect(paginator.warnings).to be_empty
    end

    it "starts on the next page when a column would stay empty" do
      node = columns(lines_of(12, orphans: 2))
      pdf, = render_layout(flow(text_node("above"), spacer(160 - (2.5 * line_height)), node))

      expect(node.split(260, 1.5 * line_height)).to eq([nil, node])
      expect(texts(pdf)[0]).to include("above")
      expect(texts(pdf)[0]).not_to include("line 1")
      expect(places(pdf, 1)["line 1"].last).to eq(places(pdf, 1)["line 7"].last)
    end

    it "ends the page at a page break inside, balancing what comes before it" do
      node = columns(lines_of(6, prefix: "a"), Stationery::Layout::PageBreak.new, lines_of(3, prefix: "b"))
      pdf, = render_layout(flow(node, text_node("after")))

      expect(node.breaks?).to be(true)
      expect(texts(pdf)[0]).to include("a 1", "a 6")
      expect(texts(pdf)[0]).not_to include("b 1")
      expect(places(pdf, 0)["a 4"]).to eq([160, places(pdf, 0)["a 1"].last])
      expect(places(pdf, 1)["b 3"]).to eq([160, places(pdf, 1)["b 1"].last])
      expect(places(pdf, 1)["after"].last - places(pdf, 1)["b 2"].last).to be_within(0.01).of(line_height)
    end

    it "keeps a page break behind content that runs over the page" do
      node = columns(lines_of(30, prefix: "a"), Stationery::Layout::PageBreak.new, lines_of(2, prefix: "b"))
      pdf, = render_layout(node)

      expect(page_count(pdf)).to eq(3)
      expect(texts(pdf)[1]).to include("a 23", "a 30")
      expect(texts(pdf)[1]).not_to include("b 1")
      expect(texts(pdf)[2]).to include("b 1", "b 2")
    end

    it "starts on the next page when it begins with a page break" do
      node = columns(Stationery::Layout::PageBreak.new, lines_of(4))
      pdf, = render_layout(flow(text_node("above"), node))

      expect(node.leading_break?).to be(true)
      expect(texts(pdf)).to match([include("above"), include("line 1", "line 4")])
    end

    it "is empty when it holds nothing but page breaks" do
      head, tail = columns(Stationery::Layout::PageBreak.new).split(260, 160, fresh: true)

      expect(head.measure(260)).to eq(0)
      expect(tail).to be_nil
    end

    it "keeps a child too tall for a page and reports the overflow" do
      tall = Stationery::Layout::Box.new(flow(text_node("tall")), height: 300)
      pdf, paginator = render_layout(columns(tall, lines_of(30)))

      expect(paginator.warnings.map(&:class)).to eq([Stationery::Layout::Overflow])
      expect(paginator.warnings.first.to_h).to eq(page: 1, height: 300, available: 160)
      expect(texts(pdf)[0]).to include("tall", "line 1", "line 11")
      expect(texts(pdf).join).to include("line 30")
    end

    it "keeps content that no column can start, rather than looping" do
      stubborn = flow(lines_of(3))
      allow(stubborn).to receive_messages(split: [nil, stubborn], measure: 500)
      head, tail = described_class.new(stubborn).split(260, 160, fresh: true)

      expect(head.columns).to eq([stubborn])
      expect(tail).to be_nil
    end
  end

  describe "inside other nodes" do
    it "splits inside a box" do
      box = Stationery::Layout::Box.new(flow(text_node("title"), columns(lines_of(30))), padding: 5)
      pdf, paginator = render_layout(box)

      expect(page_count(pdf)).to eq(2)
      expect(places(pdf, 0)["line 1"].first).to eq(25)
      expect(places(pdf, 0)["line 1"].last).to eq(places(pdf, 0)["line 11"].last)
      expect(texts(pdf)[1]).to include("line 30")
      expect(paginator.warnings).to be_empty
    end

    it "holds another block of columns, which continues in the next column" do
      inner = columns(lines_of(4, prefix: "in"), gap: 10)
      pdf, paginator = render_layout(columns(lines_of(2, prefix: "out"), inner, lines_of(2, prefix: "end")))
      placed = places(pdf)

      expect(placed["in 2"]).to eq([placed["in 1"].first + 65, placed["in 1"].last])
      expect(placed["in 3"]).to eq([160, placed["out 1"].last])
      expect(placed["in 4"]).to eq([160 + 65, placed["out 1"].last])
      expect(placed["end 2"]).to eq([160, placed["in 1"].last])
      expect(paginator.warnings).to be_empty
    end

    it "keeps everything in one column when its content breaks more often than it has columns" do
      breaks = Array.new(3) { Stationery::Layout::PageBreak.new }
      node = columns(*breaks.zip(Array.new(3) { |i| text_node("part #{i}") }).flatten)

      expect(lines_in(node.fragment(260))).to eq([3])
    end

    it "is never split again once poured" do
      fragment = columns(lines_of(6)).fragment(260)

      expect(fragment.splittable?).to be(false)
      expect(fragment.split(260, 10)).to eq([nil, fragment])
    end
  end
end
