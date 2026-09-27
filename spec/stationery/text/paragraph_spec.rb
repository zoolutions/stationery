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

    expect(right.first).to be_within(0.01).of(10 + 200 - font.width_of("x", 10, kerning: true))
  end

  it "kerns by default, and the kerned text still extracts" do
    pdf = render(paragraph("AVA"))

    expect(page_contents(pdf).first).to include("] TJ")
    expect(text_of(pdf)).to eq("AVA")
  end

  it "draws plain strings with kerning off" do
    plain = described_class.new([Stationery::Text::Run.new("AVA", base_style(kerning: false))], book:, width: 200)
    content = page_contents(render(plain)).first

    expect(content).to include("> Tj")
    expect(content).not_to include("TJ")
  end

  it "wraps with kerned widths" do
    font = book.resolve(base_style).first
    para = paragraph("AVAVAV AVAVAV", width: font.width_of("AVAVAV AVAVAV", 10, kerning: true) + 0.01)

    expect(para.lines.size).to eq(1)
    expect(para.lines.first.width).to be_within(1e-9).of(font.width_of("AVAVAV AVAVAV", 10, kerning: true))
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

  describe "justification" do
    let(:long) { "The quick brown fox jumps over the lazy dog and keeps running far beyond the hills." }

    # [x, width] of every canvas.text call, in drawing order.
    def draws(para)
      calls = []
      allow(canvas).to receive(:text).and_wrap_original do |original, string, **options|
        original.call(string, **options).tap { |width| calls << [options[:x], width] }
      end
      para.draw(canvas, 10, 10)
      calls
    end

    # Renders on a page of its own, so annotations from other renders stay out.
    def render_alone(para)
      page = Stationery::Page.new(size: [300, 300])
      resources = Stationery::Resources.new
      para.draw(Stationery::Canvas.new(page, resources), 10, 10)
      Stationery::PDF::Assembler.new(pages: [page], resources:).render
    end

    it "stretches the spaces of every soft-wrapped line to the full width" do
      para = paragraph(long, align: :justify)
      calls = draws(para)

      expect(para.lines.size).to be > 2
      para.lines[0...-1].zip(calls).each do |line, (x, width)|
        expect(line).to be_justifiable
        expect(x + width).to be_within(0.01).of(210)
      end
    end

    it "left-aligns the last line" do
      para = paragraph(long, align: :justify)
      x, width = draws(para).last

      expect(x).to eq(10)
      expect(width).to be_within(0.001).of(para.lines.last.width)
    end

    it "leaves lines without spaces alone" do
      para = paragraph("Supercalifragilisticexpialidocious", width: 60, align: :justify)
      calls = draws(para)

      expect(para.lines.size).to be > 1
      para.lines.zip(calls).each { |line, (_x, width)| expect(width).to be_within(0.001).of(line.width) }
    end

    it "moves later fragments right by the stretch of the spaces before them" do
      para = paragraph("a <b>bold</b> b c d e f g h i j k l m n o p q r s t u v w x y z end", align: :justify)
      line = para.lines.first
      extra = (200 - line.width) / line.space_count
      second = line.fragments[1]

      expect(draws(para)[1].first).to be_within(0.01).of(10 + second.x + extra)
    end

    it "widens link rectangles over stretched spaces" do
      source = "<link href='https://x.test'>#{long}</link>"
      left = link_rects(render_alone(paragraph(source))).first
      justified = link_rects(render_alone(paragraph(source, align: :justify))).first

      expect(justified[2] - justified[0]).to be_within(0.01).of(200)
      expect(justified[2] - justified[0]).to be > left[2] - left[0]
    end
  end
end
