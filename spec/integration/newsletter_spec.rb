# frozen_string_literal: true

require_relative "../../examples/newsletter"

RSpec.describe "the example newsletter" do
  let(:document) { ExampleNewsletter.preview }
  let(:pdf) { document.to_pdf }
  let(:runs) { inspect_pdf(pdf).reader.pages.first.runs }

  def run_at(start) = runs.find { |run| run.text.start_with?(start) }

  it "fits on one tagged page without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
    expect(pdf).to have_image_count(1)
    expect(pdf).to have_pdf_language("en")
    expect(pdf).to have_tagged_content
  end

  it "pours the article through two columns under the masthead" do
    lead = run_at("The harbour wall")
    second = run_at("What it cost")

    expect(lead.origin.x).to be_within(0.01).of(48)
    expect(second.origin.x).to be_within(0.01).of(48 + ((595.28 - 96 - 22) / 2) + 22)
    expect(second.origin.y).to be_within(6).of(lead.origin.y)
    expect(lead.origin.y).to be < run_at("The sea wall").origin.y
  end

  it "ends the columns at nearly the same height, with the note across the page below both" do
    left, right = runs.select { |run| run.origin.y < run_at("The harbour wall").origin.y + 1 }
                      .reject { |run| run.text.start_with?("The Harbour Letter is", "house, where") }
                      .partition { |run| run.origin.x < 297 }
    note = run_at("The Harbour Letter is")

    expect((left.map { |run| run.origin.y }.min - right.map { |run| run.origin.y }.min).abs).to be < 30
    expect(note.origin.y).to be < [*left, *right].map { |run| run.origin.y }.min
    expect(note.origin.x).to be < 297
  end

  it "reads the first column before the second" do
    drawn = strings_of(pdf).join
    order = ["The harbour wall", "The bay from", "What it cost", "What comes next", "The Harbour Letter is"]

    expect(order.map { |start| drawn.index(start) }).to eq(order.map { |start| drawn.index(start) }.sort)
    expect(inspect_pdf(pdf).structure.to_s.scan("H2").size).to eq(2)
  end
end
