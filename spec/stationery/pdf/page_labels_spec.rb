# frozen_string_literal: true

RSpec.describe Stationery::PDF::PageLabels do
  def entries(spec) = described_class.entries(spec)
  def text(value) = Stationery::PDF::TextString.new(value)

  it "writes a number tree keyed by 0-based page index with the PDF style names" do
    expect(entries(1 => { style: :roman_lower }, 3 => { style: :decimal, start: 1, prefix: "A-" }))
      .to eq(Nums: [0, { S: :r }, 2, { S: :D, St: 1, P: text("A-") }])
  end

  it "maps every style, and a nil style writes a prefix-only label" do
    styles = { decimal: :D, roman: :R, roman_lower: :r, alpha: :A, alpha_lower: :a }
    styles.each { |style, name| expect(entries(1 => { style: })).to eq(Nums: [0, { S: name }]) }
    expect(entries(1 => { prefix: "Cover" })).to eq(Nums: [0, { P: text("Cover") }])
    expect(entries(1 => { style: nil, prefix: "Cover" })).to eq(Nums: [0, { P: text("Cover") }])
  end

  it "sorts ranges by page and keeps a first range that does not start at page 1" do
    expect(entries(5 => { style: :decimal }, 2 => { style: :roman_lower }))
      .to eq(Nums: [1, { S: :r }, 4, { S: :D }])
  end

  it "returns nil for no labels" do
    expect(entries(nil)).to be_nil
    expect(entries({})).to be_nil
  end

  it "rejects pages below 1, unknown styles and a start below 1" do
    expect { entries(0 => { style: :decimal }) }.to raise_error(ArgumentError, /page 0/)
    expect { entries("1" => { style: :decimal }) }.to raise_error(ArgumentError, /page "1"/)
    expect { entries(1 => { style: :bogus }) }.to raise_error(ArgumentError, /style :bogus/)
    expect { entries(1 => { style: :decimal, start: 0 }) }.to raise_error(ArgumentError, /start 0/)
    expect { entries(1 => { colour: :red }) }.to raise_error(ArgumentError, /colour/)
  end

  it "reads labels back per page from a number tree" do
    nums = [0, { S: :r }, 2, { S: :D, St: 1, P: "A-" }, 4, { P: "Cover" }]

    expect(described_class.labels(nums, 6)).to eq(%w[i ii A-1 A-2 Cover Cover])
    expect(described_class.labels([1, { S: :R }], 3)).to eq([nil, "I", "II"])
    expect(described_class.labels([0, { S: :a, St: 26 }], 2)).to eq(%w[z aa])
  end
end
