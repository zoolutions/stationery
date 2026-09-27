# frozen_string_literal: true

RSpec.describe Stationery::Layout::Wrap do
  def chip(label, width: :auto) = Stationery::Layout::Box.new(flow(text_node(label)), width:, padding: [2, 6])

  it "places children side by side and wraps them onto new rows" do
    node = described_class.new(Array.new(6) { |i| chip("chip #{i}", width: 90) }, gap: 10, row_gap: 4)

    expect(node.rows(260).map(&:size)).to eq([2, 2, 2])
    expect(node.measure(260)).to be_within(0.01).of((chip("x").measure(90) * 3) + 8)
  end

  it "aligns each row" do
    pdf, = render_layout(described_class.new([chip("one", width: 60)], align: :center))

    expect(positions_of(pdf).first.first).to be_within(0.01).of(20 + 100 + 6)
  end

  it "splits between rows" do
    node = described_class.new(Array.new(40) { |i| chip("chip #{i}", width: 120) }, row_gap: 4)
    pdf, paginator = render_layout(node)

    expect(page_count(pdf)).to be > 1
    expect(text_of(pdf).scan(/chip \d+/).uniq.size).to eq(40)
    expect(paginator.warnings).to be_empty
  end

  it "reports a natural width of one row and a minimum of its widest child" do
    node = described_class.new([chip("a", width: 50), chip("b", width: 70)], gap: 5)

    expect(node.natural_width).to eq(125)
    expect(node.min_width).to eq(70)
  end
end
