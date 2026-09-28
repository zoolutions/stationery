# frozen_string_literal: true

require_relative "../../examples/article"

RSpec.describe "the example article" do
  let(:document) { ExampleArticle.preview }
  let(:pdf) { document.to_pdf }

  # The left edge of every line of text on the page, top to bottom.
  def starts(pdf)
    reader_for(pdf).pages.first.runs.group_by { |run| run.origin.y.round }.sort.reverse
                   .map { |_, runs| runs.map(&:x).min.round }
  end

  it "fits on one tagged page without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
    expect(pdf).to have_image_count(2)
    expect(pdf).to have_pdf_language("en")
    expect(pdf).to have_tagged_content
  end

  it "wraps the story around the photo and the pull quote" do
    lines = starts(pdf)
    margin = 72
    beside_photo = lines.select { |x| x > margin + 150 && x < margin + 250 }

    expect(beside_photo.size).to be >= 8
    expect(beside_photo.uniq.size).to eq(1)
    expect(lines.count(margin)).to be > 15
    expect(strings_of(pdf)).to include("There is no path to", "is everywhere.")
  end

  it "tags the photos as figures and the pull quote as a block quote, in reading order" do
    structure = inspect_pdf(pdf).structure.to_s

    expect(structure.scan("Figure").size).to eq(2)
    expect(structure).to match(/H1.*Figure.*BlockQuote.*H2.*Figure/m)
  end
end
