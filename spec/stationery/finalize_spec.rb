# frozen_string_literal: true

# A document class an app has loaded by the end of its boot, with every
# setting a class can have, each given a shareable value.
EverySettingDocument = Class.new(SpecDocument) do
  page size: :a5, margin: "12mm", layout: :landscape
  max_pages 3
  font_family "Brand", regular: File.join(SpecDocument::FONTS, "OpenSans-Regular.ttf")
  font_family "Inter"
  font_fallbacks "Inter"
  shaper FakeShapers::NOMINAL
  default_text font: "Brand", size: 9, features: { "smcp" => true }
  metadata title: "Every setting", lang: "en"
  page_labels 1 => { style: :roman_lower }, 3 => { style: :decimal, start: 1, prefix: "A-" }
  print scaling: :none, copies: 2, pages: 1..2
  monochrome dpi: 203
  attach_file "notes.txt", "Notes", mime: "text/plain", modified_at: Time.utc(2026, 1, 1)
  images max_ppi: 150
  strict
  incremental
  tagged
  object_streams
  conformance :pdf_a3b, missing_glyphs: :replace
  factur_x(profile: :basic) { "<xml/>" }
  sign { { certificate: "PEM", key: "PEM" } }
  encrypt owner_password: "owner", permissions: [:print]
  page_template(layer: :background) { |page| text page.number.to_s }
  header(height: 20) { text "Header" }
  footer(on: :odd) { |page| text "#{page.number} / #{page.count}" }
end

RSpec.describe Stationery, ".finalize!" do
  around { |example| BootState.around(&example) }

  it_behaves_like "a boot-finalized configuration",
                  readers: [described_class.method(:font_paths), described_class.method(:instrumenter)],
                  finalize: -> { described_class.finalize! }

  it "keeps the instrumenter in use, so one loaded after boot is not picked up" do
    described_class.finalize!
    stub_const("ActiveSupport::Notifications", Module.new)

    expect(described_class.instrumenter).to be(Stationery::Instrumentation::NULL)
  end

  it "keeps an instrumenter set at boot" do
    instrumenter = Stationery::Instrumentation::Null.new.freeze
    described_class.instrumenter = instrumenter
    described_class.finalize!

    expect(described_class.instrumenter).to be(instrumenter)
  end

  it "keeps an instrumenter that cannot be made shareable as it is" do
    instrumenter = Stationery::Instrumentation::Null.new
    described_class.instrumenter = instrumenter

    expect { described_class.finalize! }.not_to raise_error
    expect(described_class.instrumenter).to be(instrumenter)
    expect(instrumenter).not_to be_frozen
  end

  it "answers Stationery and may run again" do
    expect(described_class.finalize!).to be(described_class)
    expect(described_class.finalize!).to be(described_class)
  end

  describe "the document classes loaded by then" do
    it_behaves_like "a boot-finalized configuration",
                    readers: { "EverySettingDocument.config" => -> { EverySettingDocument.config } },
                    finalize: -> { described_class.finalize! }

    it "finalizes each of them, and each of their subclasses" do
      parent = Class.new(SpecDocument) { page size: :a5 }
      child = Class.new(parent) { metadata title: "Child" }
      described_class.finalize!

      expect([SpecDocument, parent, child].map(&:config)).to all(be_frozen)
      expect([parent, child].map { Ractor.shareable?(it.config) }).to eq([true, true])
      expect { child.page(size: :a4) }.to raise_error(FrozenError)
    end

    it "leaves a class defined after it open" do
      described_class.finalize!
      later = Class.new(SpecDocument) { page size: :a5 }

      expect { later.metadata(title: "Later") }.not_to raise_error
      expect(later.config).not_to be_frozen
    end

    it "renders a finalized class as it rendered before" do
      allow(Time).to receive(:now).and_return(Time.utc(2026, 1, 1, 12))
      klass = Class.new(SpecDocument) do
        footer { |page| text "#{page.number}/#{page.count}" }
        def view_template = 3.times { text "Hello" }
      end
      before = klass.new.to_pdf
      described_class.finalize!

      expect(klass.new.to_pdf).to eq(before)
    end

    # A shaper that keeps state and a footer that uses a local of the class
    # body: neither can be made shareable, so the class renders on the main
    # Ractor only, and boots all the same.
    it "boots a class with settings that cannot be made shareable, keeping those as they are" do
      recording = FakeShapers::Recording.new
      draft = +"Draft"
      klass = Class.new(SpecDocument) do
        shaper recording
        footer { text draft }
        def view_template = text("Hello")
      end

      expect { described_class.finalize! }.not_to raise_error
      expect(klass.config).to be_frozen
      expect(klass.config[:shaping][:shaper]).to be(recording)
      expect([recording, recording.calls, draft, $stdout]).to all(satisfy { !it.frozen? })
      expect(Ractor.shareable?(klass.config)).to be(false)
      expect(klass.new.to_pdf).to start_with("%PDF")
      expect(recording.texts).to include("Hello", "Draft")
    end
  end
end
