# frozen_string_literal: true

# Stationery.render_all across Ractors (Ruby 4.0 and later, Ractor#value):
# each Ractor renders its share of the documents with caches of its own, and
# the PDFs come back in order, the bytes the main Ractor writes for them.
# Tagged :ractor, so it runs in a process of its own (spec_helper.rb).
RSpec.describe "Stationery.render_all across Ractors", :ractor do
  before do
    skip "needs Ruby 4.0+ (Ractor#value)" unless Stationery::Parallel.available?
  end

  let(:documents) do
    Array.new(7) do |index|
      if index.even?
        CanaryDocuments::PinnedReport.new
      else
        CanaryDocuments::Letter.new(["Letter #{index}", "The quick brown fox. " * index])
      end
    end
  end

  # Writes which Ractor rendered it.
  let(:where) do
    Class.new(Stationery::Document) do
      def view_template = text(Ractor.main? ? "on the main Ractor" : "on another Ractor")
    end.finalize!
  end

  it "answers each document's PDF, in order, byte for byte what to_pdf writes" do
    expect(Stationery.render_all(documents, ractors: 3)).to eq(documents.map(&:to_pdf))
  end

  it "renders each document in a Ractor other than the main one" do
    expect(Stationery.render_all(Array.new(4) { where.new }, ractors: 2))
      .to all(have_pdf_text_on_page(1, "on another Ractor"))
  end

  it "starts as many Ractors as it is given" do
    allow(Ractor).to receive(:new).and_call_original

    Stationery.render_all(documents, ractors: 3)

    expect(Ractor).to have_received(:new).exactly(3).times
  end

  it "starts no more Ractors than there are documents" do
    allow(Ractor).to receive(:new).and_call_original

    Stationery.render_all(documents.first(2), ractors: 8)

    expect(Ractor).to have_received(:new).twice
  end

  it "passes its options to every to_pdf" do
    expect(Stationery.render_all(documents, ractors: 2, tagged: true))
      .to eq(documents.map { it.to_pdf(tagged: true) })
  end

  # Keeps what it records in a module instance variable, as
  # ActiveSupport::Notifications keeps its notifier: a Module, so shareable,
  # whose state no Ractor but the main one can read.
  describe "under an instrumenter only the main Ractor can call" do
    let(:recorder) do
      Module.new do
        @events = []

        class << self
          attr_reader :events

          def instrument(name, payload = {}) = yield(payload).tap { events << [name, payload] }
        end
      end
    end

    before { Stationery.instrumenter = recorder }
    after { Stationery.instrumenter = nil }

    it "renders in the Ractors, which report nothing, and reports the batch from the main Ractor" do
      pdfs = Stationery.render_all([where.new, where.new], ractors: 2)

      expect(pdfs.map { text_of(it) }).to all(eq("on another Ractor"))
      expect(recorder.events).to eq([["render_all.stationery", { documents: 2, ractors: 2, main_ractor: [] }]])
    end

    it "says which documents the main Ractor rendered" do
      stamp = +"draft"
      main_only = Class.new(where) { footer { |_page| text stamp } }.finalize!
      Stationery.render_all([where.new, main_only.new, where.new, where.new], ractors: 2)

      expect(recorder.events.last).to eq(["render_all.stationery", { documents: 4, ractors: 2, main_ractor: [1] }])
    end

    it "lets a render inside a Ractor started by hand report nothing either" do
      pdf = Ractor.new { CanaryDocuments::Letter.new(["By hand"]).to_pdf }.value

      expect(pdf).to eq(CanaryDocuments::Letter.new(["By hand"]).to_pdf)
    end
  end

  describe "a document a Ractor cannot take" do
    it "is rendered on the main Ractor when its class's settings are not shareable" do
      stamp = +"draft" # a footer that reads it keeps the class's settings for the main Ractor
      main_only = Class.new(where) { footer { |_page| text stamp } }.finalize!
      pdfs = Stationery.render_all([where.new, main_only.new, where.new], ractors: 2)

      expect(Ractor.shareable?(main_only.config)).to be(false)
      expect(pdfs.map { text_of(it) }).to eq(["on another Ractor", "on the main Ractor draft", "on another Ractor"])
    end

    it "is rendered on the main Ractor when it cannot be copied, and the rest of its share in the Ractor" do
      uncopyable = where.new.tap { it.instance_variable_set(:@hook, -> { :never_called }) }
      pdfs = Stationery.render_all([where.new, where.new, uncopyable, where.new, where.new], ractors: 2)

      ractor = "on another Ractor"
      expect(pdfs.map { text_of(it) }).to eq([ractor, ractor, "on the main Ractor", ractor, ractor])
    end

    it "renders in a Ractor once it has been rendered with a shaper that cannot be copied" do
      rendered = where.new.tap { it.to_pdf(shaper: FakeShapers::Recording.new) }

      expect(text_of(Stationery.render_all([rendered, where.new], ractors: 2).first)).to eq("on another Ractor")
    end

    it "is rendered on the main Ractor with every other document when the options cannot be copied" do
      pdfs = Stationery.render_all([where.new, where.new], ractors: 2, shaper: FakeShapers::Recording.new)

      expect(pdfs.map { text_of(it) }).to all(eq("on the main Ractor"))
    end

    it "is rendered on the main Ractor when its view reaches what a Ractor cannot" do
      stub_const("CanaryDocuments::UNSHAREABLE", +"from a constant")
      reaching = Class.new(where) do
        def view_template
          super
          text CanaryDocuments::UNSHAREABLE
        end
      end.finalize!
      pdfs = Stationery.render_all([where.new, where.new, reaching.new], ractors: 2)

      expect(pdfs.map { text_of(it) })
        .to eq(["on another Ractor", "on another Ractor", "on the main Ractor from a constant"])
    end
  end

  it "raises an error that is not a StandardError from the main Ractor, not as a Ractor::RemoteError" do
    deep = Class.new(Stationery::Document) { def view_template = raise(SystemStackError, "too deep") }.finalize!

    expect { Stationery.render_all([documents.first, deep.new], ractors: 2) }
      .to raise_error(SystemStackError, "too deep")
  end

  it "raises what to_pdf raises, from the main Ractor" do
    broken = Class.new(Stationery::Document) { def view_template = raise(ArgumentError, "no lines") }.finalize!

    expect { Stationery.render_all([documents.first, broken.new], ractors: 2) }
      .to raise_error(ArgumentError, "no lines")
  end

  def text_of(pdf) = Stationery::Testing::Inspector.new(pdf).text.split.join(" ")
end
