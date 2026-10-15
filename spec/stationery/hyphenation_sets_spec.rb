# frozen_string_literal: true

# The pattern sets are built once per Ractor, under the lock of the Memo that
# holds them (see Stationery::Store), never in a module instance variable
# that two threads could both find empty.
RSpec.describe Stationery::Hyphenation do
  describe ".patterns under contention" do
    # A fresh memo, and a build slow enough that every thread arrives while
    # the first is still building: without the lock each would build its own.
    before do
      allow(Stationery::Store).to receive(:fetch).and_call_original
      allow(Stationery::Store).to receive(:fetch).with(:stationery_hyphenation).and_return(Stationery::Memo.new)
      allow(described_class::Patterns).to receive(:new).and_wrap_original do |build, *args|
        3.times { Thread.pass }
        build.call(*args)
      end
    end

    let(:subject_call) { -> { described_class.patterns("de") } }

    it_behaves_like "thread-safe under contention", threads: 8, iterations: 5, consistent: :identical
  end

  it "keeps the pattern sets out of module instance variables" do
    described_class.patterns("sv")

    expect(described_class.instance_variables).to eq([])
  end

  it "builds a language once per Ractor" do
    expect(described_class.patterns("en")).to equal(described_class.patterns("en-us"))
  end

  describe "inside a non-main Ractor" do
    let(:subject_call) do
      # rubocop:disable-next RSpec/DescribedClass -- a Ractor's block reaches the module by its constant, not through self
      -> { [Stationery::Hyphenation.points("hyphenation", "en"), Stationery::Hyphenation.hyphenate("Silbentrennung", "de")] }
    end

    it_behaves_like "runs inside a non-main Ractor"
  end
end
