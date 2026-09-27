# frozen_string_literal: true

require "stationery/testing/inspector"

RSpec.describe Stationery::Testing::Inspector do
  let(:document) do
    SpecDocument.build do
      text "Hello   world"
      page_break
      text "Visit us", link: "https://example.com"
    end
  end

  describe "subjects" do
    let(:pdf) { document.to_pdf }

    it "renders a document once" do
      allow(document).to receive(:to_pdf).and_call_original
      inspector = described_class.new(document)

      expect(inspector.pdf).to start_with("%PDF")
      expect(inspector.page_count).to eq(2)
      expect(document).to have_received(:to_pdf).once
    end

    it "reads PDF bytes" do
      expect(described_class.new(pdf).page_count).to eq(2)
    end

    it "reads a file by String or Pathname path" do
      path = File.join(Dir.mktmpdir, "doc.pdf")
      File.binwrite(path, pdf)

      expect(described_class.new(path).page_count).to eq(2)
      expect(described_class.new(Pathname(path)).page_count).to eq(2)
    end

    it "reads an IO" do
      expect(described_class.new(StringIO.new(pdf)).pdf).to eq(pdf)
    end
  end

  describe "content" do
    subject(:inspector) { described_class.new(document) }

    it "extracts text per page with whitespace squeezed" do
      expect(inspector.page_texts).to eq(["Hello world", "Visit us"])
      expect(inspector.text).to eq("Hello world\nVisit us")
    end

    it "lists URI links" do
      expect(inspector.links).to eq(["https://example.com"])
    end

    it "has no internal links, bookmarks or images" do
      expect(inspector.internal_links).to eq([])
      expect(inspector.bookmarks).to eq([])
      expect(inspector.image_count).to eq(0)
    end

    it "exposes the document info" do
      expect(inspector.metadata[:Producer]).to start_with("Stationery")
    end

    it "has no language" do
      expect(inspector.lang).to be_nil
    end
  end

  describe "#lang" do
    it "reads the catalog /Lang as UTF-8" do
      doc = Class.new(SpecDocument) do
        metadata lang: "de-CH"
        def view_template = text("Grüezi")
      end.new

      lang = described_class.new(doc).lang

      expect(lang).to eq("de-CH")
      expect(lang.encoding).to eq(Encoding::UTF_8)
    end
  end

  it "counts images" do
    path = image_path("rgb.jpg")
    doc = SpecDocument.build { image path, width: 20 }

    expect(described_class.new(doc).image_count).to eq(1)
  end

  it "lists internal link destinations and bookmark titles depth-first" do
    inspector = described_class.new(outline_pdf)

    expect(inspector.internal_links).to eq(["totals", 2, "summary"])
    expect(inspector.bookmarks).to eq(%w[Intro Détails Appendix])
    expect(inspector.links).to eq([])
  end

  describe "#warnings" do
    it "collects a document's overflow warnings" do
      doc = SpecDocument.build { box(break_inside: :avoid) { 40.times { |i| text "row #{i}" } } }

      expect(described_class.new(doc).warnings.map(&:page)).to eq([1])
    end

    it "is empty for raw bytes" do
      expect(described_class.new(document.to_pdf).warnings).to eq([])
    end
  end

  it "explains a missing pdf-reader" do
    inspector = described_class.new(document)
    allow(inspector).to receive(:require).with("pdf/reader").and_raise(LoadError)

    expect { inspector.reader }.to raise_error(Stationery::Error, /add gem "pdf-reader"/)
  end
end
