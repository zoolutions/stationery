# frozen_string_literal: true

# A wholesale price list of 2,000 articles over forty-odd pages: one long
# table read from an Enumerator of records, its header row repeated on every
# page, written incrementally so each page lets go of its content once it is
# painted. Run it to write examples/price_list.pdf:
#
#   ruby -Ilib examples/price_list.rb
#   ruby -Ilib exe/stationery render examples/price_list.rb
require "stationery"

class ExamplePriceList < Stationery::Document
  ACCENT = "#B45309"
  INK = "#1C1917"
  MUTED = "#78716C"
  ZEBRA = "#FAF7F2"

  Article = Data.define(:number, :name, :unit, :pack, :price)

  RANGES = { "Coffee" => %w[Arabica Robusta Espresso Decaf Blend], "Tea" => %w[Assam Darjeeling Sencha Rooibos Chai],
             "Cocoa" => %w[Dark Milk White Spiced Raw] }.freeze
  FORMS = [["whole beans", "kg", 6], ["ground", "kg", 6], ["capsules", "box of 50", 12], ["loose leaf", "kg", 4],
           ["bags", "box of 100", 10], ["powder", "kg", 8]].freeze

  page size: :a4, margin: [40, 40, 36, 40]
  default_text size: 8.5, color: INK
  metadata title: "Price list 2027", author: "Example Provisions AB", creator: "stationery example"

  # Headers and footers are painted once the page count is known: with
  # `incremental` the body of each page is written as soon as it is painted
  # instead of being held until then.
  incremental

  header(gap: 12) do |page|
    row(align: :bottom) do
      text "Example Provisions · Price list 2027", size: 11, weight: :bold, color: ACCENT
      text "Prices in SEK excluding VAT", size: 7.5, color: MUTED, align: :right
    end
    spacer 4
    rule height: 1, color: ACCENT
  end

  footer { |page| text "Page #{page.number} of #{page.count}", size: 7.5, color: MUTED, align: :center }

  # 2,000 articles, the same every time: a seeded Random, so the list (and
  # the file) does not change between renders.
  def self.preview = new(articles(2_000))

  def self.articles(count)
    Enumerator.new do |yielder|
      random = Random.new(2027)
      count.times do |i|
        range, kinds = RANGES.to_a[i % RANGES.size]
        form, unit, pack = FORMS[random.rand(FORMS.size)]
        name = "#{kinds[random.rand(kinds.size)]} #{range.downcase}, #{form}"
        yielder << Article.new(format("EP-%05d", 10_000 + (i * 7)), name, unit, pack, random.rand(40.0..900.0).round(2))
      end
    end
  end

  def initialize(articles)
    super()
    @articles = articles
  end

  def view_template
    text "Price list 2027", size: 24, weight: :bold
    text "Valid from 1 January 2027 until further notice. Orders of 20 packs or more are delivered free.",
         color: MUTED
    spacer 14
    price_table
  end

  private

  # `table` takes any Enumerable of rows and reads it once, as the table is
  # built; the header row is the first and repeats after every page break.
  def price_table
    rows = Enumerator.new do |yielder|
      yielder << ["Article", "Description", "Unit", "Pack", "Per unit", "Per pack"]
      @articles.each do |article|
        yielder << [article.number, article.name, article.unit, article.pack.to_s, money(article.price),
                    money(article.price * article.pack)]
      end
    end
    table(rows, header: true, width: :full, widths: [62, nil, 62, 36, 66, 72],
                cell: { padding: [2.5, 6], borders: [] }) do |t|
      t.row(0).set(background: ACCENT, color: "#FFFFFF", weight: :bold)
      t.columns(3..).align = :right
      t.columns(0).rows(1..).color = MUTED
      t.zebra(from: 1, color: ZEBRA)
    end
  end

  def money(amount)
    whole, cents = format("%.2f", amount).split(".")
    "#{whole.reverse.scan(/\d{1,3}/).join(" ").reverse},#{cents}"
  end
end

if $PROGRAM_NAME == __FILE__
  list = ExamplePriceList.preview
  list.to_pdf(File.expand_path("price_list.pdf", __dir__))
  warn list.warnings.map(&:message) if list.warnings.any?
  puts "wrote examples/price_list.pdf"
end
