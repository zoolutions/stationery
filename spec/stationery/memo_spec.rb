# frozen_string_literal: true

RSpec.describe Stationery::Memo do
  let(:one) { Object.new }

  it "builds a value once per key" do
    memo = described_class.new
    built = memo.fetch(:a) { Object.new }

    expect(memo.fetch(:a) { Object.new }).to equal(built)
    expect(memo).to be_key(:a)
  end

  it "starts over once it holds its limit" do
    memo = described_class.new(limit: 2)
    %i[a b c].each { |key| memo.fetch(key) { one } }

    expect(memo.size).to eq(1)
    expect(memo).to be_key(:c)
  end

  it "keeps what a full memo holds when a block raises" do
    memo = described_class.new(limit: 2)
    %i[a b].each { |key| memo.fetch(key) { one } }

    expect { memo.fetch(:c) { raise ArgumentError } }.to raise_error(ArgumentError)
    expect(memo.size).to eq(2)
  end

  it "stores nothing for a block that raises, and clears" do
    memo = described_class.new

    expect { memo.fetch(:a) { raise ArgumentError } }.to raise_error(ArgumentError)
    expect(memo).not_to be_key(:a)

    memo.fetch(:a) { one }
    memo.clear
    expect(memo.size).to eq(0)
  end

  describe "from many threads" do
    let(:subject_call) do
      memo = described_class.new
      lambda do
        memo.fetch(:key) do
          Thread.pass
          Object.new
        end
      end
    end

    it_behaves_like "thread-safe under contention", threads: 8, iterations: 5, consistent: :identical
  end
end
