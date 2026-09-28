# frozen_string_literal: true

# A landscape packing slip: a long table that repeats its header on every
# page and a barcode drawn on a canvas. Run it to write examples/packing_slip.pdf:
#
#   ruby -Ilib examples/packing_slip.rb
#   ruby -Ilib exe/stationery render examples/packing_slip.rb
require "stationery"

class ExamplePackingSlip < Stationery::Document
  ACCENT = "#1D4ED8"
  INK = "#111827"
  MUTED = "#6B7280"
  HAIRLINE = "#E5E7EB"
  ZEBRA = "#F3F4F6"
  PANEL = "#F9FAFB"

  PRODUCTS = ["Hex bolt M8 × 40, zinc plated", "Washer M8, stainless A2", "Cable tie 200 mm, black",
              "Wall plug 8 mm", "Wood screw 5 × 60, Torx", "Hinge 90 mm, brushed steel",
              "Shelf bracket 200 × 250 mm, white powder coat, including screws and wall plugs for concrete",
              "Drawer runner 450 mm, soft close", "Threaded rod M10 × 1000", "Nylon lock nut M10",
              "Corner brace 40 mm", "Cabinet handle 128 mm, matt black aluminium, for doors up to 22 mm thick"].freeze

  page size: :a4, layout: :landscape, margin: [36, 40, 32, 40]
  default_text size: 9, color: INK
  metadata title: "Packing slip", creator: "stationery example"

  header(gap: 14) do |page|
    row(align: :bottom) do
      text "Packing slip · Order NW-2026-004817", size: 13, weight: :bold
      text "Page #{page.number} of #{page.count}", size: 8, color: MUTED, align: :right
    end
    spacer 6
    rule height: 1.5, color: ACCENT
  end

  footer { text "Check the contents against this slip within 5 days of delivery.", size: 7, color: MUTED }

  def self.preview
    items = Array.new(120) do |i|
      sku = "NW-#{10_000 + (i * 37)}"
      bin = "#{"ABCDEF"[i % 6]}-#{((i % 14) + 1).to_s.rjust(2, "0")}"
      [sku, PRODUCTS[i % PRODUCTS.size], bin, ((i * 7) % 24) + 1, (((i * 13) % 40) + 5) / 10.0]
    end
    new(order: "NW-2026-004817", items:,
        ship_to: ["Hallberg Bygg AB", "Goods reception, gate 4", "Industrigatan 8", "753 23 Uppsala", "Sweden"],
        bill_to: ["Hallberg Bygg AB", "Accounts payable", "Box 1204", "751 42 Uppsala", "Sweden"])
  end

  def initialize(order:, items:, ship_to:, bill_to:)
    super()
    @order = order
    @items = items
    @ship_to = ship_to
    @bill_to = bill_to
  end

  def view_template
    row(gap: 16) do
      column(width: 0.35) { address("SHIP TO", @ship_to) }
      column(width: 0.35) { address("BILL TO", @bill_to) }
      column { barcode }
    end
    spacer 18
    items_table
  end

  private

  def address(label, lines)
    box(background: PANEL, border: { color: HAIRLINE, width: 1 }, radius: 6, padding: [10, 12]) do
      text label, size: 7.5, weight: :bold, color: MUTED, letter_spacing: 0.6
      spacer 4
      text "<b>#{lines.first}</b>\n#{lines.drop(1).join("\n")}", markup: true, leading: 1.5
    end
  end

  def barcode
    digits = @order.delete("^0-9").chars.map(&:to_i)
    canvas(height: 40) do |canvas, rect|
      x = rect.x
      digits.cycle(3).each_with_index do |digit, index|
        width = 1 + (digit % 3)
        canvas.fill_rect(x, rect.y, width, rect.height, color: INK) if index.even?
        x += width + 1
      end
    end
    spacer 4
    text @order, size: 8, color: MUTED, letter_spacing: 2
    spacer 8
    text "Shipped 27 September 2026 · 3 parcels · Example Freight", size: 8, color: MUTED
  end

  def items_table
    rows = [["SKU", "Description", "Bin", "Qty", "Unit (kg)", "Weight (kg)"]]
    @items.each do |sku, name, bin, qty, weight|
      rows << [sku, name, bin, qty.to_s, kilograms(weight), kilograms(qty * weight)]
    end
    rows << [{ content: "#{@items.size} lines", colspan: 3 }, @items.sum { |item| item[3] }.to_s, "",
             kilograms(@items.sum { |*, qty, weight| qty * weight })]

    table(rows, header: true, split_rows: true, width: :full, widths: [80, 300, nil, 60, 70, 80],
                cell: { padding: [2.5, 8], borders: [], size: 8.5 }) do |t|
      t.row(0).set(background: ACCENT, color: "#FFFFFF", weight: :bold)
      t.columns(0).rows(1..).color = MUTED
      t.columns(3..).align = :right
      t.zebra(from: 1, to: @items.size, color: ZEBRA)
      t.row(-1).set(weight: :bold, color: INK, borders: [:top], border_color: INK, border_width: 1)
    end
  end

  def kilograms(value) = format("%.1f", value)
end

if $PROGRAM_NAME == __FILE__
  slip = ExamplePackingSlip.preview
  slip.to_pdf(File.expand_path("packing_slip.pdf", __dir__))
  warn slip.warnings.map(&:message) if slip.warnings.any?
  puts "wrote examples/packing_slip.pdf"
end
