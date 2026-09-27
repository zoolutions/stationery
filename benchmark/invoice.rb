# frozen_string_literal: true

# A one-page invoice: examples/invoice.rb against the same layout hand-written
# with Prawn and prawn-table.
#
#   bundle exec ruby -Ilib benchmark/invoice.rb
require_relative "support"
require_relative "../examples/invoice"

module PrawnInvoice
  module_function

  def render
    pdf = Prawn::Document.new(page_size: "A4", margin: [40, 44, 56, 44])
    Bench.prawn_fonts(pdf)
    header(pdf)
    amount_due(pdf)
    line_items(pdf)
    footer(pdf)
    pdf.render
  end

  def header(pdf)
    pdf.text "Invoice INV-2026-042", size: 22, style: :bold
    pdf.move_down 10
    pdf.stroke_color "4F46E5"
    pdf.line_width 3
    pdf.stroke_horizontal_rule
    pdf.move_down 18
  end

  def amount_due(pdf)
    total = Bench::INVOICE_ITEMS.sum { |_, qty, price| qty * price } * 1.25
    pdf.bounding_box([pdf.bounds.width - 190, pdf.cursor], width: 190, height: 70) do
      pdf.fill_color "F3F4F6"
      pdf.fill_rounded_rectangle [0, 70], 190, 70, 6
      pdf.fill_color "6B7280"
      pdf.text_box "AMOUNT DUE", at: [12, 58], size: 8, style: :bold
      pdf.fill_color "4F46E5"
      pdf.text_box Bench.money(total), at: [12, 44], size: 19, style: :bold
    end
    pdf.fill_color "1F2937"
    pdf.move_down 26
  end

  def line_items(pdf)
    rows = [%w[Description Qty Price VAT Amount]]
    Bench::INVOICE_ITEMS.each do |name, qty, price|
      rows << [name, qty.to_s, Bench.money(price), "25%", Bench.money(qty * price)]
    end
    pdf.table(rows, width: pdf.bounds.width, header: true, column_widths: { 1 => 45, 2 => 80, 3 => 60, 4 => 85 },
                    cell_style: { padding: [7, 8], borders: [] }) do |t|
      t.row(0).background_color = "4F46E5"
      t.row(0).text_color = "FFFFFF"
      t.row(0).font_style = :bold
      t.columns(1..4).align = :right
      t.row_colors = %w[FFFFFF F9FAFB]
    end
  end

  def footer(pdf)
    pdf.move_down 28
    pdf.text "Thank you for your business", size: 9, style: :bold
    pdf.move_down 3
    pdf.text "Pay to IBAN SE45 5000 0000 0583 9825 7466 within 30 days. Questions? hello@acme.test", size: 8.5
  end
end

def stationery_invoice
  ExampleInvoice.new(number: "INV-2026-042", items: Bench::INVOICE_ITEMS,
                     customer: "Müller & Söhne GmbH", due: "26 October 2026").to_pdf
end

Bench.compare("stationery" => -> { stationery_invoice }, "prawn" => -> { PrawnInvoice.render })
