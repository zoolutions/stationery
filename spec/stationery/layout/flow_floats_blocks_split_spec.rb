# frozen_string_literal: true

# Boxes and list items that wrap beside floats, across pages. The page is
# 300 × 200 with a 20 pt margin: 160 pt of content height, eleven lines of
# Open Sans at 10 pt.
RSpec.describe Stationery::Layout::Flow do
  let(:words) { Array.new(200) { |i| "word#{i}" }.join(" ") }
  let(:ascent) { open_sans_book.resolve(base_style).first.ascender(10) }

  def block(width, height, **) = Stationery::Layout::Box.new(flow, width:, height:, **)
  def black(width, height) = Stationery::Layout::Floated.new(block(width, height, background: "#000000"), side: :left)

  def boxed(*children, break_inside: :auto, **)
    Stationery::Layout::Box.new(flow(*children), **).tap { |box| box.break_inside = break_inside }
  end

  def item(*children)
    Stationery::Layout::ListItem.new(text_node("1."), flow(*children), indent: 20, marker_gap: 4)
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

  describe "a box" do
    it "splits beside a float: narrow beside it, the full width below it and on the next page" do
      pdf, paginator = render_layout(flow(black(80, 60), boxed(text_node(words), padding: [0, 0, 0, 6])))

      expect(pages_of(pdf)[0].map(&:first)).to eq(([100.0] * 5) + ([26.0] * 6))
      expect(pages_of(pdf)[1].map(&:first).uniq).to eq([26.0])
      expect(pages_of(pdf)[1].first.last).to eq(20.0)
      expect(text_of(pdf).split).to eq(words.split)
      expect(paginator.warnings).to be_empty
    end

    it "splits with a background beside the float, which spans the full width on both pages" do
      box = boxed(text_node(words), background: "#EEEEEE", padding: [0, 0, 0, 6])
      pdf, paginator = render_layout(flow(black(80, 60), box))
      fills = page_contents(pdf).map do |content|
        content.scan(/^([\d.]+) ([\d.]+) ([\d.]+) ([\d.]+) re$/).map { |rect| rect.map(&:to_f) }
      end

      expect(fills[0].map { |x, _, w, _| [x, w] }).to eq([[20.0, 260.0], [20.0, 80.0]])
      expect(fills[0].first[1] + fills[0].first[3]).to eq(180.0)
      expect(fills[1].map { |x, y, w, h| [x, w, y + h] }).to eq([[20.0, 260.0, 180.0]])
      expect(pages_of(pdf)[0].map(&:first)).to eq(([100.0] * 5) + ([26.0] * 6))
      expect(pages_of(pdf)[1].map(&:first).uniq).to eq([26.0])
      expect(text_of(pdf).split).to eq(words.split)
      expect(paginator.warnings).to be_empty
    end

    it "wraps the lines a page break carries over again at the full width: the float stayed behind" do
      pdf, = render_layout(flow(lines_of(8), black(80, 40), boxed(text_node(words))))
      second = reader_for(pdf).pages[1].runs

      expect(pages_of(pdf)[0].last(3)).to eq([[100.0, nth_line(8)], [100.0, nth_line(9)], [100.0, nth_line(10)]])
      expect(pages_of(pdf)[1].first(5).map(&:first).uniq).to eq([20.0])
      expect(second.first.text.split.size).to be > reader_for(pdf).pages[0].runs.last.text.split.size
      expect(text_of(pdf).split.last(200)).to eq(words.split)
    end

    it "keeps the padding and the role of a box on both of its parts" do
      box = boxed(text_node(words), padding: 10, role: :section)
      head, tail = flow(black(80, 60), box).split(260, 160, fresh: true)

      expect(head.children.last.measure(260, exclusions: nil)).to be <= 160
      expect(head.children.last.tag).to equal(box.tag)
      expect(tail.children.first.tag).to equal(box.tag)
      expect(tail.children.first.wraps?).to be(true)
    end

    it "carries what is left of its floor over to the next page" do
      box = boxed(text_node(words.split.first(30).join(" ")), min_height: 300)
      head, tail = flow(black(80, 60), box).split(260, 160, fresh: true)

      expect(head.measure(260)).to be_within(0.001).of(160)
      expect(tail.measure(260)).to be_within(0.001).of(140)
    end

    it "moves to the next page whole when it prefers that, with the float written before it" do
      pdf, = render_layout(flow(lines_of(8), black(80, 40), boxed(lines_of(5, prefix: "boxed"), break_inside: nil)))

      expect(floats_of(pdf)).to eq([0, 1])
      expect(pages_of(pdf)[0].size).to eq(8)
      expect(pages_of(pdf)[1].first).to eq([100.0, 20.0])
    end

    it "never splits with break_inside: :avoid" do
      pdf, = render_layout(flow(lines_of(8), black(80, 40), boxed(lines_of(5, prefix: "boxed"), break_inside: :avoid)))

      expect(floats_of(pdf)).to eq([0, 1])
      expect(reader_for(pdf).pages[0].text).not_to include("boxed")
    end

    it "keeps a heading with the float and the box that follow it" do
      heading = text_node("Heading").tap { |node| node.keep_with_next = true }
      pdf, = render_layout(flow(spacer(100), heading, black(80, 60), boxed(text_node("beside"))))

      expect(floats_of(pdf)).to eq([0, 1])
      expect(reader_for(pdf).pages[0].text).not_to include("Heading")
      expect(pages_of(pdf)[1]).to eq([[20.0, 20.0], [100.0, nth_line(1)]])
    end

    it "stays with what follows it when it is told to" do
      box = boxed(text_node("boxed")).tap { |node| node.keep_with_next = true }
      pdf, = render_layout(flow(black(80, 20), spacer(140), box, lines_of(3)))

      expect(inspect_pdf(pdf).page_texts.last).to start_with("boxed")
    end

    it "honours orphans and widows inside it, counting the lines as they are wrapped again" do
      text = text_node(words.split.first(40).join(" "), widows: 3, orphans: 2)
      pdf, = render_layout(flow(lines_of(8), black(160, 40), boxed(text)))

      expect(reader_for(pdf).pages[0].runs.size - 8).to be >= 2
      expect(reader_for(pdf).pages[1].runs.size).to be >= 3
      expect(pages_of(pdf)[1].map(&:first).uniq).to eq([20.0])
    end

    # Fuzz seed 444 with float widths in points (#168): the list was placed
    # below the float for the wide float further down in it, and the part of
    # it cut for the room there was laid out beside the float, and ran over.
    it "keeps the part cut below a float there, where the whole was placed for what follows in it" do
      list = flow(boxed(text_node(words)), black(200, 20))
      pdf, paginator = render_layout(flow(black(150, 100), list))

      expect(pages_of(pdf)[0].map(&:first).uniq).to eq([20.0])
      expect(pages_of(pdf)[0].first.last).to eq(120.0)
      expect(pages_of(pdf)[1].first.last).to eq(20.0)
      expect(text_of(pdf).split).to eq(words.split)
      expect(paginator.warnings).to be_empty
    end

    it "measures the part it cut below a float as it was cut" do
      head, = flow(black(150, 100), flow(boxed(text_node(words)), black(200, 20))).split(260, 160, fresh: true)

      expect(head.measure(260)).to be <= 160
    end

    it "moves on whole when the orphans of its text do not fit beside the float" do
      pdf, = render_layout(flow(spacer(125), black(80, 30), boxed(text_node(words, orphans: 3))))

      expect(floats_of(pdf).first(2)).to eq([0, 1])
      expect(pages_of(pdf)[0]).to be_empty
      expect(pages_of(pdf)[1].first).to eq([100.0, 20.0])
    end
  end

  describe "a list item" do
    it "splits beside a float and wraps what it carries over at the full width" do
      pdf, paginator = render_layout(flow(black(80, 60), item(text_node(words))))

      expect(pages_of(pdf)[0].map(&:first)).to eq([100.0] + ([120.0] * 5) + ([40.0] * 6))
      expect(pages_of(pdf)[1].map(&:first).uniq).to eq([40.0])
      expect(text_of(pdf).split.drop(1)).to eq(words.split)
      expect(paginator.warnings).to be_empty
    end

    it "wraps the lines a page break cuts beside the float again" do
      pdf, = render_layout(flow(lines_of(8), black(80, 40), item(text_node(words))))

      expect(pages_of(pdf)[0].last(3).map(&:first)).to eq([120.0, 120.0, 120.0])
      expect(pages_of(pdf)[1].first(4).map(&:first).uniq).to eq([40.0])
      expect(reader_for(pdf).pages[1].runs.first.text.split.size)
        .to be > reader_for(pdf).pages[0].runs.last.text.split.size
    end

    it "keeps its marker on the first part only" do
      head, tail = flow(black(80, 60), item(text_node(words))).split(260, 160, fresh: true)

      expect(head.children.last.marker).not_to be_nil
      expect(tail.children.first.marker).to be_nil
    end
  end
end
