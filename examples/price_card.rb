# frozen_string_literal: true

# A shop-window price card a person fills in on screen and prints: the
# product's name centred and shrunk to fit its line, the price large,
# centred and red, the price per unit right-aligned in grey and a select of
# units. The name and price are fitted by the gem and the size it chose is
# written to the file (`font_size: :fit`), so every viewer shows them at
# that size. The fields have no border and no background, so the printed
# card shows the values alone; a viewer that redraws a field after an edit
# keeps its alignment, colour and size (/Q and /DA). Run it to write
# examples/price_card.pdf:
#
#   ruby -Ilib examples/price_card.rb
#   ruby -Ilib exe/stationery render examples/price_card.rb
require "stationery"

class ExamplePriceCard < Stationery::Document
  INK = "#0F172A"
  SALE = "#DC2626"
  MUTED = "#64748B"
  HAIRLINE = "#E2E8F0"
  UNITS = ["per piece", "per kg", "per litre", "per pack"].freeze
  BARE = { border: nil, background: nil }.freeze

  page size: :a5, layout: :landscape, margin: 36
  default_text size: 12, color: INK
  metadata title: "Price card", author: "Corner Coffee Shop", creator: "stationery example", lang: "en"

  footer do
    rule height: 0.5, color: HAIRLINE
    spacer 6
    text "All prices include 25% VAT · Corner Coffee Shop, Stortorget 4, Lund", size: 8, color: MUTED,
                                                                                align: :center
  end

  def self.preview
    new(product: "Espresso machine Deluxe 3000 with milk frother", price: "4 990 kr",
        unit_price: "Was 5 990 kr · save 1 000 kr", unit: "per piece")
  end

  def initialize(product: "", price: "", unit_price: "", unit: UNITS.first)
    super()
    @product = product
    @price = price
    @unit_price = unit_price
    @unit = unit
  end

  def view_template
    text "Corner Coffee Shop", size: 16, weight: :bold, align: :center
    spacer 4
    rule height: 1.5, color: INK
    spacer 10
    label "Product"
    text_style(weight: :bold) do
      text_field "product", value: @product, height: 44, font_size: :fit, max_font_size: 32, align: :center,
                            tooltip: "Product", **BARE
    end
    rule height: 0.5, color: HAIRLINE
    spacer 10
    label "Price"
    text_style(weight: :bold) do
      text_field "price", value: @price, height: 150, font_size: :fit, max_font_size: 120, align: :center,
                          color: SALE, tooltip: "Price", **BARE
    end
    spacer 6
    row(gap: 12) do
      column(width: 150) do
        select "unit", options: UNITS, value: @unit, height: 22, align: :center, tooltip: "Unit", **BARE
      end
      column do
        text_field "note", value: @unit_price, height: 22, align: :right, color: MUTED, tooltip: "Note", **BARE
      end
    end
  end

  private

  def label(title) = text(title.upcase, size: 8, color: MUTED, letter_spacing: 1, align: :center)
end

if $PROGRAM_NAME == __FILE__
  card = ExamplePriceCard.preview
  card.to_pdf(File.expand_path("price_card.pdf", __dir__))
  warn card.warnings.map(&:message) if card.warnings.any?
  puts "wrote examples/price_card.pdf"
end
