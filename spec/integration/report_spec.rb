# frozen_string_literal: true

require_relative "../../examples/report"

RSpec.describe "the example report" do
  let(:document) { ExampleReport.preview }
  let(:pdf) { document.to_pdf }
  let(:pages) { reader_for(pdf).pages }
  let(:headings) do
    { "Introduction" => "1. Introduction", "Highlights" => "2. Highlights of the year",
      "Financial review" => "3. Financial review", "Operations" => "4. Operations",
      "Risks" => "5. Risks and uncertainties", "Appendix" => "6. Appendix" }
  end

  def page_of(heading)
    pages.each_with_index.find { |page, index| index > 1 && page.text.include?(heading) }&.last
  end

  it "renders six to eight pages without warnings" do
    expect(document).to have_no_warnings
    expect(page_count(pdf)).to be_between(6, 8)
    expect(pdf).to have_pdf_text("Moving more with less")
  end

  it "repeats the header on every page but the cover and the footer on every page" do
    expect(pages.first.text).not_to include("Page 1 of")
    pages.each_with_index.drop(1).each do |page, index|
      expect(page.text).to include("Page #{index + 1} of #{pages.size}")
    end
    expect(pages).to all(have_attributes(text: include("Confidential.")))
  end

  it "nests level-2 bookmarks under their sections" do
    outline = outline_of(pdf)

    expect(pdf).to have_bookmark("Introduction")
    expect(outline.map { |entry| entry[:title] }).to eq(["Contents", *headings.keys])
    expect(outline[1][:children].map { |entry| entry[:title] })
      .to eq(["About this report", "A word from the chief executive"])
    expect(outline.last[:children].map { |entry| entry[:title] }).to eq(["Definitions", "Five-year summary"])
  end

  it "lists the page each section heading actually landed on in the contents" do
    contents = pages[1].text.lines.map(&:strip)

    headings.each do |title, heading|
      line = contents.find { |entry| entry.start_with?(title) }
      expect(line[/(\d+)\z/, 1].to_i).to eq(page_of(heading) + 1), "#{title}: #{line.inspect}"
    end
  end

  it "points the outline and the internal links at the right pages" do
    appendix = page_of("6. Appendix")
    intro = page_of("1. Introduction")
    links = link_destinations(pdf)

    expect(outline_of(pdf).find { |entry| entry[:title] == "Appendix" }[:page]).to eq(appendix)
    expect(links).to include([intro, appendix, anything], [appendix, intro, anything])
    expect(links.count { |from, _, _| from == 1 }).to eq(15) # one per contents row
  end

  it "splits the callout box across a page break" do
    first = page_of("What we learned from electrifying linehaul")

    expect(pages[first + 1].text).to include("Next year we will extend the programme")
  end
end
