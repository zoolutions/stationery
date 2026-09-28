# frozen_string_literal: true

# The HTML and CSS twins of the benchmark documents, rendered by sghtmltopdf
# (an HTML-to-PDF engine in Rust) as the third `rake bench` lane. It is given
# the same Open Sans files and `dpi: 72`, so a CSS pixel is a point and the
# pages match. The lane is optional: without the gem `Bench::Sg.available?`
# is false and the benches print two engines.
require_relative "documents"

module Bench
  module Sg
    # False without the gem, or with SGHTMLTOPDF=0 in the environment (to see
    # the two-engine output on a machine that has it).
    AVAILABLE = ENV["SGHTMLTOPDF"] != "0" && begin
      require "sghtmltopdf"
      true
    rescue LoadError
      false
    end

    module_function

    def available? = AVAILABLE

    def version = available? ? Sghtmltopdf::VERSION : nil

    OPTIONS = { page_size: "A4", dpi: 72, disable_system_fonts: true, font: [Bench::FONT, Bench::FONT_BOLD],
                allow_path: [Bench::FONTS, Bench::ASSETS] }.freeze

    def render(html) = Sghtmltopdf.render(html, **OPTIONS)
  end

  module HTML
    FONT_FACE = <<~CSS.freeze
      @font-face { font-family: "Open Sans"; src: url("#{Bench::FONT}"); font-weight: 400; }
      @font-face { font-family: "Open Sans"; src: url("#{Bench::FONT_BOLD}"); font-weight: 700; }
    CSS
    INVOICE_CSS = <<~CSS.freeze
      #{FONT_FACE}
      @page { size: A4; margin: 40pt 44pt 56pt 44pt; @bottom-right { content: "Page " counter(page) " of " counter(pages); font-size: 7px; color: #6B7280; } }
      body { font-family: "Open Sans"; font-size: 9px; color: #1F2937; margin: 0; }
      .head { display: flex; align-items: center; justify-content: space-between; }
      h1 { font-size: 22px; margin: 0; }
      .rule { height: 3px; background: #4F46E5; margin: 10px 0 18px; }
      .summary { display: flex; gap: 24px; margin-bottom: 22px; }
      .summary .meta { flex: 1; }
      .due { width: 166px; background: #F3F4F6; border-radius: 6px; padding: 12px; }
      .due .label { font-size: 8px; font-weight: 700; color: #6B7280; letter-spacing: .5px; }
      .due .amount { font-size: 19px; font-weight: 700; color: #4F46E5; }
      .pill { display: inline-block; background: #3B82F6; color: #fff; font-size: 7px; font-weight: 700; border-radius: 7px; padding: 2px 9px; margin-top: 6px; }
      .parties { display: flex; gap: 24px; margin-bottom: 26px; }
      .parties > div { flex: 1; }
      .parties .label { font-size: 8px; font-weight: 700; color: #6B7280; letter-spacing: .5px; margin-bottom: 3px; }
      table.items { width: 100%; border-collapse: collapse; }
      table.items th { background: #4F46E5; color: #fff; font-weight: 700; text-align: left; padding: 7px 8px; }
      table.items td { padding: 7px 8px; }
      table.items tr:nth-child(even) td { background: #F9FAFB; }
      .r { text-align: right; }
      .total td { font-weight: 700; font-size: 11px; }
      .foot { border-top: 1px solid #E5E7EB; margin-top: 28px; padding-top: 14px; break-inside: avoid; }
      .muted { color: #6B7280; }
      a { color: #4F46E5; text-decoration: none; }
    CSS
    LOGO = File.join(Bench::ASSETS, "logo.png")

    module_function

    def money(amount)
      whole, cents = format("%.2f", amount).split(".")
      "€#{whole.reverse.scan(/\d{1,3}/).join(" ").reverse},#{cents}"
    end

    def table
      rows = Bench::TABLE_ROWS.map { |row| "<tr>#{row.map { |cell| "<td>#{cell}</td>" }.join}</tr>" }.join
      header = Bench::TABLE_HEADER.map { |cell| "<th>#{cell}</th>" }.join
      <<~HTML
        <!doctype html><html><head><meta charset="utf-8"><style>
        #{FONT_FACE}
        @page { size: A4; margin: 36pt; }
        body { font-family: "Open Sans"; font-size: 9px; margin: 0; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #000; padding: 7.4px 5px; text-align: left; }
        th { font-weight: 700; }
        </style></head><body>
        <table><thead><tr>#{header}</tr></thead><tbody>#{rows}</tbody></table>
        </body></html>
      HTML
    end

    def invoice
      subtotal = Bench::INVOICE_ITEMS.sum { |_, qty, price| qty * price }
      vat = (subtotal * 0.25).round(2)
      lines = Bench::INVOICE_ITEMS.map do |name, qty, price|
        "<tr><td>#{name}</td><td class=r>#{qty}</td><td class=r>#{money(price)}</td><td class=r>25%</td>" \
          "<td class=r>#{money(qty * price)}</td></tr>"
      end.join
      <<~HTML
        <!doctype html><html><head><meta charset="utf-8"><title>Invoice</title><style>#{INVOICE_CSS}        </style></head><body>
        <div class="head"><h1>Invoice INV-2026-042</h1><img src="#{LOGO}" height="34"></div>
        <div class="rule"></div>
        <div class="summary">
          <table class="meta"><tr><td><b>Invoice date</b></td><td class=muted>26 September 2026</td></tr>
          <tr><td><b>Due date</b></td><td class=muted>26 October 2026</td></tr>
          <tr><td><b>Reference</b></td><td class=muted>PO-7781</td></tr></table>
          <div class="due"><div class="label">AMOUNT DUE</div><div class="amount">#{money(subtotal + vat)}</div><span class="pill">OPEN</span></div>
        </div>
        <div class="parties">
          <div><div class="label">FROM</div><b>Acme Studio AB</b><br>Storgatan 1<br>111 22 Stockholm<br>hello@acme.test</div>
          <div><div class="label">BILL TO</div><b>Müller &amp; Söhne GmbH</b><br>Hauptstraße 5<br>10115 Berlin</div>
        </div>
        <table class="items"><thead><tr><th>Description</th><th class=r>Qty</th><th class=r>Price</th><th class=r>VAT</th><th class=r>Amount</th></tr></thead>
        <tbody>#{lines}
        <tr><td></td><td></td><td></td><td class=r>Subtotal</td><td class=r>#{money(subtotal)}</td></tr>
        <tr><td></td><td></td><td></td><td class=r>VAT 25%</td><td class=r>#{money(vat)}</td></tr>
        <tr class="total"><td></td><td></td><td></td><td class=r>Total</td><td class=r>#{money(subtotal + vat)}</td></tr>
        </tbody></table>
        <div class="foot"><b>Thank you for your business</b><p class="muted">Pay to IBAN SE45 5000 0000 0583 9825 7466 within 30 days. Questions? <a href="mailto:hello@acme.test">hello@acme.test</a></p></div>
        </body></html>
      HTML
    end

    def photos
      section = <<~HTML
        <h2>Healthy Living</h2>#{"<p>#{Bench::PARAGRAPH}</p>" * 3}
        <div class="grid">#{Bench::PHOTOS.map { |photo| %(<img src="#{photo}">) }.join}</div>
      HTML
      <<~HTML
        <!doctype html><html><head><meta charset="utf-8"><style>
        #{FONT_FACE}
        @page { size: A4; margin: 48pt; }
        body { font-family: "Open Sans"; font-size: 9.5px; margin: 0; }
        h2 { font-size: 16px; margin: 0; }
        p { margin: 0; line-height: 1.55; }
        .cover { width: 499px; height: 200px; object-fit: cover; display: block; }
        .grid { display: flex; gap: 8px; margin-bottom: 10px; }
        .grid img { width: 161px; height: 90px; object-fit: cover; }
        </style></head><body>
        <img class="cover" src="#{Bench::COVER}">
        #{section * 6}
        </body></html>
      HTML
    end
  end
end
