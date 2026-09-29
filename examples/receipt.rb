# frozen_string_literal: true

# A till receipt on an 80 mm roll, in black and white only: a logo, the
# items with their VAT rates, VAT by rate, the total and the payment, a QR
# code of the receipt online, and a cut line drawn on a `canvas` above a
# coupon. Run it to write examples/receipt.pdf:
#
#   ruby -Ilib examples/receipt.rb
#   ruby -Ilib exe/stationery render examples/receipt.rb --png
require "stationery"

class ExampleReceipt < Stationery::Document
  LOGO = File.expand_path("assets/logo.png", __dir__)
  RATES = { "A" => 25, "B" => 12 }.freeze

  # A receipt printer feeds the roll for as long as there is something to
  # print and cuts it after the last line. A PDF page has a length, so this
  # one is as long as its content: 80 mm wide (72 mm of it printable) and
  # 195 mm long. A printer driver set to the roll prints it as it is.
  #
  # Receipt printers print one bit at 203 dpi. `snap: true` makes every colour
  # black or white and puts rules on the printer's dots; `dither: :threshold`
  # cuts the colour logo at half, so its letters stay clean instead of
  # speckled. They are driven in ESC/POS, not ZPL: `to_zpl` is for label
  # printers, and ESC/POS is not something Stationery writes. Print the PDF,
  # or send `to_png` to a driver that takes a picture.
  page size: [mm(80), mm(195)], margin: [mm(4), mm(4), mm(6), mm(4)]
  max_pages 1 # one slip of paper: what does not fit warns instead of starting a second
  monochrome dpi: 203, snap: true, dither: :threshold
  default_text size: 8.5, leading: 1.5
  metadata title: "Receipt", creator: "stationery example"

  def self.preview
    items = [["Sourdough loaf", 1, 4.20, "B"], ["Oat milk 1 l", 2, 1.95, "B"], ["Espresso beans 500 g", 1, 12.90, "B"],
             ["Cinnamon bun", 3, 2.50, "B"], ["Beeswax candle", 1, 9.80, "A"], ["Linen tea towel", 1, 6.60, "A"]]
    new(number: "TR-0417-2291", at: "29 Sep 2026 10:42", till: "Till 2 · Sam", items:,
        payment: { method: "Card **** 4242", reference: "Auth 318204" })
  end

  def initialize(number:, at:, till:, items:, payment:)
    super()
    @number = number
    @at = at
    @till = till
    @items = items
    @payment = payment
  end

  def view_template
    header
    dashes
    line_items
    dashes
    totals
    dashes
    vat
    spacer 6
    payment
    spacer 10
    online
    spacer 10
    cut_line
    spacer 8
    coupon
  end

  private

  def header
    image LOGO, height: 30, align: :center
    spacer 6
    text "Acme Pantry\n12 Sample Street, 3011 Testville\nVAT no. XX 0123 4567 89", align: :center, size: 8
    spacer 6
    row do
      column { text "#{@number}\n#{@till}", size: 8 }
      column { text @at, size: 8, align: :right }
    end
  end

  def line_items
    rows = @items.map do |name, qty, price, rate|
      [qty > 1 ? "#{name}\n  #{qty} × #{money(price)}" : name, money(qty * price), rate]
    end
    table(rows, width: :full, widths: [nil, 56, 12], cell: { borders: [], padding: [1, 0] }) do |t|
      t.columns(1..).align = :right
    end
  end

  def totals
    table([["Subtotal", money(total - vat_total)], ["VAT", money(vat_total)]],
          width: :full, widths: [nil, 70], cell: { borders: [], padding: [1, 0] }) do |t|
      t.column(1).align = :right
    end
    spacer 3
    row do
      column { text "TOTAL", size: 13, weight: :bold }
      column { text money(total), size: 13, weight: :bold, align: :right }
    end
  end

  # Prices include VAT, as a till's do: the VAT in a gross amount at r % is
  # gross × r / (100 + r).
  def vat
    rows = [%w[VAT Net VAT Gross]]
    by_rate.each do |code, gross|
      rate = RATES.fetch(code)
      tax = (gross * rate / (100 + rate)).round(2)
      rows << ["#{code} #{rate}%", money(gross - tax), money(tax), money(gross)]
    end
    table(rows, width: :full, cell: { borders: [], padding: [1, 0], size: 7.5 }) do |t|
      t.columns(1..).align = :right
      t.row(0).weight = :bold
    end
  end

  def payment
    row do
      column { text "#{@payment[:method]}\n#{@payment[:reference]}", size: 8 }
      column { text "Paid #{money(total)}", size: 8, weight: :bold, align: :right }
    end
  end

  def online
    barcode "https://receipts.example/r/#{@number}", type: :qr, module_size: 2, align: :center
    spacer 3
    text "Your receipt online, and returns within 30 days", size: 7.5, align: :center
    spacer 6
    text "Thank you!", size: 11, weight: :bold, align: :center
  end

  # A dashed line across the paper with a pair of scissors at its start, drawn
  # on a canvas as tall as the scissors.
  def cut_line
    canvas(height: 12) do |c, rect|
      y = rect.y + 6
      c.line(rect.x + 16, y, rect.x + rect.width, y, color: "#000000", width: 0.75, dash: [3, 2])
      c.circle(rect.x + 3, y - 3, 2.2, stroke: "#000000", line_width: 0.8)
      c.circle(rect.x + 3, y + 3, 2.2, stroke: "#000000", line_width: 0.8)
      c.line(rect.x + 5, y - 2, rect.x + 13, y + 2.5, color: "#000000", width: 0.8)
      c.line(rect.x + 5, y + 2, rect.x + 13, y - 2.5, color: "#000000", width: 0.8)
    end
  end

  def coupon
    box(border: { width: 1 }, padding: [6, 8]) do
      text "10% OFF YOUR NEXT VISIT", size: 10, weight: :bold, align: :center
      spacer 2
      text "Code PANTRY10 · valid until 31 Oct 2026", size: 7.5, align: :center
    end
  end

  def dashes
    spacer 5
    rule height: 0.75
    spacer 5
  end

  def by_rate
    @items.group_by(&:last).sort.to_h { |code, items| [code, items.sum { |_, qty, price| qty * price }] }
  end

  def total = @items.sum { |_, qty, price| qty * price }.round(2)

  def vat_total
    by_rate.sum { |code, gross| (gross * RATES.fetch(code) / (100 + RATES.fetch(code))).round(2) }
  end

  def money(amount) = format("€%.2f", amount).tr(".", ",")
end

if $PROGRAM_NAME == __FILE__
  receipt = ExampleReceipt.preview
  receipt.to_pdf(File.expand_path("receipt.pdf", __dir__))
  warn receipt.warnings.map(&:message) if receipt.warnings.any?
  puts "wrote examples/receipt.pdf"
end
