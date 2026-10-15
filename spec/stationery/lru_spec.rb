# frozen_string_literal: true

RSpec.describe Stationery::LRU do
  subject(:lru) { described_class.new(2) }

  let(:one) { Object.new }
  let(:two) { Object.new }

  def held(key) = lru.fetch(key) { |value| value }

  it "hands the block the value it holds, nil the first time" do
    expect(lru.fetch(:a) { |value| value || one }).to be(one)
    expect(held(:a)).to be(one)
  end

  it "keeps the value the block answers, so a stale one is replaced" do
    lru.fetch(:a) { one }

    expect(lru.fetch(:a) { |value| value.equal?(one) ? two : value }).to be(two)
    expect(held(:a)).to be(two)
  end

  it "lets the least recently used entry go past its size" do
    lru.fetch(:a) { one }
    lru.fetch(:b) { two }
    held(:a)
    lru.fetch(:c) { two }

    expect(lru.size).to eq(2)
    expect(held(:a)).to be(one)
    expect(held(:b)).to be_nil
  end

  it "stores nothing for a block that raises, and clears" do
    expect { lru.fetch(:a) { raise ArgumentError } }.to raise_error(ArgumentError)
    expect(lru.size).to eq(0)

    lru.fetch(:a) { one }
    lru.clear
    expect(lru.size).to eq(0)
  end

  describe "from many threads" do
    let(:subject_call) do
      cache = described_class.new(4)
      lambda do
        cache.fetch(:key) do |value|
          Thread.pass
          value || Object.new
        end
      end
    end

    it_behaves_like "thread-safe under contention", threads: 8, iterations: 5, consistent: :identical
  end
end
