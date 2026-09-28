# frozen_string_literal: true

require "stationery/testing/matchers"

RSpec.describe Stationery::Testing::Matchers do
  let(:document) do
    SpecDocument.build do
      text "Invoice INV-7"
      page_break
      text "Pay online", link: "https://pay.example.com/7"
    end
  end
  let(:pdf) { document.to_pdf }

  it "matches text anywhere, by String or Regexp" do
    expect(pdf).to have_pdf_text("INV-7")
    expect(pdf).to have_pdf_text(/Invoice INV-\d/)
    expect(pdf).not_to have_pdf_text("Receipt")
    expect(have_pdf_text(/INV-\d/).description).to eq("have text /INV-\\d/")
  end

  it "describes a text mismatch with an excerpt of what was found" do
    matcher = have_pdf_text("Receipt")
    matcher.matches?(pdf)

    expect(matcher.description).to eq('have text "Receipt"')
    expect(matcher.failure_message).to eq("expected PDF to have text \"Receipt\", got text:\nInvoice INV-7\nPay online")
    expect(matcher.failure_message_when_negated).to start_with('expected PDF not to have text "Receipt"')
  end

  it "cuts the excerpt at 500 characters" do
    matcher = have_pdf_text("missing")
    matcher.matches?(SpecDocument.build { 60.times { text "0123456789" } })

    expect(matcher.failure_message).to end_with("…")
    expect(matcher.failure_message.split("\n", 2).last.length).to eq(501)
  end

  it "matches text on one page" do
    expect(pdf).to have_pdf_text_on_page(2, "Pay online")
    expect(pdf).not_to have_pdf_text_on_page(1, /Pay/)
  end

  it "reports the page's text, or the page count when the page does not exist" do
    wrong_page = have_pdf_text_on_page(1, "Pay online")
    wrong_page.matches?(pdf)
    missing_page = have_pdf_text_on_page(3, "Pay online")

    expect(missing_page.matches?(pdf)).to be(false)
    expect(wrong_page.description).to eq('have text "Pay online" on page 1')
    expect(wrong_page.failure_message).to end_with("got text on page 1:\nInvoice INV-7")
    expect(missing_page.failure_message).to end_with("but it has 2 page(s)")
  end

  it "matches the page count" do
    matcher = have_page_count(3)

    expect(pdf).to have_page_count(2)
    expect(matcher.matches?(pdf)).to be(false)
    expect(matcher.description).to eq("have 3 page(s)")
    expect(matcher.failure_message).to eq("expected PDF to have 3 page(s), got 2")
  end

  it "matches links by URL or Regexp" do
    matcher = have_pdf_link("https://example.com")

    expect(pdf).to have_pdf_link("https://pay.example.com/7")
    expect(pdf).to have_pdf_link(%r{pay\.example\.com/\d+})
    expect(matcher.matches?(pdf)).to be(false)
    expect(matcher.description).to eq('have a link to "https://example.com"')
    expect(matcher.failure_message).to end_with('got links ["https://pay.example.com/7"]')
  end

  it "matches the image count" do
    matcher = have_image_count(1)

    expect(pdf).to have_image_count(0)
    expect(matcher.matches?(pdf)).to be(false)
    expect(matcher.description).to eq("have 1 image(s)")
    expect(matcher.failure_message).to eq("expected PDF to have 1 image(s), got 0")
  end

  it "matches bookmarks" do
    matcher = have_bookmark("Summary")

    expect(outline_pdf).to have_bookmark("Détails")
    expect(matcher.matches?(outline_pdf)).to be(false)
    expect(matcher.description).to eq('have a bookmark "Summary"')
    expect(matcher.failure_message).to end_with('got bookmarks ["Intro", "Détails", "Appendix"]')
  end

  it "composes with and, or and all like the built-in matchers" do
    expect(outline_pdf).to have_bookmark("Intro").and have_bookmark("Appendix")
    expect(outline_pdf).to have_bookmark("Missing").or have_bookmark("Détails")
    expect([pdf, document]).to all(have_pdf_text("INV-7").and(have_page_count(2)))
    expect { expect(outline_pdf).to have_bookmark("Intro").and have_bookmark("Missing") }
      .to raise_error(RSpec::Expectations::ExpectationNotMetError, /expected PDF to have a bookmark "Missing"/)
  end

  it "matches a document without warnings" do
    expect(document).to have_no_warnings
    expect(have_no_warnings.description).to eq("have no warnings")
  end

  it "lists the warnings of an overflowing document" do
    matcher = have_no_warnings
    overflowing = SpecDocument.build { box(break_inside: :avoid) { 40.times { |i| text "row #{i}" } } }

    expect(matcher.matches?(overflowing)).to be(false)
    expect(matcher.failure_message).to match(/\Aexpected PDF to have no warnings, got:\n  - content .+ on page 1/)
    expect(matcher.failure_message_when_negated).to start_with("expected PDF not to have no warnings")
  end

  describe "tagged PDF" do
    let(:tagged) do
      Class.new(SpecDocument) do
        tagged
        metadata lang: "en"
        def view_template = text("Title", heading: 1)
      end.new
    end

    it "matches the structure tree" do
      expect(tagged).to have_structure([[:Document, [[:H1, "Title"]]]])
      matcher = have_structure([[:Document, [[:P, "Title"]]]])

      expect(matcher.matches?(tagged)).to be(false)
      expect(matcher.description).to eq("have structure [[:Document, [[:P, \"Title\"]]]]")
      expect(matcher.failure_message).to end_with("got [[:Document, [[:H1, \"Title\"]]]]")
    end

    it "matches the language" do
      matcher = have_pdf_language("de")

      expect(tagged).to have_pdf_language("en")
      expect(matcher.matches?(tagged)).to be(false)
      expect(matcher.description).to eq('have language "de"')
      expect(matcher.failure_message).to eq('expected PDF to have language "de", got "en"')
      expect(have_pdf_language("en").tap { |m| m.matches?(document) }.failure_message).to end_with("got none")
    end

    it "matches an attachment by name, and optionally by type and relationship" do
      pdf = document.to_pdf(attachments: [{ name: "invoice.xml", data: "<i/>", mime: "text/xml",
                                            relationship: :alternative }])

      expect(pdf).to have_attachment("invoice.xml")
      expect(pdf).to have_attachment("invoice.xml", mime: "text/xml", relationship: :alternative)
      expect(pdf).not_to have_attachment("invoice.xml", mime: "text/plain")
      matcher = have_attachment("other.xml", mime: "text/xml")
      expect(matcher.matches?(pdf)).to be(false)
      expect(matcher.description).to eq('have an attachment "other.xml" mime "text/xml"')
      expect(matcher.failure_message).to eq(
        'expected PDF to have an attachment "other.xml" mime "text/xml", got ["invoice.xml (text/xml, alternative)"]'
      )
      expect(have_attachment("x").tap { |m| m.matches?(document) }.failure_message).to end_with("got none")
    end

    it "matches the claimed conformance levels" do
      titled = Class.new(tagged.class) { metadata title: "Title" }.new
      pdf = titled.to_pdf(conformance: %i[pdf_a3b pdf_ua1])

      expect(pdf).to have_conformance(:pdf_a3b)
      expect(pdf).to have_conformance(:pdf_a3b, :pdf_ua1)
      expect(pdf).not_to have_conformance(:pdf_a2b)
      matcher = have_conformance(:pdf_a2b, :pdf_ua1)
      expect(matcher.matches?(pdf)).to be(false)
      expect(matcher.description).to eq("conform to PDF/A-2b and PDF/UA-1")
      expect(matcher.failure_message)
        .to eq("expected PDF to conform to PDF/A-2b and PDF/UA-1, got PDF/A-3b and PDF/UA-1")
      expect(have_conformance(:pdf_ua1).tap { |m| m.matches?(document) }.failure_message).to end_with("got no claim")
    end

    it "matches a Factur-X invoice, and optionally its profile" do
      pdf = document.to_pdf(factur_x: { xml: "<rsm:CrossIndustryInvoice/>", profile: :basic })

      expect(pdf).to have_factur_x
      expect(pdf).to have_factur_x(profile: :basic)
      expect(pdf).not_to have_factur_x(profile: :en16931)
      matcher = have_factur_x(profile: :en16931)
      expect(matcher.matches?(pdf)).to be(false)
      expect(matcher.description).to eq("be a Factur-X invoice of profile :en16931")
      expect(matcher.failure_message)
        .to eq("expected PDF to be a Factur-X invoice of profile :en16931, got profile :basic")
      expect(have_factur_x.tap { |m| m.matches?(document) }.failure_message)
        .to eq("expected PDF to be a Factur-X invoice, got no invoice")
    end

    it "matches a signature, by signer and by validity" do
      identity = signer
      pdf = document.to_pdf(sign: { certificate: identity.certificate, key: identity.key, name: "Legal" })
      tampered = pdf.dup.tap { |bytes| bytes.setbyte(12, bytes.getbyte(12) ^ 1) }

      expect(pdf).to have_signature.and have_signature(name: "Legal")
      expect(pdf).not_to have_signature(name: "Finance")
      expect(tampered).to have_signature(valid: false)
      matcher = have_signature(name: "Finance")
      expect(matcher.matches?(pdf)).to be(false)
      expect(matcher.description).to eq('have a valid signature by "Finance"')
      expect(matcher.failure_message).to eq('expected PDF to have a valid signature by "Finance", got "Legal" (valid)')
      expect(have_signature.tap { |m| m.matches?(tampered) }.failure_message)
        .to eq('expected PDF to have a valid signature, got "Legal" (invalid)')
      expect(have_signature(valid: false).tap { |m| m.matches?(document) }.failure_message)
        .to eq("expected PDF to have an invalid signature, got none")
    end

    it "matches page labels" do
      labelled = Class.new(SpecDocument) do
        page_labels 1 => { style: :roman_lower }, 3 => { style: :decimal }
        def view_template
          3.times do
            text("x")
            page_break
          end
        end
      end.new
      matcher = have_page_labels(%w[i ii 2])

      expect(labelled).to have_page_labels(%w[i ii 1])
      expect(matcher.matches?(labelled)).to be(false)
      expect(matcher.description).to eq('have page labels ["i", "ii", "2"]')
      expect(matcher.failure_message).to eq('expected PDF to have page labels ["i", "ii", "2"], got ["i", "ii", "1"]')
      expect(have_page_labels(%w[i]).tap { |m| m.matches?(document) }.failure_message).to end_with("got none")
    end

    it "matches when every text is tagged or an artifact" do
      matcher = have_tagged_content

      expect(tagged).to have_tagged_content
      expect(matcher.matches?(document)).to be(false)
      expect(matcher.description).to eq("be tagged with every text in marked content")
      expect(matcher.failure_message).to end_with("but it is not tagged")
      expect(matcher.matches?(document.to_pdf(tagged: true))).to be(true)
      expect(matcher.failure_message_when_negated).to end_with("got untagged text []")
    end
  end

  it "reuses an inspector passed as the subject" do
    inspector = Stationery::Testing::Inspector.new(pdf)
    have_page_count(2).matches?(inspector)

    expect(have_no_warnings.tap { |m| m.matches?(inspector) }.failure_message_when_negated).to end_with("got none")
  end
end
