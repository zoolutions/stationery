# frozen_string_literal: true

RSpec.describe Stationery::Text::Exclusions do
  def band(top, bottom, left, right) = described_class::Band.new(top:, bottom:, left:, right:)

  it "is nothing when there are no bands" do
    expect(described_class.of([])).to be_nil
    expect(described_class.of([band(0, 10, 5, 0)]).bands.size).to eq(1)
  end

  it "insets a line by the bands it overlaps" do
    exclusions = described_class.new([band(0, 30, 50, 0), band(20, 60, 0, 40)])

    expect(exclusions.insets(0, 12)).to eq([50, 0])
    expect(exclusions.insets(12, 12)).to eq([50, 40])
    expect(exclusions.insets(30, 12)).to eq([0, 40])
    expect(exclusions.insets(60, 12)).to eq([0, 0])
  end

  it "takes the widest band on each side" do
    exclusions = described_class.new([band(0, 30, 50, 0), band(0, 30, 80, 10)])

    expect(exclusions.insets(10, 12)).to eq([80, 10])
  end

  it "leaves a line that only touches a band alone" do
    exclusions = described_class.new([band(12, 24, 50, 0)])

    expect(exclusions.insets(0, 12)).to eq([0, 0])
    expect(exclusions.insets(24, 12)).to eq([0, 0])
  end

  describe "#inset" do
    it "is what the bands take inside a rectangle that starts further down and further in" do
      exclusions = described_class.new([band(0, 30, 50, 0), band(20, 60, 0, 40)])

      expect(exclusions.inset(top: 5, right: 10, left: 8).bands).to eq([band(0, 25, 42, 0), band(15, 55, 0, 30)])
      expect(exclusions.inset(top: 0, right: 0, left: 0)).to eq(exclusions)
    end

    it "leaves out a band that ends above the rectangle or takes nothing from it" do
      exclusions = described_class.new([band(0, 30, 50, 0), band(20, 60, 0, 40)])

      expect(exclusions.inset(top: 30, right: 0, left: 0).bands).to eq([band(0, 30, 0, 40)])
      expect(exclusions.inset(top: 0, right: 40, left: 0).bands).to eq([band(0, 30, 50, 0)])
    end

    it "is nothing when no band is left" do
      exclusions = described_class.new([band(0, 30, 50, 0)])

      expect(exclusions.inset(top: 30, right: 0, left: 0)).to be_nil
      expect(exclusions.inset(top: 0, right: 0, left: 50)).to be_nil
    end
  end

  it "compares and hashes by its bands, so it can key a memo" do
    one = described_class.new([band(0, 30, 50, 0)])
    same = described_class.new([band(0, 30, 50, 0)])
    other = described_class.new([band(0, 31, 50, 0)])

    expect(one).to eq(same)
    expect({ [200, one] => :hit }[[200, same]]).to eq(:hit)
    expect(one).not_to eq(other)
  end
end
