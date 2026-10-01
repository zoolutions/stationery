# frozen_string_literal: true

require_relative "../../examples/price_card"

RSpec.describe "the example price card" do
  let(:document) { ExamplePriceCard.preview }
  let(:pdf) { document.to_pdf }
  let(:fields) { inspect_pdf(pdf).layout[:pages].first[:fields] }

  def size_in(operators) = operators[/ ([\d.]+) Tf/, 1].to_f

  it "fits on one A5 landscape page without warnings" do
    expect(pdf).to have_page_count(1)
    expect(document).to have_no_warnings
  end

  it "writes the alignment, colour and the fitted size a viewer redraws an edit with" do
    product, price = form_fields(pdf).values_at("product", "price")

    expect(product).to include(Q: 1, DA: match(%r{\A/F\d+ [\d.]+ Tf 0 g\z}))
    expect(price).to include(Q: 1, DA: match(%r{\A/F\d+ 120 Tf 0.8627 0.149 0.149 rg\z}))
    [product, price].each { |field| expect(size_in(field[:DA])).to eq(size_in(appearance_of(pdf, field))) }
    expect(pdf).to have_pdf_text("4 990 kr", fields: true)
  end

  it "reports each field's alignment, size and colour" do
    expect(fields.map { |field| field.slice(:name, :align, :font_size, :color) })
      .to eq([{ name: "product", align: :center, font_size: size_in(form_fields(pdf)["product"][:DA]),
                color: "#000000" },
              { name: "price", align: :center, font_size: 120, color: "#DC2626" },
              { name: "unit", align: :center, font_size: 10, color: "#000000" },
              { name: "note", align: :right, font_size: 10, color: "#64748B" }])
  end

  it "draws the price as large as its field allows, and the product's name shrunk to its width" do
    price, product = form_fields(pdf).values_at("price", "product").map { |field| appearance_of(pdf, field) }

    expect(size_in(price)).to eq(120)
    expect(size_in(product)).to be_between(14, 32).exclusive
  end
end
