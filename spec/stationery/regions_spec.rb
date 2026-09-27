# frozen_string_literal: true

RSpec.describe Stationery::Regions do
  def region(slot = :header, on: :all, height: nil, gap: 0)
    Stationery::Region.new(slot:, height:, gap:, on:, block: proc {})
  end

  def regions(*entries, measure: ->(_region, _number) { 10 }) = described_class.new(entries, measure:)

  describe ".matches?" do
    {
      all: [1, 2, 3, 4], first: [1], rest: [2, 3, 4], odd: [1, 3], even: [2, 4],
      3 => [3], (2..3) => [2, 3], ->(n) { n > 2 } => [3, 4]
    }.each do |on, numbers|
      it "matches #{on.inspect} on pages #{numbers}" do
        expect((1..4).select { |n| described_class.matches?(on, n) }).to eq(numbers)
      end
    end
  end

  describe ".validate!" do
    it "accepts every selector form" do
      [:all, :first, :rest, :odd, :even, 2, (1..3), ->(n) { n > 1 }].each do |on|
        expect(described_class.validate!(on)).to eq(on)
      end
    end

    it "rejects unknown selectors" do
      expect { described_class.validate!(:sometimes) }.to raise_error(ArgumentError, /on:/)
      expect { described_class.validate!("first") }.to raise_error(ArgumentError, /on:/)
    end
  end

  describe "#entry_for" do
    it "lets the last matching declaration win" do
      all = region
      first = region(on: :first)
      set = regions(all, first, region(:footer))

      expect(set.entry_for(:header, 1)).to be(first)
      expect(set.entry_for(:header, 2)).to be(all)
      expect(set.entry_for(:footer, 2).slot).to eq(:footer)
    end

    it "returns nil when nothing matches" do
      expect(regions(region(on: :first)).entry_for(:header, 2)).to be_nil
    end
  end

  describe "#reserve" do
    it "reserves each slot's height plus its gap" do
      set = regions(region(gap: 8), region(:footer, height: 12, gap: 4))

      expect(set.reserve(1)).to eq([18, 16])
    end

    it "reserves nothing for a missing or empty region" do
      set = regions(region(on: :first, gap: 8), measure: ->(_region, _number) { 0 })

      expect(set.reserve(1)).to eq([0, 0])
      expect(set.reserve(2)).to eq([0, 0])
    end

    it "measures each declaration once, at the first page that asks" do
      calls = []
      set = regions(region(gap: 8), measure: lambda { |_region, number|
        calls << number
        10
      })

      3.times { |i| set.reserve(i + 2) }
      expect(calls).to eq([2])
    end

    it "skips measuring when the height is given" do
      measure = ->(*) { raise "measured" }

      expect(regions(region(height: 30), measure:).reserve(1)).to eq([30, 0])
    end
  end
end
