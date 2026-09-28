# frozen_string_literal: true

require_relative "../../examples/flyer"

RSpec.describe "the example flyer" do
  let(:document) { ExampleFlyer.preview }
  let(:pdf) { document.to_pdf }

  it "renders a tagged A4 flyer without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(4)
    expect(pdf).to have_pdf_language("en")
    expect(pdf).to have_tagged_content
  end

  it "bookmarks every section" do
    expect(pdf).to have_bookmark("Life at Harbourside").and have_bookmark("Prices").and have_bookmark("Impressions")
  end

  it "embeds the cover, the collage, the cards and the gallery as figures" do
    expect(pdf).to have_image_count(7) # seven distinct files, each embedded once
    expect(inspect_pdf(pdf).structure.to_s.scan("Figure").size).to eq(12)
  end

  it "links the call to action" do
    expect(pdf).to have_pdf_link("https://harbourside.example/apply")
    expect(pdf).to have_pdf_text(/Apply for a call/)
  end
end
