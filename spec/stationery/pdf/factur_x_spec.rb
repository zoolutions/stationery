# frozen_string_literal: true

RSpec.describe Stationery::PDF::FacturX do
  let(:xml) { %(<?xml version="1.0" encoding="UTF-8"?>\n<rsm:CrossIndustryInvoice/>) }
  let(:document) do
    Class.new(SpecDocument) do
      metadata title: "Invoice 42", lang: "en"
      def view_template = text("Invoice 42")
      def invoice_xml = %(<rsm:CrossIndustryInvoice id="#{self.class.name || "anonymous"}"/>)
    end
  end

  describe ".for" do
    it "is nil without a spec and builds from a Hash" do
      expect(described_class.for(nil, document.new)).to be_nil

      invoice = described_class.for({ xml:, profile: "basic" }, document.new)
      expect(invoice).to have_attributes(xml:, profile: :basic, filename: "factur-x.xml", version: "1.0",
                                         level: "BASIC")
    end

    it "evaluates a block in the document, calls a callable with it and sends a Symbol" do
      instance = document.new

      expect(described_class.for({ xml: -> { invoice_xml } }, instance).xml).to include("CrossIndustryInvoice")
      expect(described_class.for({ xml: ->(doc) { doc.invoice_xml.dup } }, instance).xml).to eq(instance.invoice_xml)
      expect(described_class.for({ xml: :invoice_xml }, instance).xml).to eq(instance.invoice_xml)
    end

    it "names every profile's conformance level, file and relationship" do
      rows = described_class::PROFILES.keys.map do |profile|
        invoice = described_class.for({ xml:, profile: }, document.new)
        [profile, invoice.level, invoice.filename, invoice.attachment.relationship]
      end

      expect(rows).to eq([
                           [:minimum, "MINIMUM", "factur-x.xml", :data],
                           [:basic_wl, "BASIC WL", "factur-x.xml", :data],
                           [:basic, "BASIC", "factur-x.xml", :alternative],
                           [:en16931, "EN 16931", "factur-x.xml", :alternative],
                           [:extended, "EXTENDED", "factur-x.xml", :alternative],
                           [:xrechnung, "XRECHNUNG", "xrechnung.xml", :alternative]
                         ])
    end

    it "refuses an unknown profile and anything that is not invoice XML" do
      expect { described_class.for({ xml:, profile: :comfort }, document.new) }
        .to raise_error(ArgumentError, "unknown Factur-X profile :comfort (use :minimum, :basic_wl, :basic, " \
                                       ":en16931, :extended, :xrechnung)")
      expect { described_class.for({ xml: " \n" }, document.new) }
        .to raise_error(ArgumentError, "factur_x needs the invoice XML (a String starting with <?xml or " \
                                       "<rsm:CrossIndustryInvoice), got an empty String")
      expect { described_class.for({ xml: "{}" }, document.new) }
        .to raise_error(ArgumentError, /got "\{\}"/)
      expect { described_class.for({ xml: nil }, document.new) }.to raise_error(ArgumentError, /got nil/)
    end

    it "accepts a byte order mark and a bare root element" do
      expect(described_class.for({ xml: "﻿#{xml}" }, document.new).xml).to start_with("﻿")
      expect(described_class.for({ xml: "<rsm:CrossIndustryInvoice/>" }, document.new).profile).to eq(:en16931)
    end
  end

  it "merges PDF/A-3b into the declared levels and refuses PDF/A-2b" do
    invoice = described_class.for({ xml: }, document.new)

    expect(invoice.conformance(nil)).to eq([:pdf_a3b])
    expect(invoice.conformance(:pdf_ua1)).to eq(%i[pdf_ua1 pdf_a3b])
    expect(invoice.conformance(%i[pdf_a3b pdf_ua1])).to eq(%i[pdf_a3b pdf_ua1])
    expect { invoice.conformance(:pdf_a2b) }
      .to raise_error(ArgumentError, "Factur-X embeds its XML, which needs PDF/A-3b: drop conformance :pdf_a2b")
  end

  it "describes itself and its schema for the XMP packet" do
    invoice = described_class.for({ xml:, profile: :extended, version: "1.0" }, document.new)

    expect(invoice.xmp_extensions).to eq(
      "urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#" => {
        prefix: "fx", "DocumentType" => "INVOICE", "DocumentFileName" => "factur-x.xml", "Version" => "1.0",
        "ConformanceLevel" => "EXTENDED"
      }
    )
    expect(invoice.xmp_schema).to include(prefix: "fx", name: "Factur-X PDFA Extension Schema",
                                          uri: "urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#")
    expect(invoice.xmp_schema[:properties].map { it.values_at(:name, :type, :category) })
      .to eq(%w[DocumentFileName DocumentType Version ConformanceLevel].map { [it, "Text", "external"] })
  end

  describe "in a document" do
    it "embeds the XML, claims PDF/A-3b and identifies the invoice in XMP" do
      pdf = document.new.to_pdf(factur_x: { xml:, profile: :en16931 })
      inspector = inspect_pdf(pdf)

      expect(inspector.conformance).to eq([:pdf_a3b])
      expect(inspector.attachments).to eq([{ name: "factur-x.xml", mime: "text/xml", bytes: xml.b,
                                             description: "Factur-X Invoice", relationship: :alternative }])
      expect(inspector.xmp_values).to include(
        "fx:DocumentType" => "INVOICE", "fx:DocumentFileName" => "factur-x.xml", "fx:Version" => "1.0",
        "fx:ConformanceLevel" => "EN 16931"
      )
      expect(inspector.xmp).to include("<pdfaSchema:prefix>fx</pdfaSchema:prefix>")
        .and include("<pdfaProperty:name>ConformanceLevel</pdfaProperty:name>")
    end

    it "stamps the embedded file with its modification date" do
      pdf = document.new.to_pdf(factur_x: { xml: })
      objects = reader_for(pdf).objects
      catalog = objects.deref(objects.trailer[:Root])
      spec = objects.deref_hash(objects.deref_array(catalog[:AF]).first)
      params = objects.deref(objects.deref_hash(spec[:EF])[:F]).hash[:Params]

      expect(params[:ModDate]).to match(/\AD:\d{14}Z\z/)
      expect(params[:Size]).to eq(xml.bytesize)
    end

    it "takes the XML from the class, evaluated per render in the document" do
      klass = Class.new(document) { factur_x(profile: :basic) { invoice_xml } }
      by_name = Class.new(document) { factur_x :invoice_xml, profile: :xrechnung }

      expect(inspect_pdf(klass.new.to_pdf).factur_x)
        .to eq(profile: :basic, filename: "factur-x.xml", version: "1.0", xml: klass.new.invoice_xml)
      expect(inspect_pdf(by_name.new.to_pdf).factur_x).to include(profile: :xrechnung, filename: "xrechnung.xml")
      expect(inspect_pdf(klass.new.to_pdf(factur_x: nil)).factur_x).to be_nil
    end

    it "validates a literal at declaration and keeps declared levels" do
      expect { Class.new(document) { factur_x "nope" } }.to raise_error(ArgumentError, /got "nope"/)
      expect { Class.new(document) { factur_x "<?xml?>", profile: :zugferd } }
        .to raise_error(ArgumentError, /unknown Factur-X profile :zugferd/)
      expect { Class.new(document) { factur_x } }
        .to raise_error(ArgumentError, "factur_x needs the invoice XML, a method name or a block")

      accessible = Class.new(document) do
        conformance :pdf_ua1
        factur_x "<?xml version=\"1.0\"?><rsm:CrossIndustryInvoice/>"
      end
      expect(inspect_pdf(accessible.new.to_pdf).conformance).to eq(%i[pdf_a3b pdf_ua1])
    end

    it "keeps other attachments and refuses a second file of the same name" do
      pdf = document.new.to_pdf(factur_x: { xml: }, attachments: [{ name: "terms.txt", data: "net 30" }])

      expect(inspect_pdf(pdf).attachments.map { it[:name] }).to eq(%w[factur-x.xml terms.txt])
      expect { document.new.to_pdf(factur_x: { xml: }, attachments: [{ name: "factur-x.xml", data: "x" }]) }
        .to raise_error(ArgumentError, 'attachment "factur-x.xml" is given twice')
    end

    it "refuses encryption, as PDF/A does" do
      expect { document.new.to_pdf(factur_x: { xml: }, encrypt: { owner_password: "o" }) }
        .to raise_error(ArgumentError, %r{PDF/A forbids encryption})
    end

    it "changes nothing without an invoice" do
      allow(Time).to receive(:now).and_return(Time.utc(2026, 9, 28, 12))
      plain = Class.new(document)
      declared = Class.new(document) { factur_x "<?xml version=\"1.0\"?><rsm:CrossIndustryInvoice/>" }

      expect(declared.new.to_pdf(factur_x: nil)).to eq(plain.new.to_pdf)
    end
  end
end
