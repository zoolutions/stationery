# frozen_string_literal: true

require_relative "../../examples/packing_slip"

RSpec.describe "the example packing slip" do
  let(:document) { ExamplePackingSlip.preview }
  let(:pdf) { document.to_pdf }
  let(:pages) { reader_for(pdf).pages }

  it "renders three to five landscape A4 pages without warnings" do
    expect(document).to have_no_warnings
    expect(page_count(pdf)).to be_between(3, 5)
    expect(pages.map { |page| page.attributes[:MediaBox].map(&:round) }.uniq).to eq([[0, 0, 842, 595]])
  end

  it "repeats the header and the table header on every page" do
    pages.each_with_index do |page, index|
      expect(page.text).to include("Packing slip · Order NW-2026-004817", "Page #{index + 1} of #{pages.size}")
      expect(page.text).to match(/SKU\s+Description\s+Bin\s+Qty/)
    end
  end

  it "lists every SKU exactly once and totals the quantities" do
    skus = text_of(pdf).scan(/\bNW-\d{5}\b/)

    expect(skus.size).to eq(120)
    expect(skus.uniq.size).to eq(120)
    expect(skus.first).to eq("NW-10000")
    expect(pages.last.text).to match(/120 lines\s+1500\s+3702\.0/)
  end

  it "draws the barcode as filled rectangles on the first page" do
    bars = page_contents(pdf).first.scan(/^[\d.]+ [\d.]+ ([123]) 40 re$/).flatten

    expect(bars.size).to eq(15) # every other digit of 2026004817, three times
    expect(bars.uniq.sort).to eq(%w[1 2 3])
    expect(page_contents(pdf).drop(1).join).not_to match(/ 40 re$/)
  end
end
