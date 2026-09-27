# frozen_string_literal: true

require_relative "../../examples/postcard"

RSpec.describe "the example postcard" do
  let(:document) { ExamplePostcard.preview }
  let(:pdf) { document.to_pdf }

  it "fits on one tagged page without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
    expect(pdf).to have_image_count(3)
    expect(pdf).to have_pdf_language("en")
    expect(pdf).to have_tagged_content
  end

  it "shows the greeting and the three photos as figures" do
    expect(pdf).to have_pdf_text(/Greetings from\s+Sardinia/)
    expect(inspect_pdf(pdf).structure.to_s.scan("Figure").size).to eq(3)
  end
end
