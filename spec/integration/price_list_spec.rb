# frozen_string_literal: true

require_relative "../../examples/price_list"

RSpec.describe "the example price list" do
  let(:document) { ExamplePriceList.new(ExamplePriceList.articles(400)) }
  let(:pdf) { document.to_pdf }
  let(:pages) { reader_for(pdf).pages }

  it "reads the same articles from its Enumerator every time" do
    first = ExamplePriceList.articles(50).to_a

    expect(ExamplePriceList.articles(50).to_a).to eq(first)
    expect(first.map(&:number).uniq.size).to eq(50)
  end

  it "lists every article once, over as many pages as it takes, without warnings" do
    numbers = text_of(pdf).scan(/\bEP-\d{5}\b/)

    expect(document).to have_no_warnings
    expect(numbers.size).to eq(400)
    expect(numbers.uniq.size).to eq(400)
    expect(pages.size).to be > 5
  end

  it "repeats the header and the table's header row on every page" do
    pages.each_with_index do |page, index|
      expect(page.text).to include("Example Provisions · Price list 2027", "Page #{index + 1} of #{pages.size}")
      expect(page.text).to match(/Article\s+Description\s+Unit\s+Pack\s+Per unit\s+Per pack/)
    end
  end

  it "is incremental, and writes the pages it would write without" do
    expect(ExamplePriceList.config[:incremental]).to be(true)
    expect(text_of(document.to_pdf(incremental: false))).to eq(text_of(pdf))
  end
end
