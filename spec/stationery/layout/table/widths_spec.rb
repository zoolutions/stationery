# frozen_string_literal: true

RSpec.describe Stationery::Layout::Table::Widths do
  def resolve(spec, natural, min, target) = described_class.resolve(spec:, natural:, min:, target:)

  it "keeps fixed columns and shares the remainder among the others" do
    expect(resolve([nil, 55, 85], [30, 10, 10], [20, 5, 5], 300)).to eq([160, 55, 85])
  end

  it "shares extra space between several flexible columns in proportion to their natural width" do
    expect(resolve([nil, nil], [100, 50], [10, 10], 300)).to eq([200, 100])
  end

  it "shrinks flexible columns toward their minimum widths first" do
    widths = resolve([nil, nil], [200, 100], [50, 80], 200)

    expect(widths.sum).to be_within(0.001).of(200)
    expect(widths[1]).to be >= 80
  end

  it "goes below minimum widths only when it must" do
    widths = resolve([nil, nil], [200, 100], [150, 100], 100)

    expect(widths.sum).to be_within(0.001).of(100)
  end
end
