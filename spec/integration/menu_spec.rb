# frozen_string_literal: true

require_relative "../../examples/menu"

RSpec.describe "the example menu" do
  let(:document) { ExampleMenu.preview }
  let(:pdf) { document.to_pdf }
  let(:page) { inspect_pdf(pdf).layout[:pages].first }

  def line(start) = page[:text].find { |run| run[:text].start_with?(start) }

  it "fits on one page without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
    expect(pdf).to have_image_count(1)
  end

  it "wraps the introduction between the floated photo and the dish of the day, then below both" do
    photo = page[:images].first
    special = line("DISH OF THE DAY")
    beside = page[:text].select { |run| run[:y].between?(photo[:y], photo[:y] + photo[:height]) }
    intro = beside.select { |run| run[:font] == "Inter-Regular" && run[:size].between?(10, 11) }

    expect(photo[:x]).to eq(56)
    expect(intro.map { |run| run[:x] }).to all(be > photo[:x] + photo[:width])
    expect(intro.map { |run| run[:x] }).to all(be < special[:x])
    expect(page[:text].find { |run| run[:text].end_with?("evening does.") }[:x]).to eq(56)
  end

  it "pours the courses through two columns, a course never split between them" do
    starts = %w[Starters Mains Desserts].to_h { |course| [course, line(course)] }
    middle = 595.28 / 2

    expect(starts.values_at("Starters", "Mains").map { |run| run[:x] }).to all(be < middle)
    expect(starts["Desserts"][:x]).to be > middle
    expect(starts["Desserts"][:y]).to be_within(1).of(starts["Starters"][:y])
    expect(line("Harbour burger")[:x]).to be < middle
  end
end
