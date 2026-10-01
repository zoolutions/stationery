# frozen_string_literal: true

require_relative "../../examples/price_card"

RSpec.describe "the example price card" do
  let(:document) { ExamplePriceCard.preview }
  let(:pdf) { document.to_pdf }
  let(:fields) { inspect_pdf(pdf).layout[:pages].first[:fields] }

  it "fits on one A5 landscape page without warnings" do
    expect(pdf).to have_page_count(1)
    expect(document).to have_no_warnings
  end

  it "writes the alignment, colour and auto-size a viewer redraws an edit with" do
    product, price = form_fields(pdf).values_at("product", "price")

    expect(product).to include(Q: 1, DA: match(%r{\A/F\d+ 0 Tf 0 g\z}))
    expect(price).to include(Q: 1, DA: match(%r{\A/F\d+ 0 Tf 0.8627 0.149 0.149 rg\z}))
    expect(pdf).to have_pdf_text("4 990 kr", fields: true)
  end

  it "reports each field's alignment, size and colour" do
    expect(fields.map { |field| field.slice(:name, :align, :font_size, :color) })
      .to eq([{ name: "product", align: :center, font_size: :auto, color: "#000000" },
              { name: "price", align: :center, font_size: :auto, color: "#DC2626" },
              { name: "unit", align: :center, font_size: 10, color: "#000000" },
              { name: "note", align: :right, font_size: 10, color: "#64748B" }])
  end

  it "draws the price as large as its field allows, and the product's name shrunk to its width" do
    price, product = form_fields(pdf).values_at("price", "product").map { |field| appearance_of(pdf, field) }

    expect(price[%r{ ([\d.]+) Tf}, 1].to_f).to eq(120)
    expect(product[%r{ ([\d.]+) Tf}, 1].to_f).to be_between(14, 32).exclusive
  end
end
