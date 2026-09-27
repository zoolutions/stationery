# frozen_string_literal: true

RSpec.describe Stationery::ListMarkers do
  def label(format, number, suffix = ".") = described_class.label(format, number, suffix)

  it "numbers in decimal with a suffix" do
    expect(label(:decimal, 3)).to eq("3.")
    expect(label(:decimal, 12, ")")).to eq("12)")
    expect(label(:decimal, 1, "")).to eq("1")
  end

  it "letters bijectively, lower and upper case" do
    expect([1, 26, 27, 52, 703].map { |n| label(:alpha, n, "") }).to eq(%w[a z aa az aaa])
    expect(label(:upper_alpha, 28)).to eq("AB.")
  end

  it "writes roman numerals, lower and upper case" do
    expect([1, 4, 9, 14, 40, 90, 400, 1994, 3999].map { |n| label(:roman, n, "") })
      .to eq(%w[i iv ix xiv xl xc cd mcmxciv mmmcmxcix])
    expect(label(:upper_roman, 1994)).to eq("MCMXCIV.")
  end

  it "falls back to decimal where a format has no numeral" do
    expect([label(:alpha, 0), label(:roman, 0), label(:roman, -2), label(:upper_roman, 4000)])
      .to eq(%w[0. 0. -2. 4000.])
  end

  it "calls a proc with the number" do
    expect(label(->(n) { "Step #{n}" }, 2, ":")).to eq("Step 2:")
  end

  it "rejects an unknown format" do
    expect { label(:greek, 1) }.to raise_error(ArgumentError, /greek/)
  end
end
