# frozen_string_literal: true

# A 4 × 6 in shipping label for a thermal label printer, in black and white
# only, with a Code 128 and a QR code, written as a PDF and as ZPL whose
# barcodes the printer draws itself (`native: true`). Run it to write
# examples/shipping_label.pdf and examples/shipping_label.zpl:
#
#   ruby -Ilib examples/shipping_label.rb
#   ruby -Ilib exe/stationery render examples/shipping_label.rb --zpl --dpi 203
require "stationery"

class ExampleShippingLabel < Stationery::Document
  page size: "4in x 6in", margin: mm(4)
  max_pages 1 # one label: what does not fit warns, and to_zpl writes no second label
  monochrome dpi: 203
  default_text size: 10
  metadata title: "Shipping label", creator: "stationery example"

  def self.preview
    new(parcel: "SX 0042 7719 03", service: "EXPRESS", weight: "2.4 kg", route: "R-07",
        from: ["Northwind Supplies", "Unit 5, Harbour Road", "40115 Gothenburg", "Sweden"],
        to: ["Ada Example", "Example Workshop Ltd", "12 Sample Street", "3011 Testville", "Netherlands"])
  end

  def initialize(parcel:, service:, weight:, route:, from:, to:)
    super()
    @parcel = parcel
    @service = service
    @weight = weight
    @route = route
    @from = from
    @to = to
  end

  def view_template
    row(gap: 8) do
      column(width: 0.62) { address("FROM", @from, size: 9) }
      column { service }
    end
    spacer 8
    rule height: 2
    spacer 10
    address("SHIP TO", @to, size: 14)
    spacer 12
    rule height: 2
    spacer 10
    row(gap: 8, align: :center) do
      column(width: 0.36) { detail("ROUTE", @route) }
      column(width: 0.36) { detail("WEIGHT", @weight) }
      column { barcode "https://track.example/#{code}", type: :qr, module_size: 1.4, align: :right, native: true }
    end
    spacer 10
    box(border: { width: 3 }, padding: 10) do
      text "PARCEL", size: 8, weight: :bold
      spacer 6
      barcode code, module_size: 1.5, height: 44, align: :center, native: true
      spacer 4
      text @parcel, size: 14, weight: :bold, letter_spacing: 1, align: :center
    end
    spacer 10
    text "Keep dry · This side up", size: 9, align: :center
  end

  private

  def code = @parcel.delete(" ")

  def address(label, lines, size:)
    text label, size: 8, weight: :bold, letter_spacing: 0.6
    spacer 3
    text "<b>#{lines.first}</b>\n#{lines.drop(1).join("\n")}", size:, markup: true, leading: 1.5
  end

  def service
    box(background: "#000000", padding: [10, 6]) do
      text @service, size: 16, weight: :bold, color: "#FFFFFF", align: :center
    end
  end

  def detail(label, value)
    text label, size: 8, weight: :bold, letter_spacing: 0.6
    spacer 2
    text value, size: 20, weight: :bold
  end
end

if $PROGRAM_NAME == __FILE__
  label = ExampleShippingLabel.preview
  label.to_pdf(File.expand_path("shipping_label.pdf", __dir__))
  label.to_zpl(File.expand_path("shipping_label.zpl", __dir__))
  warn label.warnings.map(&:message) if label.warnings.any?
  puts "wrote examples/shipping_label.pdf and examples/shipping_label.zpl"
end
