# frozen_string_literal: true

RSpec.describe Stationery::Text::Paragraph do
  let(:book) { open_sans_book }
  let(:resources) { Stationery::Resources.new }
  let(:page) { Stationery::Page.new(size: [300, 300]) }
  let(:canvas) { Stationery::Canvas.new(page, resources) }

  def paragraph(source, width: 200, **)
    described_class.new(Stationery::Text::Markup.parse(source, base_style), book:, width:, **)
  end

  def render(para, x: 10, y: 10)
    para.draw(canvas, x, y)
    Stationery::PDF::Assembler.new(pages: [page], resources:).render
  end

  it "reports its height as the sum of its lines plus leading between them" do
    one = paragraph("one")
    three = paragraph("one\ntwo\nthree", leading: 4)

    expect(three.height).to be_within(0.001).of((one.height * 3) + 8)
  end

  it "draws each line so the text extracts in order" do
    pdf = render(paragraph("first line\nsecond line"))

    expect(strings_of(pdf)).to eq(["first line", "second line"])
  end

  it "aligns lines right and centre inside its width" do
    right = positions_of(render(paragraph("x", align: :right))).first
    font = book.resolve(base_style).first

    expect(right.first).to be_within(0.01).of(10 + 200 - font.width_of("x", 10))
  end

  it "splits by whole lines to fit a height, returning the remainder" do
    para = paragraph("a\nb\nc\nd")
    line = para.lines.first.height
    head, tail = para.split((line * 2) + 1)

    expect(head.lines.size).to eq(2)
    expect(tail.lines.size).to eq(2)
    expect(para.split(line * 10)).to eq([para, nil])
    expect(para.split(1)).to eq([nil, para])
  end

  it "creates link annotations over linked fragments only" do
    pdf = render(paragraph("see <link href='https://x.test'>here</link> now"))

    expect(link_rects(pdf).size).to eq(1)
    expect(pdf).to include("/URI (https://x.test)")
  end

  describe "fitting a fixed height" do
    let(:long) { Array.new(40) { "word" }.join(" ") }

    it "truncates at the last whole line that fits" do
      para = paragraph(long, width: 100).fit(30, overflow: :truncate)

      expect(para.height).to be <= 30
      expect(para.lines).not_to be_empty
    end

    it "shrinks the text until it fits, never below 4pt" do
      para = paragraph(long, width: 100).fit(40, overflow: :shrink_to_fit)

      expect(para.height).to be <= 40
      expect(para.lines.first.fragments.first.style.size).to be < 10
      tiny = paragraph(long * 20, width: 100).fit(5, overflow: :shrink_to_fit)
      expect(tiny.lines.first.fragments.first.style.size).to eq(4)
    end

    it "leaves the paragraph alone when it already fits or overflow is visible" do
      para = paragraph("short")

      expect(para.fit(100, overflow: :shrink_to_fit)).to equal(para)
      expect(paragraph(long, width: 100).fit(10, overflow: :visible).height).to be > 10
    end
  end
end
