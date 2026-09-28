# frozen_string_literal: true

require_relative "../../examples/resume"

RSpec.describe "the example résumé" do
  let(:document) { ExampleResume.preview }
  let(:pdf) { document.to_pdf }
  let(:page) { inspect_pdf(pdf).layout[:pages].first }

  def line(start) = page[:text].find { |run| run[:text].start_with?(start) }

  it "fits on one page without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
  end

  it "sets the sidebar in the narrow column and the HTML body in the wide one, side by side" do
    sidebar = line("CONTACT")
    body = line("Profile")
    content = 595.28 - 88

    expect(sidebar[:x]).to be < body[:x]
    expect(body[:x] - 44).to be_within(1).of(((content - 24) * 0.3) + 24)
    expect(body[:y]).to be_within(12).of(sidebar[:y])
  end

  it "links the contact lines and the link in the HTML" do
    expect(page[:links].map { |link| link[:uri] }.uniq)
      .to eq(%w[mailto:kim@example.com tel:+46700000000 https://kim.example.com
                https://harbour-logistics.example/graduates])
  end

  it "reads the headings and lists of the HTML" do
    expect(text_of(pdf)).to include("Experience", "Lead engineer · Harbour Logistics", "live replanning", "Education")
  end
end
