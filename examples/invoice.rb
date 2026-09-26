# frozen_string_literal: true

# An invoice built with stationery. Run it to write examples/invoice.pdf:
#
#   ruby -Ilib examples/invoice.rb
require "stationery"

class ExampleInvoice < Stationery::Document
  FONTS = File.expand_path("../spec/fixtures/fonts", __dir__)
  LOGO = File.expand_path("assets/logo.png", __dir__)

  ACCENT = "#4F46E5"
  INK = "#1F2937"
  MUTED = "#6B7280"
  HAIRLINE = "#E5E7EB"
  ZEBRA = "#F9FAFB"
  CALLOUT = "#F3F4F6"

  page size: :a4, margin: [40, 44, 56, 44]
  font_family "Open Sans",
              regular: File.join(FONTS, "OpenSans-Regular.ttf"), bold: File.join(FONTS, "OpenSans-Bold.ttf"),
              italic: File.join(FONTS, "OpenSans-Italic.ttf"), bold_italic: File.join(FONTS, "OpenSans-BoldItalic.ttf")
  default_text font: "Open Sans", size: 9, color: INK
  metadata title: "Invoice", creator: "stationery example"

  page_template do |page|
    box(at: [page.margin[3], page.height - 34], width: page.content_box.width) do
      text "Page #{page.number} of #{page.count}", size: 7, color: MUTED, align: :right
    end
  end

  def initialize(number:, items:, customer:, due:)
    super()
    @number = number
    @items = items
    @customer = customer
    @due = due
  end

  def view_template
    header
    spacer 18
    summary
    spacer 22
    parties
    spacer 26
    line_items
    spacer 28
    footer
  end

  private

  def header
    row(align: :middle) do
      column(width: 0.5) { text "Invoice #{@number}", size: 22, weight: :bold }
      column(width: 0.5, align: :right) { image LOGO, height: 34, align: :right }
    end
    spacer 10
    rule height: 3, color: ACCENT
  end

  def summary
    row(gap: 24) do
      column do
        table([["Invoice date", "26 September 2026"], ["Due date", @due], ["Reference", "PO-7781"]],
              widths: [90, nil], cell: { borders: [], padding: [1, 12, 2, 0], color: MUTED }) do |t|
          t.column(0).weight = :bold
          t.column(0).color = INK
        end
      end
      column(width: 190) { amount_due }
    end
  end

  def amount_due
    box(background: CALLOUT, radius: 6, padding: 12) do
      text "AMOUNT DUE", size: 8, weight: :bold, color: MUTED, letter_spacing: 0.5
      text money(total), size: 19, weight: :bold, color: ACCENT
      spacer 6
      row { column(width: :auto) { status_pill("OPEN", "#3B82F6") } }
    end
  end

  def status_pill(label, color)
    box(background: color, radius: 7, padding: [2, 9]) { text label, size: 7, weight: :bold, color: "#FFFFFF" }
  end

  def parties
    row(gap: 24) do
      column(width: 0.5) do
        party("FROM", ["<b>Acme Studio AB</b>", "Storgatan 1", "111 22 Stockholm", "hello@acme.test"])
      end
      column(width: 0.5) { party("BILL TO", ["<b>#{@customer}</b>", "Hauptstraße 5", "10115 Berlin"]) }
    end
  end

  def party(label, lines)
    text label, size: 8, weight: :bold, color: MUTED, letter_spacing: 0.5
    spacer 3
    text lines.join("\n"), markup: true, leading: 1
  end

  def line_items
    rows = [%w[Description Qty Price VAT Amount]]
    @items.each { |name, qty, price| rows << [name, qty.to_s, money(price), "25%", money(qty * price)] }
    rows << ["", "", "", "Subtotal", money(subtotal)]
    rows << ["", "", "", "VAT 25%", money(vat)]
    rows << ["", "", "", "Total", money(total)]
    count = @items.size

    table(rows, width: :full, widths: [nil, 45, 80, 60, 85], header: true,
                cell: { padding: [7, 8], borders: [] }) do |t|
      t.row(0).set(background: ACCENT, color: "#FFFFFF", weight: :bold)
      t.columns(1..).align = :right
      t.zebra(from: 2, to: count, color: ZEBRA)
      t.row(count + 1).columns(3..).set(borders: [:top], border_color: HAIRLINE, border_width: 1)
      t.row(-1).set(weight: :bold, size: 11)
    end
  end

  def footer
    group(keep_together: true) do
      rule height: 1, color: HAIRLINE
      spacer 14
      text "Thank you for your business", size: 9, weight: :bold
      spacer 3
      text "Pay to IBAN SE45 5000 0000 0583 9825 7466 within 30 days. Questions? " \
           "<link href='mailto:hello@acme.test'><color rgb='#{ACCENT}'>hello@acme.test</color></link>",
           markup: true, size: 8.5, color: MUTED, leading: 2
    end
  end

  def subtotal = @items.sum { |_, qty, price| qty * price }
  def vat = (subtotal * 0.25).round(2)
  def total = subtotal + vat

  def money(amount)
    whole, cents = format("%.2f", amount).split(".")
    "€#{whole.reverse.scan(/\d{1,3}/).join(" ").reverse},#{cents}"
  end
end

if $PROGRAM_NAME == __FILE__
  items = [["Brand workshop", 1, 2400.0], ["Logo design, three concepts", 1, 3200.0],
           ["Illustration set (12)", 12, 180.0], ["Print-ready files", 1, 450.0], ["Rush delivery", 1, 300.0]]
  ExampleInvoice.new(number: "INV-2026-042", items:, customer: "Müller & Söhne GmbH", due: "26 October 2026")
                .to_pdf(File.expand_path("invoice.pdf", __dir__))
  puts "wrote examples/invoice.pdf"
end
