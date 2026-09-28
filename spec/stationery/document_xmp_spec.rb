# frozen_string_literal: true

require "stringio"

RSpec.describe Stationery::Document do
  describe "XMP metadata" do
    let(:document) do
      Class.new(SpecDocument) do
        metadata title: "Invoice 42", author: "Acme", subject: "Billing", keywords: %w[invoice q3], lang: "de"
        def view_template = text("x")
      end
    end

    def metadata_object(pdf) = pdf[%r{\d+ 0 obj\n<</Type /Metadata.*?endobj}m]

    it "writes the packet as an uncompressed /Metadata stream on the catalog" do
      pdf = document.new.to_pdf
      object = metadata_object(pdf)

      expect(object).to include("/Subtype /XML").and include("<?xpacket begin=")
      expect(object).not_to include("/Filter")
      expect(catalog_of(pdf)[:Metadata]).to be_a(PDF::Reader::Reference)
    end

    it "mirrors the Info dictionary at the same instant" do
      allow(Time).to receive(:now).and_return(Time.utc(2026, 9, 28, 8, 5, 9))
      pdf = document.new.to_pdf

      expect(reader_for(pdf).info[:CreationDate]).to eq("D:20260928080509Z")
      expect(inspect_pdf(pdf).xmp_values).to include(
        "dc:title" => "Invoice 42", "dc:creator" => ["Acme"], "dc:description" => "Billing",
        "dc:subject" => %w[invoice q3], "dc:language" => ["de"], "xmp:CreateDate" => "2026-09-28T08:05:09Z",
        "pdf:Producer" => "Stationery #{Stationery::VERSION}", "pdf:Keywords" => "invoice, q3"
      )
    end

    it "is written for a document without metadata too" do
      values = inspect_pdf(SpecDocument.build { text "x" }.to_pdf).xmp_values

      expect(values).to include("pdf:Producer" => "Stationery #{Stationery::VERSION}")
      expect(values).not_to have_key("dc:title")
    end

    it "can be left out per document or per render, keeping xmp out of the Info dictionary" do
      silent = Class.new(document) { metadata xmp: false }

      expect(metadata_object(silent.new.to_pdf)).to be_nil
      expect(reader_for(silent.new.to_pdf).info).not_to have_key(:xmp)
      expect(metadata_object(document.new.to_pdf(xmp: false))).to be_nil
      expect(metadata_object(silent.new.to_pdf(xmp: true))).not_to be_nil
    end

    it "encrypts the packet with the rest of an encrypted document" do
      pdf = document.new.to_pdf(encrypt: { owner_password: "s3cret", user_password: "1234" })
      reader = PDF::Reader.new(StringIO.new(pdf), password: "1234")
      catalog = reader.objects.deref(reader.objects.trailer[:Root])

      expect(pdf).not_to include("<?xpacket")
      expect(reader.objects.deref(catalog[:Metadata]).unfiltered_data).to include("<dc:title>")
    end
  end
end
