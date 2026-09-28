# frozen_string_literal: true

# A Factur-X (ZUGFeRD) e-invoice: the example invoice as PDF/A-3b with its
# EN 16931 invoice XML embedded, so accounting software books what people read.
# Run it to write examples/e_invoice.pdf:
#
#   ruby -Ilib examples/e_invoice.rb
#   ruby -Ilib exe/stationery render examples/e_invoice.rb
require "date"
require "stationery"
require_relative "invoice"

class ExampleEInvoice < ExampleInvoice
  ISSUED = Date.new(2026, 9, 26)
  VAT_RATE = 25
  SELLER = { name: "Acme Studio AB", street: "Storgatan 1", postcode: "111 22", city: "Stockholm", country: "SE",
             email: "hello@acme.test", vat_id: "SE556677889901", iban: "SE4550000000058398257466" }.freeze
  BUYER = { street: "Hauptstraße 5", postcode: "10115", city: "Berlin", country: "DE", vat_id: "DE123456789" }.freeze

  metadata title: "E-invoice", author: SELLER[:name], lang: "en"

  # The XML comes from the document being rendered, so every invoice embeds
  # its own. `factur_x` also makes the file PDF/A-3b and identifies the
  # invoice in the XMP metadata.
  factur_x(profile: :en16931) { cross_industry_invoice }

  private

  # SAMPLE CODE. Stationery embeds the invoice XML, it does not write it: in
  # an application the XML comes from your invoicing code or a library made
  # for it. This is the smallest Cross Industry Invoice that satisfies
  # EN 16931 for the lines above: one VAT rate, no allowances or charges.
  def cross_industry_invoice
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rsm:CrossIndustryInvoice xmlns:rsm="urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100" xmlns:ram="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100" xmlns:udt="urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100">
        <rsm:ExchangedDocumentContext>
          <ram:GuidelineSpecifiedDocumentContextParameter>
            <ram:ID>urn:cen.eu:en16931:2017</ram:ID>
          </ram:GuidelineSpecifiedDocumentContextParameter>
        </rsm:ExchangedDocumentContext>
        <rsm:ExchangedDocument>
          <ram:ID>#{xml(@number)}</ram:ID>
          <ram:TypeCode>380</ram:TypeCode>
          <ram:IssueDateTime>#{xml_date(ISSUED)}</ram:IssueDateTime>
        </rsm:ExchangedDocument>
        <rsm:SupplyChainTradeTransaction>
      #{@items.each_with_index.map { |item, index| xml_line(index + 1, *item) }.join.chomp}
          <ram:ApplicableHeaderTradeAgreement>
            <ram:SellerTradeParty>
              <ram:Name>#{xml(SELLER[:name])}</ram:Name>
      #{xml_address(SELLER)}
              <ram:URIUniversalCommunication>
                <ram:URIID schemeID="EM">#{xml(SELLER[:email])}</ram:URIID>
              </ram:URIUniversalCommunication>
      #{xml_vat_id(SELLER)}
            </ram:SellerTradeParty>
            <ram:BuyerTradeParty>
              <ram:Name>#{xml(@customer)}</ram:Name>
      #{xml_address(BUYER)}
      #{xml_vat_id(BUYER)}
            </ram:BuyerTradeParty>
            <ram:BuyerOrderReferencedDocument>
              <ram:IssuerAssignedID>PO-7781</ram:IssuerAssignedID>
            </ram:BuyerOrderReferencedDocument>
          </ram:ApplicableHeaderTradeAgreement>
          <ram:ApplicableHeaderTradeDelivery>
            <ram:ActualDeliverySupplyChainEvent>
              <ram:OccurrenceDateTime>#{xml_date(ISSUED)}</ram:OccurrenceDateTime>
            </ram:ActualDeliverySupplyChainEvent>
          </ram:ApplicableHeaderTradeDelivery>
          <ram:ApplicableHeaderTradeSettlement>
            <ram:InvoiceCurrencyCode>EUR</ram:InvoiceCurrencyCode>
            <ram:SpecifiedTradeSettlementPaymentMeans>
              <ram:TypeCode>58</ram:TypeCode>
              <ram:PayeePartyCreditorFinancialAccount>
                <ram:IBANID>#{SELLER[:iban]}</ram:IBANID>
              </ram:PayeePartyCreditorFinancialAccount>
            </ram:SpecifiedTradeSettlementPaymentMeans>
            <ram:ApplicableTradeTax>
              <ram:CalculatedAmount>#{xml_amount(vat)}</ram:CalculatedAmount>
              <ram:TypeCode>VAT</ram:TypeCode>
              <ram:BasisAmount>#{xml_amount(subtotal)}</ram:BasisAmount>
              <ram:CategoryCode>S</ram:CategoryCode>
              <ram:RateApplicablePercent>#{VAT_RATE}</ram:RateApplicablePercent>
            </ram:ApplicableTradeTax>
            <ram:SpecifiedTradePaymentTerms>
              <ram:DueDateDateTime>#{xml_date(Date.parse(@due))}</ram:DueDateDateTime>
            </ram:SpecifiedTradePaymentTerms>
            <ram:SpecifiedTradeSettlementHeaderMonetarySummation>
              <ram:LineTotalAmount>#{xml_amount(subtotal)}</ram:LineTotalAmount>
              <ram:TaxBasisTotalAmount>#{xml_amount(subtotal)}</ram:TaxBasisTotalAmount>
              <ram:TaxTotalAmount currencyID="EUR">#{xml_amount(vat)}</ram:TaxTotalAmount>
              <ram:GrandTotalAmount>#{xml_amount(total)}</ram:GrandTotalAmount>
              <ram:DuePayableAmount>#{xml_amount(total)}</ram:DuePayableAmount>
            </ram:SpecifiedTradeSettlementHeaderMonetarySummation>
          </ram:ApplicableHeaderTradeSettlement>
        </rsm:SupplyChainTradeTransaction>
      </rsm:CrossIndustryInvoice>
    XML
  end

  def xml_line(number, name, quantity, price)
    <<~XML.gsub(/^/, "    ")
      <ram:IncludedSupplyChainTradeLineItem>
        <ram:AssociatedDocumentLineDocument>
          <ram:LineID>#{number}</ram:LineID>
        </ram:AssociatedDocumentLineDocument>
        <ram:SpecifiedTradeProduct>
          <ram:Name>#{xml(name)}</ram:Name>
        </ram:SpecifiedTradeProduct>
        <ram:SpecifiedLineTradeAgreement>
          <ram:NetPriceProductTradePrice>
            <ram:ChargeAmount>#{xml_amount(price)}</ram:ChargeAmount>
          </ram:NetPriceProductTradePrice>
        </ram:SpecifiedLineTradeAgreement>
        <ram:SpecifiedLineTradeDelivery>
          <ram:BilledQuantity unitCode="C62">#{quantity}</ram:BilledQuantity>
        </ram:SpecifiedLineTradeDelivery>
        <ram:SpecifiedLineTradeSettlement>
          <ram:ApplicableTradeTax>
            <ram:TypeCode>VAT</ram:TypeCode>
            <ram:CategoryCode>S</ram:CategoryCode>
            <ram:RateApplicablePercent>#{VAT_RATE}</ram:RateApplicablePercent>
          </ram:ApplicableTradeTax>
          <ram:SpecifiedTradeSettlementLineMonetarySummation>
            <ram:LineTotalAmount>#{xml_amount(quantity * price)}</ram:LineTotalAmount>
          </ram:SpecifiedTradeSettlementLineMonetarySummation>
        </ram:SpecifiedLineTradeSettlement>
      </ram:IncludedSupplyChainTradeLineItem>
    XML
  end

  def xml_address(party)
    <<~XML.gsub(/^/, "        ").chomp
      <ram:PostalTradeAddress>
        <ram:PostcodeCode>#{xml(party[:postcode])}</ram:PostcodeCode>
        <ram:LineOne>#{xml(party[:street])}</ram:LineOne>
        <ram:CityName>#{xml(party[:city])}</ram:CityName>
        <ram:CountryID>#{party[:country]}</ram:CountryID>
      </ram:PostalTradeAddress>
    XML
  end

  def xml_vat_id(party)
    <<~XML.gsub(/^/, "        ").chomp
      <ram:SpecifiedTaxRegistration>
        <ram:ID schemeID="VA">#{party[:vat_id]}</ram:ID>
      </ram:SpecifiedTaxRegistration>
    XML
  end

  def xml_date(date) = %(<udt:DateTimeString format="102">#{date.strftime("%Y%m%d")}</udt:DateTimeString>)
  def xml_amount(amount) = format("%.2f", amount)
  def xml(text) = text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
end

if $PROGRAM_NAME == __FILE__
  ExampleEInvoice.preview.to_pdf(File.expand_path("e_invoice.pdf", __dir__))
  puts "wrote examples/e_invoice.pdf"
end
