# frozen_string_literal: true

# A paragraph beside floats: every line is drawn, aligned and justified in
# the width it has, and what a page break carries over is wrapped again.
RSpec.describe Stationery::Text::Paragraph do
  let(:book) { open_sans_book }
  let(:canvas) { Stationery::Canvas.new(Stationery::Page.new(size: [300, 300]), Stationery::Resources.new) }
  let(:words) { Array.new(60) { |i| "word#{i}" }.join(" ") }
  let(:left) { exclusions(band(0, line_height * 2, 80, 0)) }

  def band(top, bottom, left, right) = Stationery::Text::Exclusions::Band.new(top:, bottom:, left:, right:)
  def exclusions(*bands) = Stationery::Text::Exclusions.new(bands)

  def paragraph(source, width: 200, **)
    described_class.new(Stationery::Text::Markup.parse(source, base_style), book:, width:, **)
  end

  # [x, width] of every canvas.text call, in drawing order.
  def draws(para)
    calls = []
    allow(canvas).to receive(:text).and_wrap_original do |original, string, **options|
      original.call(string, **options).tap { |width| calls << [options[:x], width] }
    end
    para.draw(canvas, 10, 10)
    calls
  end

  it "draws the lines beside a left float after it and the lines below it at the edge" do
    xs = draws(paragraph(words, exclusions: left)).map(&:first)

    expect(xs.first(4)).to eq([90, 90, 10, 10])
  end

  it "measures the lines it has, which are more than without the float" do
    beside = paragraph(words, exclusions: exclusions(band(0, line_height * 4, 120, 0)))

    expect(beside.lines.size).to be > paragraph(words).lines.size
    expect(beside.height).to be_within(0.001).of(beside.lines.size * line_height)
  end

  it "aligns every line inside its own width" do
    right = paragraph(words, align: :right, exclusions: exclusions(band(0, line_height * 2, 0, 80)))
    centre = paragraph(words, align: :center, exclusions: left)

    right.lines.zip(draws(right)).first(3).each_with_index do |(line, (x, _)), index|
      expect(x + line.width).to be_within(0.01).of(index < 2 ? 130 : 210)
    end
    first = centre.lines.first
    expect(draws(centre).first.first).to be_within(0.01).of(10 + 80 + ((120 - first.width) / 2))
  end

  it "justifies every soft-wrapped line to its own width" do
    para = paragraph(words, align: :justify, exclusions: left)

    para.lines.zip(draws(para)).first(4).each_with_index do |(_line, (x, width)), index|
      expect(x).to eq(index < 2 ? 90 : 10)
      expect(width).to be_within(0.01).of(index < 2 ? 120 : 200)
    end
  end

  it "counts its leading when it finds the lines beside the float" do
    para = paragraph(words, leading: 6, exclusions: exclusions(band(0, (line_height * 2) + 5, 80, 0)))

    expect(para.lines.map(&:offset).first(3)).to eq([80, 80, 0])
  end

  describe "split" do
    let(:tall) { exclusions(band(0, line_height * 6, 80, 0)) }

    it "keeps the lines beside the float and wraps what is carried over at the full width" do
      para = paragraph(words, exclusions: tall)
      head, tail = para.split((line_height * 3) + 1)

      expect(head.lines.map(&:offset)).to eq([80, 80, 80])
      expect(tail.lines.map(&:offset).uniq).to eq([0])
      expect(tail.lines.first.width).to be > 120
      expect((head.lines + tail.lines).map(&:text).join(" ")).to eq(words)
      expect(tail.lines.size).to be < para.lines.size - 3
    end

    it "splits at a count of lines the same way" do
      head, tail = paragraph(words, exclusions: tall).split_at(2)

      expect(head.lines.size).to eq(2)
      expect(draws(tail).map(&:first).uniq).to eq([10])
    end

    it "carries the lines over as they are when the float ended above the break" do
      para = paragraph(words, exclusions: left)
      allow(Stationery::Text::Wrapper).to receive(:new).and_call_original
      _head, tail = para.split((line_height * 3) + 1)

      expect(tail.lines).to eq(para.lines.drop(3))
      expect(Stationery::Text::Wrapper).not_to have_received(:new)
    end

    it "hands back the whole paragraph when everything or nothing fits" do
      para = paragraph(words, exclusions: tall)

      expect(para.split(1000)).to eq([para, nil])
      expect(para.split(1)).to eq([nil, para])
    end
  end
end
