# frozen_string_literal: true

# A run of floats taller together than the page, where flows nest. The page
# is 300 × 200 with a 20 pt margin: 160 pt of content height, which two of
# the three floats of 60 pt fit.
RSpec.describe "Floats in a run" do # rubocop:disable RSpec/DescribeClass
  def build(&) = SpecDocument.build(&)

  # Three floats too wide to lie side by side, and the copy after them.
  let(:run_in) do
    lambda do |document, width = 150|
      3.times { document.box(float: :left, width:, height: 60, background: "#DDDDDD") }
      document.text "copy beside it"
    end
  end

  # Per page, how many floats were drawn.
  def floats_of(pdf) = page_contents(pdf).map { |content| content.scan("0.8667 0.8667 0.8667 rg").size }

  def pages_of(pdf) = inspect_pdf(pdf).page_texts

  it "moves the third float of the body to the next page, with the copy" do
    floats = run_in
    document = build { floats.call(self) }

    expect(floats_of(document.to_pdf)).to eq([2, 1])
    expect(pages_of(document.to_pdf)).to eq(["", "copy beside it"])
    expect(document).to have_no_warnings
  end

  it "does so inside a box, which is cut between the floats" do
    floats = run_in
    document = build { box(padding: 5, border: { width: 1 }) { floats.call(self) } }

    expect(floats_of(document.to_pdf)).to eq([2, 1])
    expect(pages_of(document.to_pdf).last).to include("copy beside")
    expect(document).to have_no_warnings
  end

  it "does so inside a box below other content, which moves to the next page first" do
    floats = run_in
    document = build do
      text "A line first."
      box(padding: 5, background: "#EEEEFF") { floats.call(self) }
    end

    expect(floats_of(document.to_pdf)).to eq([0, 2, 1])
    expect(document).to have_no_warnings
  end

  it "does so inside a list item" do
    floats = run_in
    document = build do
      ul do
        li { floats.call(self) }
        li "second"
      end
    end

    expect(floats_of(document.to_pdf)).to eq([2, 1])
    expect(pages_of(document.to_pdf).last).to include("copy beside", "second")
    expect(document).to have_no_warnings
  end

  it "does so inside a table cell, the row cut between the floats" do
    floats = run_in
    document = build { table([[-> { floats.call(self, 120) }, "other"]], width: :full) }

    expect(floats_of(document.to_pdf)).to eq([2, 1])
    expect(pages_of(document.to_pdf).first).to include("other")
    expect(pages_of(document.to_pdf).last).to include("copy beside")
    expect(document).to have_no_warnings
  end

  it "does so inside the column of a row" do
    floats = run_in
    document = build do
      row do
        column { floats.call(self, 80) }
        column { text "other" }
      end
    end

    expect(floats_of(document.to_pdf)).to eq([2, 1])
    expect(document).to have_no_warnings
  end

  it "takes the third float to the next column of `columns`" do
    floats = run_in
    document = build { columns(count: 2, gap: 10) { floats.call(self, 80) } }

    expect(floats_of(document.to_pdf)).to eq([3])
    expect(page_contents(document.to_pdf).first.scan(/^([\d.]+) [\d.]+ 80 60 re$/).flatten).to eq(%w[20 20 155])
    expect(document).to have_no_warnings
  end

  it "keeps the order written in a tagged PDF" do
    document = build do
      3.times { |index| box(float: :left, width: 150, height: 60) { text "float #{index + 1}" } }
      text "copy"
    end
    pdf = document.to_pdf(tagged: true)
    marked = ->((_, _, kids)) { kids.flat_map { |kid| kid.first.is_a?(Symbol) ? marked.call(kid) : [kid] } }

    expect(pages_of(pdf).map { |page| page.scan(/float \d|copy/) }).to eq([["float 1", "float 2"], ["float 3", "copy"]])
    expect(struct_tree(pdf).flat_map(&marked)).to eq([[0, 0], [0, 1], [1, 0], [1, 1]])
    expect(document).to have_no_warnings
  end
end
