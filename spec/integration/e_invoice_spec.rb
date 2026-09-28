# frozen_string_literal: true

require_relative "../../examples/e_invoice"

RSpec.describe "the example e-invoice" do
  let(:document) { ExampleEInvoice.preview }
  let(:pdf) { document.to_pdf }
  let(:invoice) { inspect_pdf(pdf).factur_x }

  it "is the invoice, as PDF/A-3b, without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
    expect(pdf).to have_conformance(:pdf_a3b)
    expect(pdf).to have_pdf_language("en")
    expect(text_of(pdf)).to eq(text_of(ExampleInvoice.preview.to_pdf))
  end

  it "embeds its EN 16931 XML as the alternative to the page" do
    expect(pdf).to have_factur_x(profile: :en16931)
    expect(pdf).to have_attachment("factur-x.xml", mime: "text/xml", relationship: :alternative)
    expect(invoice).to include(filename: "factur-x.xml", version: "1.0")
    expect(invoice[:xml]).to start_with(%(<?xml version="1.0" encoding="UTF-8"?>\n<rsm:CrossIndustryInvoice ))
      .and end_with("</rsm:CrossIndustryInvoice>\n")
  end

  it "says in XML what the page says" do
    xml = invoice[:xml]

    expect(xml).to include("<ram:ID>INV-2026-042</ram:ID>", "<ram:Name>Müller &amp; Söhne GmbH</ram:Name>",
                           "<ram:Name>Illustration set (12)</ram:Name>",
                           %(<ram:BilledQuantity unitCode="C62">12</ram:BilledQuantity>),
                           %(<udt:DateTimeString format="102">20261026</udt:DateTimeString>))
    expect(xml.scan("<ram:IncludedSupplyChainTradeLineItem>").size).to eq(5)
    expect(xml).to include("<ram:LineTotalAmount>8510.00</ram:LineTotalAmount>",
                           %(<ram:TaxTotalAmount currencyID="EUR">2127.50</ram:TaxTotalAmount>),
                           "<ram:DuePayableAmount>10637.50</ram:DuePayableAmount>")
    expect(text_of(pdf)).to include("€10 637,50")
  end

  it "balances every opening tag" do
    xml = invoice[:xml]
    opened = xml.scan(/<((?:rsm|ram|udt):\w+)[ >]/).flatten.tally
    closed = xml.scan(%r{</((?:rsm|ram|udt):\w+)>}).flatten.tally

    expect(opened).to eq(closed)
  end
end
