# frozen_string_literal: true

require_relative "../../examples/invoice"

RSpec.describe "the example invoice" do
  let(:items) do
    [["Brand workshop", 1, 2400.0], ["Logo design", 1, 3200.0], ["Illustration set (12)", 12, 180.0]]
  end

  def render(items: self.items)
    ExampleInvoice.new(number: "INV-7", items:, customer: "Müller & Söhne GmbH", due: "1 Nov 2026").to_pdf
  end

  it "prints the title, amount due, parties, every line item in order and the total" do
    text = text_of(render)

    expect(text).to include("Invoice INV-7", "AMOUNT DUE", "€9 700,00", "FROM", "BILL TO", "Müller & Söhne GmbH")
    expect(text.index("Brand workshop")).to be < text.index("Logo design")
    expect(text.index("Logo design")).to be < text.index("Illustration set (12)")
    expect(text).to include("Total", "€9 700,00")
  end

  it "embeds the logo once and links the contact address" do
    pdf = render

    expect(pdf).to have_image_count(2) # the logo and its alpha soft mask
    expect(pdf).to have_pdf_link("mailto:hello@acme.test")
  end

  it "right-aligns the amount column" do
    pdf = render
    strings = strings_of(pdf)
    positions = positions_of(pdf)
    font = Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(font_path("OpenSans-Regular.ttf")))
    right_edges = ["€2 400,00", "€3 200,00", "€2 160,00"].map do |amount|
      index = strings.rindex(amount)
      positions[index].first + font.width_of(amount, 9, kerning: true)
    end

    expect(right_edges.uniq { |edge| edge.round(2) }.size).to eq(1)
  end

  it "paginates a long invoice, repeating the table header and numbering the pages" do
    pdf = render(items: Array.new(80) { |i| ["Item #{i + 1}", 1, 10.0] })
    pages = reader_for(pdf).pages

    expect(pdf).to have_pdf_text_on_page(pages.size, "Page #{pages.size} of #{pages.size}")
    expect(pages.size).to be >= 3
    pages.drop(1).each { |page| expect(page.text).to include("Description") }
    expect(pages.last.text).to include("Page #{pages.size} of #{pages.size}", "Total")
    expect(text_of(pdf).scan(/Item \d+\b/).uniq.size).to eq(80)
  end

  it "survives characters outside ASCII" do
    expect(render(items: [["Café crème — Ångström", 1, 5.0]])).to have_pdf_text("Café crème — Ångström")
  end
end
