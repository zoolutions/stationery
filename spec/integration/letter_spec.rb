# frozen_string_literal: true

require_relative "../../examples/letter"

RSpec.describe "the example letter" do
  let(:document) { ExampleLetter.preview }
  let(:pdf) { document.to_pdf }

  it "fits on one page without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
  end

  it "prints the letterhead, recipient, subject, body, signature and registration line in order" do
    text = text_of(pdf)
    order = ["Mälaren Studio", "Ms Anna Hallberg", "Proposal for the redesign of your customer portal",
             "Dear Ms Hallberg,", "SEK 480,000", "Kind regards,", "Erik Sandberg", "Org. nr 559123-4567"]

    expect(order.map { |fragment| text.index(fragment) }).to eq(order.map { |fragment| text.index(fragment) }.sort)
    expect(order).to all(satisfy { |fragment| text.include?(fragment) })
  end

  it "links the full proposal with a single annotation" do
    expect(pdf).to have_pdf_link("https://malaren.studio/p/MS-2026-118")
    expect(link_rects(pdf).size).to eq(1)
  end

  it "draws the logo as vector paths, not an image" do
    expect(pdf).to have_image_count(0)
    expect(page_contents(pdf).first).to match(/\bc\n/) # the rounded square's curves
  end
end
