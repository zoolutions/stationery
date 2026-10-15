# frozen_string_literal: true

RSpec.describe Stationery::Store do
  it "builds a value once and hands every later fetch the same object" do
    builds = 0
    build = proc do
      builds += 1
      Object.new
    end
    built = described_class.fetch(:stationery_spec_store_once, &build)

    expect(described_class.fetch(:stationery_spec_store_once, &build)).to equal(built)
    expect(builds).to eq(1)
  end

  it "is Ractor.store_if_absent where Ruby has it", if: defined?(Ractor) && Ractor.respond_to?(:store_if_absent) do
    built = Ractor.store_if_absent(:stationery_spec_native) { Object.new }

    expect(described_class).to be_native
    expect(described_class.fetch(:stationery_spec_native) { Object.new }).to be(built)
  end

  describe Stationery::Store::Locked do
    it "stores nothing for a block that raises" do
      store = described_class.new

      built = Object.new

      expect { store.fetch(:key) { raise ArgumentError } }.to raise_error(ArgumentError)
      expect(store.fetch(:key) { built }).to be(built)
    end

    describe "from many threads" do
      # One store; a build that yields, so every thread arrives while the
      # first is still building: without the lock each would build its own.
      let(:subject_call) do
        store = described_class.new
        lambda do
          store.fetch(:key) do
            Thread.pass
            Object.new
          end
        end
      end

      it_behaves_like "thread-safe under contention", threads: 8, iterations: 5, consistent: :identical
    end
  end
end
