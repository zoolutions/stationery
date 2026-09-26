# frozen_string_literal: true

RSpec.describe Stationery::Layout::Row do
  def column(*children, **) = Stationery::Layout::Box.new(flow(*children), **)

  it "resolves point, fraction, auto and shared widths" do
    row = described_class.new(
      [column(width: 50), column(width: 0.25), column(text_node("auto"), width: :auto), column, column], gap: 10
    )
    widths = row.column_widths(460)
    auto = open_sans_book.resolve(base_style).first.width_of("auto", 10)

    expect(widths[0]).to eq(50)
    expect(widths[1]).to eq(0.25 * 420)
    expect(widths[2]).to be_within(0.01).of(auto)
    expect(widths[3]).to be_within(0.01).of((420 - 50 - 105 - auto) / 2)
    expect(widths.sum + 40).to be_within(0.01).of(460)
  end

  it "is as tall as its tallest column and never splits" do
    row = described_class.new([column(lines_of(3)), column(text_node("one"))])

    expect(row.measure(260)).to be_within(0.001).of(line_height * 3)
    expect(row.splittable?).to be(false)
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
end
