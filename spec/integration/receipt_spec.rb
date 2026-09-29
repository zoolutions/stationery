# frozen_string_literal: true

require_relative "../../examples/receipt"

RSpec.describe "the example receipt" do
  let(:document) { ExampleReceipt.preview }
  let(:pdf) { document.to_pdf }
  let(:page) { inspect_pdf(pdf).layout[:pages].first }

  it "fits on one page of an 80 mm roll without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
    expect(page[:width]).to eq(226.8)
  end

  it "adds the items up, VAT by rate, to the total paid" do
    expect(text_of(pdf)).to match(/A 25%\s+€13,12\s+€3,28\s+€16,40/).and match(/B 12%\s+€25,45\s+€3,05\s+€28,50/)
    expect(text_of(pdf)).to match(/Subtotal\s+€38,57\s+VAT\s+€6,33\s+TOTAL\s+€44,90/)
    expect(text_of(pdf)).to include("Card **** 4242", "Paid €44,90")
  end

  it "paints in black only, the logo as a one-bit image" do
    expect(pdf).to have_pdf_colors("#000000")
    expect(pdf).to include("/BitsPerComponent 1")
  end

  it "draws the cut line on a canvas, dashed" do
    expect(page_contents(pdf).first).to include("[3 2] 0 d")
  end
end
