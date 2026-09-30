# frozen_string_literal: true

require "stringio"

# `object_streams:` packs a tagged render's structure elements, and every
# other object that is not a stream, into deflated object streams.
RSpec.describe Stationery::Document, "#to_pdf" do
  before { allow(Time).to receive(:now).and_return(Time.utc(2026, 1, 1, 12)) }

  let(:ledger) do
    Class.new(SpecDocument) do
      metadata title: "Ledger", lang: "en"

      def view_template
        rows = Array.new(120) { |i| ["#{(i % 28) + 1}/03", "Counterparty #{i}", "INV-#{i}", "45.50"] }
        table([%w[Date Recipient Reference Amount], *rows], header: true, cell: { size: 7, padding: [4, 3] })
      end
    end
  end

  def packed?(pdf) = pdf.include?("/Type /ObjStm")

  it "packs a tagged render by default, to a fraction of its size with the same structure" do
    packed = ledger.new.to_pdf(tagged: true)
    plain = ledger.new.to_pdf(tagged: true, object_streams: false)

    expect(packed?(packed)).to be(true)
    expect(packed?(plain)).to be(false)
    expect(packed.bytesize).to be < plain.bytesize / 3
    expect(struct_tree(packed)).to eq(struct_tree(plain))
    expect(reader_for(packed).page_count).to eq(reader_for(plain).page_count)
  end

  it "packs a PDF/UA-1 render, which is tagged" do
    expect(packed?(ledger.new.to_pdf(conformance: :pdf_ua1))).to be(true)
  end

  it "leaves an untagged render as it was unless asked" do
    expect(packed?(ledger.new.to_pdf)).to be(false)
    expect(packed?(ledger.new.to_pdf(conformance: :pdf_a3b))).to be(false)
    expect(packed?(ledger.new.to_pdf(object_streams: true))).to be(true)
  end

  it "takes the class's setting, which a render overrides" do
    unpacked = Class.new(ledger) do
      tagged
      object_streams false
    end

    expect(packed?(unpacked.new.to_pdf)).to be(false)
    expect(packed?(unpacked.new.to_pdf(object_streams: true))).to be(true)
  end

  it "packs an incremental tagged render streamed to a block" do
    chunks = []
    ledger.new.to_pdf(tagged: true, incremental: true) { |chunk| chunks << chunk.dup }
    pdf = chunks.join

    expect(packed?(pdf)).to be(true)
    expect(struct_tree(pdf)).to eq(struct_tree(ledger.new.to_pdf(tagged: true, object_streams: false)))
  end

  it "packs an encrypted tagged render streamed to a block, which opens with its password" do
    chunks = []
    ledger.new.to_pdf(tagged: true, encrypt: { user_password: "u", owner_password: "o" }) { |chunk| chunks << chunk }
    reader = PDF::Reader.new(StringIO.new(chunks.join), password: "u")

    expect(packed?(chunks.join)).to be(true)
    expect(reader.page_count).to eq(ledger.new.tap(&:to_pdf).page_count)
    expect(reader.objects.deref(reader.objects.trailer[:Root])).to include(:StructTreeRoot)
  end

  it "counts the pages it laid out, which a packed file does not show in its bytes" do
    document = ledger.new
    pdf = document.to_pdf(tagged: true)

    expect(document.page_count).to eq(page_count(pdf)).and be > 1
    expect(ledger.new.tap(&:to_png).page_count).to eq(document.page_count)
  end

  it "keeps a signature dictionary out, so the signature covers the packed file" do
    signed = Class.new(ledger) do
      def view_template
        super
        signature_field "approval", width: 160, label: "Approved by"
      end
    end
    pdf = signed.new.to_pdf(conformance: :pdf_ua1, sign: { certificate: signer.certificate, key: signer.key })

    expect(packed?(pdf)).to be(true)
    expect(pdf).to match(%r{^\d+ 0 obj\n<</Type /Sig })
    verdict = openssl_verdict(pdf)
    expect(verdict).to include("Verification successful") if verdict
  end

  it "is a PDF option a picture refuses" do
    expect { ledger.new.to_png(object_streams: true) }.to raise_error(ArgumentError, /object_streams/)
  end
end
