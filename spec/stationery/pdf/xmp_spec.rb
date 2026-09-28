# frozen_string_literal: true

RSpec.describe Stationery::PDF::XMP do
  let(:time) { Time.utc(2026, 9, 28, 8, 5, 9) }
  let(:info) do
    { Title: "Q3 & <Q4>", Author: "Acme \"Studio\"", Subject: "Billing", Keywords: "invoice, q3",
      Creator: "stationery", Producer: "Stationery 1.0" }
  end
  let(:packet) { described_class.packet(info:, lang: "en-US", time:) }

  def li(text) = "<rdf:li xml:lang=\"x-default\">#{text}</rdf:li>"

  it "wraps the descriptions in an xpacket with 2 KB of padding" do
    expect(packet).to start_with(%(<?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?>\n))
      .and include(%(<x:xmpmeta xmlns:x="adobe:ns:meta/">\n <rdf:RDF))
    expect(packet).to end_with("</x:xmpmeta>\n#{described_class::PADDING}<?xpacket end=\"w\"?>\n")
    expect(described_class::PADDING.bytesize).to eq(2048)
  end

  it "writes Dublin Core properties, escaped, with the right RDF containers" do
    expect(packet).to include("<dc:title><rdf:Alt>#{li("Q3 &amp; &lt;Q4&gt;")}</rdf:Alt></dc:title>")
    expect(packet).to include("<dc:creator><rdf:Seq><rdf:li>Acme &quot;Studio&quot;</rdf:li></rdf:Seq></dc:creator>")
    expect(packet).to include("<dc:description><rdf:Alt>#{li("Billing")}</rdf:Alt></dc:description>")
    expect(packet).to include("<dc:subject><rdf:Bag><rdf:li>invoice</rdf:li><rdf:li>q3</rdf:li></rdf:Bag></dc:subject>")
    expect(packet).to include("<dc:language><rdf:Bag><rdf:li>en-US</rdf:li></rdf:Bag></dc:language>")
  end

  it "writes the xmp dates and creator tool and the pdf producer and keywords" do
    stamp = "2026-09-28T08:05:09Z"

    expect(packet).to include("<xmp:CreateDate>#{stamp}</xmp:CreateDate>")
      .and include("<xmp:ModifyDate>#{stamp}</xmp:ModifyDate>")
      .and include("<xmp:MetadataDate>#{stamp}</xmp:MetadataDate>")
      .and include("<xmp:CreatorTool>stationery</xmp:CreatorTool>")
    expect(packet).to include("<pdf:Producer>Stationery 1.0</pdf:Producer>")
      .and include("<pdf:Keywords>invoice, q3</pdf:Keywords>")
  end

  it "leaves out empty properties and whole descriptions with nothing to say" do
    xml = described_class.packet(info: { Producer: "P", Title: "" }, time:)

    expect(xml).not_to include("dc:")
    expect(xml).to include("<pdf:Producer>P</pdf:Producer>")
    expect(xml.scan("<rdf:Description").size).to eq(2)
  end

  it "is deterministic for the same input" do
    again = described_class.packet(info:, lang: "en-US", time:)

    expect(again).to eq(packet)
  end

  it "writes an extension schema per namespace, arrays as bags" do
    extensions = {
      "http://www.aiim.org/pdfa/ns/id/" => { prefix: "pdfaid", "part" => 3, "conformance" => "B" },
      "urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#" => { prefix: "fx", "Tags" => %w[a b] }
    }
    xml = described_class.packet(info: {}, time:, extensions:)

    expect(xml).to include(%(<rdf:Description rdf:about="" xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/">\n))
      .and include("   <pdfaid:part>3</pdfaid:part>\n   <pdfaid:conformance>B</pdfaid:conformance>\n")
    expect(xml).to include("<fx:Tags><rdf:Bag><rdf:li>a</rdf:li><rdf:li>b</rdf:li></rdf:Bag></fx:Tags>")
  end

  it "requires a prefix for an extension" do
    expect { described_class.packet(info: {}, time:, extensions: { "urn:x" => { "part" => 1 } }) }
      .to raise_error(ArgumentError, "XMP extension urn:x needs a :prefix")
  end

  it "describes extension schemas PDF/A does not know in a pdfaExtension container" do
    schema = { name: "Factur-X", uri: "urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#", prefix: "fx",
               properties: [{ name: "DocumentType", type: "Text", category: "external", description: "Invoice & co" }] }

    packet = described_class.packet(schemas: [schema])

    expect(packet).to include('xmlns:pdfaExtension="http://www.aiim.org/pdfa/ns/extension/"')
      .and include("<pdfaSchema:schema>Factur-X</pdfaSchema:schema>")
      .and include("<pdfaSchema:prefix>fx</pdfaSchema:prefix>")
      .and include("<pdfaProperty:name>DocumentType</pdfaProperty:name>")
      .and include("<pdfaProperty:valueType>Text</pdfaProperty:valueType>")
      .and include("<pdfaProperty:description>Invoice &amp; co</pdfaProperty:description>")
    expect(described_class.packet).not_to include("pdfaExtension")
  end
end
