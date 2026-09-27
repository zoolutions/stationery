# frozen_string_literal: true

RSpec.describe Stationery::Layout::Row do
  def column(*children, **) = Stationery::Layout::Box.new(flow(*children), **)

  it "resolves point, fraction, auto and shared widths" do
    row = described_class.new(
      [column(width: 50), column(width: 0.25), column(text_node("auto"), width: :auto), column, column], gap: 10
    )
    widths = row.column_widths(460)
    auto = open_sans_book.resolve(base_style).first.width_of("auto", 10, kerning: true)

    expect(widths[0]).to eq(50)
    expect(widths[1]).to eq(0.25 * 420)
    expect(widths[2]).to be_within(0.01).of(auto)
    expect(widths[3]).to be_within(0.01).of((420 - 50 - 105 - auto) / 2)
    expect(widths.sum + 40).to be_within(0.01).of(460)
  end

  it "is as tall as its tallest column" do
    row = described_class.new([column(lines_of(3)), column(text_node("one"))])

    expect(row.measure(260)).to be_within(0.001).of(line_height * 3)
    expect(row.splittable?).to be(true)
  end

  it "places columns side by side and aligns them vertically" do
    row = described_class.new([column(lines_of(3), width: 0.5), column(text_node("mid"), width: 0.5)], align: :middle)
    pdf, = render_layout(row)
    positions = positions_of(pdf)
    mid = positions.last

    expect(mid.first).to be_within(0.01).of(20 + 130)
    expect(mid.last).to be_within(0.01).of(positions[1].last)
  end

  it "stretches column backgrounds to the row height" do
    row = described_class.new([column(lines_of(3), background: "#EEEEEE"),
                               column(text_node("x"), background: "#DDDDDD")])
    pdf, = render_layout(row)
    heights = page_contents(pdf).first.scan(/[\d.]+ [\d.]+ [\d.]+ ([\d.]+) re\nf/).flatten.map(&:to_f)

    expect(heights.uniq.size).to eq(1)
  end

  describe "across pages" do
    def tall_row(**) = described_class.new([column(lines_of(20, prefix: "a")), column(lines_of(20, prefix: "b"))], **)
    def rect_heights(content) = content.scan(/[\d.]+ [\d.]+ [\d.]+ ([\d.]+) re\nf/).flatten.map(&:to_f)

    it "continues every column on the next page" do
      pdf, paginator = render_layout(tall_row)
      first, second = reader_for(pdf).pages

      expect(page_count(pdf)).to eq(2)
      expect(first.text).to include("a 1", "b 1")
      expect(first.text).not_to include("a 20", "b 20")
      expect(second.text).to include("a 20", "b 20")
      expect(paginator.warnings).to be_empty
    end

    it "keeps a short column's background as tall as the fragment" do
      row = described_class.new([column(lines_of(20), background: "#EEEEEE"),
                                 column(text_node("x"), background: "#DDDDDD")])
      pdf, = render_layout(row)
      heights = rect_heights(page_contents(pdf)[1])

      expect(heights.size).to eq(2)
      expect(heights.uniq.size).to eq(1)
      expect(rect_heights(page_contents(pdf)[0]).uniq.size).to eq(1)
    end

    it "moves whole when a column cannot start in the space left" do
      row = described_class.new([column(lines_of(20), padding: [20, 0, 0, 0]), column(lines_of(20))])

      expect(row.split(260, 15)).to eq([nil, row])
    end

    it "moves whole when a column that does not fit avoids breaking inside" do
      kept = column(lines_of(20)).tap { |c| c.break_inside = :avoid }
      row = described_class.new([column(lines_of(20)), kept])

      expect(row.split(260, 100)).to eq([nil, row])
    end

    it "never splits with a fixed-height column" do
      row = described_class.new([column(lines_of(20)), column(text_node("x"), height: 20)])
      pdf, paginator = render_layout(row)

      expect(row.splittable?).to be(false)
      expect(page_count(pdf)).to eq(1)
      expect(paginator.warnings.size).to eq(1)
    end

    it "never splits with break_inside: :avoid" do
      pdf, paginator = render_layout(tall_row.tap { |row| row.break_inside = :avoid })

      expect(page_count(pdf)).to eq(1)
      expect(paginator.warnings.size).to eq(1)
    end

    it "moves whole to the next page when it fits there" do
      row = described_class.new([column(lines_of(5)), column(text_node("side"))])
      pdf, = render_layout(flow(spacer(120), row))

      expect(reader_for(pdf).pages[0].text).to be_empty
      expect(reader_for(pdf).pages[1].text).to include("line 1", "side")
    end

    it "splits below other content with break_inside: :auto, keep_with_next on the tail" do
      row = tall_row.tap do |r|
        r.break_inside = :auto
        r.keep_with_next = true
      end
      head, tail = row.split(260, 100)
      pdf, = render_layout(flow(spacer(100), row))

      expect([head.keep_with_next, tail.keep_with_next]).to eq([nil, true])
      expect(reader_for(pdf).pages[0].text).to include("a 1", "b 1")
    end

    it "aligns each fragment's columns" do
      row = described_class.new([column(lines_of(20)), column(text_node("mid"))], align: :middle)
      pdf, paginator = render_layout(row)

      expect(reader_for(pdf).pages[0].text).to include("mid")
      expect(paginator.warnings).to be_empty
    end
  end
end
