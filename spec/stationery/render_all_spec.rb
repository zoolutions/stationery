# frozen_string_literal: true

# Stationery.render_all where no Ractor is started: below Ruby 4.0, or with
# `ractors: 1`, it renders on the main Ractor. The renders across Ractors are
# in spec/integration/render_all_spec.rb, tagged :ractor.
RSpec.describe Stationery, ".render_all" do
  let(:documents) { [CanaryDocuments::Letter.new(["First"]), CanaryDocuments::Letter.new(%w[Second Third])] }
  let(:sequential) { documents.map(&:to_pdf) }

  context "without Ractor#value (below Ruby 4.0)" do
    before { allow(Stationery::Parallel).to receive(:available?).and_return(false) }

    it "renders each document on the main Ractor, in order, as to_pdf does" do
      allow(Ractor).to receive(:new) if defined?(Ractor)

      expect(described_class.render_all(documents, ractors: 4)).to eq(sequential)
      expect(Ractor).not_to have_received(:new) if defined?(Ractor)
    end
  end

  context "with one Ractor" do
    it "renders on the main Ractor" do
      allow(Ractor).to receive(:new) if defined?(Ractor)

      expect(described_class.render_all(documents, ractors: 1)).to eq(sequential)
      expect(Ractor).not_to have_received(:new) if defined?(Ractor)
    end
  end

  it "passes its options to every to_pdf" do
    allow(Stationery::Parallel).to receive(:available?).and_return(false)
    pdfs = described_class.render_all(documents, ractors: 2, tagged: true)

    expect(pdfs).to eq(documents.map { it.to_pdf(tagged: true) })
    expect(pdfs.first).to have_structure([[:Document, [[:P, "First"]]]])
  end

  describe "its event" do
    let(:events) { [] }
    let(:recorder) do
      events = self.events
      Object.new.tap do |recorder|
        recorder.define_singleton_method(:instrument) do |name, payload = {}, &block|
          block.call(payload).tap { events << [name, payload] }
        end
      end
    end

    before { described_class.instrumenter = recorder }
    after { described_class.instrumenter = nil }

    it "is render_all.stationery, around the renders, naming the documents rendered on the main Ractor" do
      described_class.render_all(documents, ractors: 4)

      expect(events.map(&:first).grep(/\Arender/)).to eq(%w[render.stationery render.stationery render_all.stationery])
      expect(events.last.last).to eq(documents: 2, ractors: 0, main_ractor: [0, 1])
    end
  end

  it "answers an empty Array for no documents" do
    expect(described_class.render_all([], ractors: 4)).to eq([])
  end

  it "uses as many Ractors as the machine has processors by default" do
    expect(Stationery::Parallel.default_ractors).to eq(Etc.nprocessors)
  end

  [0, -1, 1.5, "2", nil].each do |count|
    it "refuses ractors: #{count.inspect}" do
      expect { described_class.render_all(documents, ractors: count) }
        .to raise_error(ArgumentError, /ractors: must be a positive Integer, not #{Regexp.escape(count.inspect)}/)
    end
  end

  it "raises what to_pdf raises" do
    broken = Class.new(Stationery::Document) { def view_template = raise(ArgumentError, "no lines") }

    expect { described_class.render_all([broken.new], ractors: 1) }.to raise_error(ArgumentError, "no lines")
  end
end
