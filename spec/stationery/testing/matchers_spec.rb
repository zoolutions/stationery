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

  it "matches a document without warnings" do
    expect(document).to have_no_warnings
    expect(have_no_warnings.description).to eq("have no warnings")
  end

  it "lists the warnings of an overflowing document" do
    matcher = have_no_warnings
    overflowing = SpecDocument.build { box { 40.times { |i| text "row #{i}" } } }

    expect(matcher.matches?(overflowing)).to be(false)
    expect(matcher.failure_message).to match(/\Aexpected PDF to have no warnings, got:\n  - content .+ on page 1/)
    expect(matcher.failure_message_when_negated).to start_with("expected PDF not to have no warnings")
  end

  it "reuses an inspector passed as the subject" do
    inspector = Stationery::Testing::Inspector.new(pdf)
    have_page_count(2).matches?(inspector)

    expect(have_no_warnings.tap { |m| m.matches?(inspector) }.failure_message_when_negated).to end_with("got none")
  end
end
