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

  # A shaper's reordered stretch is shown in a Span whose ActualText is the
  # text as written (see Fonts::ShapedRun).
  describe "#text of a sequence with ActualText" do
    def shaped(shaper, &) = Class.new(SpecDocument) { shaper(shaper) }.build(&)

    it "is the ActualText when the first glyph shown has no advance" do
      pdf = shaped(FakeShapers::MARK_FIRST) { text "café au lait" }.to_pdf

      expect(page_contents(pdf).first).to match(%r{/Span <</ActualText <FEFF00650301>>> BDC\n\S+ Ts\n\[\S+ <0264>\] TJ})
      expect(described_class.new(pdf).text).to eq("café au lait")
    end

    it "is the ActualText when nothing shown has an advance" do
      pdf = shaped(FakeShapers::STACKED) { text "abc" }.to_pdf

      expect(described_class.new(pdf).text).to eq("abc")
    end

    it "is read once, between the text around it, however many glyphs the sequence shows" do
      doc = shaped(FakeShapers::REVERSED) do
        text "before <b>right to left, a long stretch</b> after", markup: true
        text "below"
      end

      expect(described_class.new(doc).text).to eq("before right to left, a long stretch after\nbelow")
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

  describe "#attachments" do
    it "lists every embedded file with its inflated bytes" do
      pdf = document.to_pdf(attachments: [{ name: "invoice.xml", data: "<i/>", mime: "text/xml",
                                            description: "e-invoice", relationship: :alternative }])

      expect(described_class.new(pdf).attachments)
        .to eq([{ name: "invoice.xml", mime: "text/xml", bytes: "<i/>", description: "e-invoice",
                  relationship: :alternative }])
      expect(described_class.new(document).attachments).to eq([])
    end
  end

  describe "#conformance" do
    it "reads the claimed levels from the XMP packet" do
      doc = Class.new(SpecDocument) do
        metadata title: "Report", lang: "en"
        def view_template = text("x")
      end.new

      expect(described_class.new(doc.to_pdf(conformance: %i[pdf_a3b pdf_ua1])).conformance).to eq(%i[pdf_a3b pdf_ua1])
      expect(described_class.new(doc.to_pdf(conformance: :pdf_a2b)).conformance).to eq([:pdf_a2b])
      expect(described_class.new(doc).conformance).to eq([])
      expect(described_class.new(doc.to_pdf(xmp: false)).conformance).to eq([])
    end
  end

  describe "#factur_x" do
    it "reads the invoice the XMP packet names, with its embedded XML" do
      doc = SpecDocument.build { text "x" }
      xml = "<?xml version=\"1.0\"?><rsm:CrossIndustryInvoice>Müller</rsm:CrossIndustryInvoice>"
      invoice = described_class.new(doc.to_pdf(factur_x: { xml:, profile: :extended, version: "1.0" })).factur_x

      expect(invoice).to eq(profile: :extended, filename: "factur-x.xml", version: "1.0", xml:)
      expect(invoice[:xml].encoding).to eq(Encoding::UTF_8)
      expect(described_class.new(doc).factur_x).to be_nil
    end
  end

  describe "#signatures" do
    let(:identity) { signer }
    let(:options) { { certificate: identity.certificate, key: identity.key } }

    it "lists every signed field with what it says and whether it verifies" do
      doc = SpecDocument.build do
        signature_field "board.chair", label: "Chair"
        signature_field "board.member", label: "Member"
      end
      at = Time.utc(2026, 9, 28, 12, 30, 15)
      sign = { **options, field: "board.member", at:, reason: "Godkänt", location: "Malmö" }

      signed = { field: "board.member", name: "Test Signer rsa", reason: "Godkänt", location: "Malmö",
                 signed_at: at, subfilter: :"ETSI.CAdES.detached", byte_range: [0, be > 0, be > 0, be > 0],
                 signer: "CN=Test Signer rsa,O=Stationery,C=SE", valid: true, timestamp: nil }

      expect(described_class.new(doc.to_pdf(sign:)).signatures).to match([signed])
    end

    it "reads a signature's timestamp: when, by which TSA, and whether it verifies" do
      at = Time.utc(2026, 9, 28, 12, 30, 15)
      pdf = document.to_pdf(sign: { **options, timestamp: { client: TimestampHelpers::FakeTSA.new(at:) } })

      expect(described_class.new(pdf).signatures.first[:timestamp])
        .to eq(time: at, tsa: "CN=Test TSA,O=Stationery,C=SE", valid: true)
    end

    it "is empty without a form or a signed field" do
      expect(described_class.new(document).signatures).to eq([])
      expect(described_class.new(SpecDocument.build { signature_field "empty" }).signatures).to eq([])
    end

    it "calls a signature it cannot read invalid" do
      pdf = document.to_pdf(sign: options)
      range = pdf[%r{/ByteRange \[([\d ]+)\]}, 1].split.map(&:to_i)
      broken = pdf.dup.tap { |bytes| bytes.bytesplice(range[1] + 1, 8, "00000000") }

      expect(described_class.new(broken).signatures).to match([include(signer: nil, valid: false)])
    end
  end

  describe "#xmp and #xmp_values" do
    it "reads the packet and its properties, or nil and {} without one" do
      doc = Class.new(SpecDocument) do
        metadata title: "Q3 & <Q4>", author: "Acme", keywords: %w[a b]
        def view_template = text("x")
      end.new
      inspector = described_class.new(doc)

      expect(inspector.xmp).to start_with("<?xpacket begin=").and include("<pdf:Producer>")
      expect(inspector.xmp.encoding).to eq(Encoding::UTF_8)
      expect(inspector.xmp_values)
        .to include("dc:title" => "Q3 & <Q4>", "dc:creator" => ["Acme"], "dc:subject" => %w[a b])
      expect(inspector.xmp_values["xmp:CreateDate"]).to match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/)
      expect(described_class.new(doc.to_pdf(xmp: false)).xmp).to be_nil
      expect(described_class.new(doc.to_pdf(xmp: false)).xmp_values).to eq({})
    end
  end

  describe "#page_labels" do
    it "computes one label per page from the /PageLabels tree, nil before the first range" do
      doc = Class.new(SpecDocument) do
        page_labels 2 => { style: :roman_lower }, 4 => { style: :decimal, prefix: "A-" }
        def view_template
          5.times do
            text("x")
            page_break
          end
        end
      end.new

      expect(described_class.new(doc).page_labels).to eq([nil, "i", "ii", "A-1", "A-2"])
    end

    it "is empty without labels" do
      expect(described_class.new(document).page_labels).to eq([])
    end
  end

  describe "#print_preferences" do
    it "reads the print hints of the catalog, the page ranges as Ranges" do
      doc = Class.new(SpecDocument) do
        print scaling: :none, copies: 2, pick_tray_by_size: false, duplex: :short_edge, pages: 1..1,
              dialog: :on_open
        def view_template = text("x")
      end.new

      expect(described_class.new(doc).print_preferences)
        .to eq(scaling: :none, copies: 2, pick_tray_by_size: false, duplex: :short_edge, pages: [1..1],
               dialog: :on_open)
    end

    it "is empty without hints" do
      expect(described_class.new(document).print_preferences).to eq({})
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
