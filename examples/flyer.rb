# frozen_string_literal: true

# An A4 event flyer: a cover photo bled to the page edges, a date pill, a
# stats band, prose from HTML, a tilted photo collage, a price table,
# accommodation cards, a gallery grid, testimonials and a call to action with
# a link. Run it to write examples/flyer.pdf:
#
#   ruby -Ilib examples/flyer.rb
#   ruby -Ilib exe/stationery render examples/flyer.rb
require "stationery"

class ExampleFlyer < Stationery::Document
  ASSETS = File.expand_path("assets", __dir__)
  PAGE = "#FAF8F2"
  BAND = "#F1EEE7"
  HAIRLINE = "#E3DDD3"
  PRIMARY = "#345644"
  PRIMARY_CONTENT = "#F3FBF6"
  ACCENT = "#C1983A"
  INK = "#3A2A20"
  MUTED = "#74685F"
  FAINT = "#9A9189"
  TINT = "#E6E8E1"
  MARGIN = 48
  COVER_HEIGHT = 220
  OVERHANG = 24

  SVG_OPEN = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' \
             'stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">'
  ICONS = {
    calendar: '<path d="M4 6h16v14H4z M4 10h16 M8 3v4 M16 3v4"/>',
    pin: '<path d="M12 21s-6-5.5-6-11a6 6 0 0 1 12 0c0 5.5-6 11-6 11z"/><circle cx="12" cy="10" r="2.2"/>',
    users: '<circle cx="9" cy="8" r="3.2"/>' \
           '<path d="M3 20a6 6 0 0 1 12 0 M15.5 5.5a3 3 0 0 1 0 5.5 M17 13.5a6 6 0 0 1 4 6"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>',
    check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    quote: '<path d="M7 16c-1.5 0-3-1.5-3-3.5S5.5 8 8 7l1 1.5c-1.5.7-2 1.6-2 2.5 1.5 0 2.5 1 2.5 2.5S8.5 16 7 16z ' \
           'M16 16c-1.5 0-3-1.5-3-3.5S14.5 8 17 7l1 1.5c-1.5.7-2 1.6-2 2.5 1.5 0 2.5 1 2.5 2.5S17.5 16 16 16z"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 3v2 M12 19v2 M3 12h2 M19 12h2 M5.6 5.6l1.4 1.4 M17 17l1.4 1.4 ' \
         'M5.6 18.4L7 17 M17 7l1.4-1.4"/>'
  }.freeze

  LIFE = <<~HTML
    <p>We believe a good month feels natural rather than scheduled. Breakfast is long, the sea is a short walk
    away and the evenings belong to whoever brings a guitar. Food is not included: guests shop at the Tuesday
    market, cook for themselves or for everyone, and eat out in the harbour when the mood takes them.</p>
    <p>Most days follow a loose rhythm:</p>
    <ul>
      <li>Morning movement on the terrace before it gets warm</li>
      <li>Focused work or rest until the early afternoon</li>
      <li>Swims, hikes and boat trips when the light softens</li>
      <li>A shared table and a circle on two evenings a week</li>
    </ul>
    <p>Every session adapts to who turns up. Nothing is compulsory, and nobody keeps score.</p>
  HTML

  page size: :a4, margin: MARGIN
  default_text size: 10, color: INK, leading: 3
  metadata title: "Harbourside — a month on Ilha Serena", author: "stationery example", lang: "en"
  tagged

  # A cream page, painted under every page.
  page_template(layer: :background) do |page|
    canvas(at: [0, 0], width: page.width, height: page.height) do |c, rect|
      c.fill_rect(rect.x, rect.y, rect.width, rect.height, color: PAGE)
    end
  end

  footer(gap: 12) do |page|
    text "Harbourside  ·  harbourside.example  ·  Page #{page.number} of #{page.count}",
         size: 7, color: FAINT, align: :center
  end

  def self.preview = new

  def view_template
    hero
    stats
    section("Life at Harbourside", band: true)
    html LIFE, styles: { p: { color: MUTED }, ul: { gap: 3, marker_color: ACCENT, indent: 14 } }
    spacer 10
    collage
    section("What's included")
    included
    section("Prices", band: true)
    prices
    section("Where you sleep")
    accommodation
    section("Impressions", band: true)
    gallery
    section("What guests say")
    testimonials
    call_to_action
  end

  private

  # ---- hero ----------------------------------------------------------------

  # The cover photo covers the page's full width and bleeds off the top; the
  # positioned box takes no flow height, so a spacer reserves the space.
  def hero
    box(at: [0, 0], width: page_width) do
      image photo("sea"), width: page_width, height: COVER_HEIGHT, fit: :cover, alt: "The harbour at first light"
    end
    spacer COVER_HEIGHT - MARGIN + 18
    date_pill
    spacer 14
    text "Harbourside", size: 30, weight: :bold, color: PRIMARY, align: :center, heading: 1
    spacer 4
    text "A month of community living on Ilha Serena", size: 12, color: MUTED, align: :center
    spacer 14
    meta_row
  end

  def date_pill
    group(align: :center) do
      box(width: :auto, background: PRIMARY, radius: 10, padding: [4, 12]) do
        row(gap: 5, align: :middle) do
          column(width: :auto) { icon(:calendar, size: 10, color: PRIMARY_CONTENT) }
          column(width: :auto) { text "3 – 31 May 2027", size: 9, color: PRIMARY_CONTENT }
        end
      end
    end
  end

  def meta_row
    row do
      [[:pin, "Porto Velho, Ilha Serena"], [:users, "12 – 20 guests"], [:clock, "7 to 28 nights"]].each do |name, label|
        column do
          row(gap: 5, align: :middle) do
            column(width: 14, padding: [0, 0, 0, 4]) { icon(name, size: 10) }
            column { text label, size: 9, color: MUTED }
          end
        end
      end
    end
  end

  # ---- stats band ----------------------------------------------------------

  def stats
    spacer 22
    box(background: BAND, radius: 12, padding: [14, 10]) do
      row do
        [[:clock, "Duration", "7 – 28 nights"], [:sun, "Investment", "from € 690"],
         [:users, "Group size", "12 – 20 guests"]].each do |name, label, value|
          column(align: :center) { stat(name, label, value) }
        end
      end
    end
  end

  def stat(name, label, value)
    icon_disc(name)
    spacer 6
    text label, size: 8, color: FAINT, align: :center
    spacer 2
    text value, size: 11, weight: :bold, color: PRIMARY, align: :center
  end

  def icon_disc(name, diameter: 26)
    group(align: :center) do
      box(width: diameter, height: diameter, radius: diameter / 2.0, background: TINT, valign: :middle) do
        icon(name, size: 13, align: :center)
      end
    end
  end

  # ---- sections ------------------------------------------------------------

  # A section heading, on a full-bleed tinted strip for every other section,
  # bookmarked in the outline and kept with the start of its section.
  def section(title, band: false)
    spacer 18
    group(keep_with_next: 120, bookmark: title) do
      if band
        box(background: BAND, outset: [0, MARGIN, 0, MARGIN], padding: [12, 0]) { heading(title) }
      else
        heading(title)
      end
      spacer 10
    end
  end

  def heading(title) = text(title, size: 19, weight: :bold, color: PRIMARY, align: :center, heading: 2)

  def collage
    group(align: :center) do
      box(padding: OVERHANG, width: :auto) do
        stack do
          box(width: :auto, radius: 16, shadow: true) do
            image photo("hills"), width: 300, height: 225, fit: :cover, radius: 16, alt: "Hills above the harbour"
          end
          layer(bottom: -OVERHANG, left: -OVERHANG, width: 0.4, rotate: -3, **frame) do
            image photo("stone"), width: 112, height: 84, fit: :cover, radius: 8, alt: "The old stone quay"
          end
          layer(top: -OVERHANG, right: -OVERHANG, width: 1/3r, rotate: 2, **frame) do
            image photo("bay"), width: 92, height: 92, fit: :cover, radius: 8, alt: "The bay from the terrace"
          end
        end
      end
    end
  end

  def frame = { padding: 4, background: "#FFFFFF", radius: 12, shadow: true }

  def included
    items = ["Your room for the whole stay", "Morning movement, six days a week",
             "Two evening circles every week", "A boat day and two guided hikes",
             "A shared kitchen and the Tuesday market run", "Fast Wi-Fi and a quiet room to work in"]
    items.each_slice(2) do |pair|
      row(gap: 14) do
        pair.each do |item|
          column(width: 0.5) do
            row(gap: 6) do
              column(width: 10, padding: [3, 0, 0, 0]) { icon(:check, size: 9, color: ACCENT) }
              column { text item, size: 10, leading: 2 }
            end
          end
        end
      end
      spacer 7
    end
  end

  def prices
    text "Prices are per person and include everything listed above. Children under twelve stay free in " \
         "their parents' room.", color: MUTED, align: :center
    spacer 10
    rows = [["Stay", "Regular", "Early bird\n<font size='7'>until 31 January</font>", "Returning guests"],
            ["7 nights", "€ 690", "€ 620", "€ 590"], ["14 nights", "€ 1,290", "€ 1,160", "€ 1,090"],
            ["21 nights", "€ 1,790", "€ 1,610", "€ 1,520"], ["28 nights", "€ 2,190", "€ 1,970", "€ 1,860"]]
    table(rows, width: :full, header: true,
                cell: { markup: true, size: 9.5, borders: [:bottom], border_color: HAIRLINE, padding: [6, 8] }) do |t|
      t.row(0).set(background: PRIMARY, color: PRIMARY_CONTENT, weight: :bold)
      t.columns(1..).align = :right
      t.zebra(from: 2, color: BAND)
    end
    spacer 8
    text "Returning guests are anyone who has stayed with us before, in any house.", size: 8.5, color: FAINT,
                                                                                     align: :center
  end

  def accommodation
    [["The Harbour House", "6 rooms · sleeps 10", "ridge",
      "The old harbourmaster's house: a big kitchen, a walled garden and rooms that look over the boats."],
     ["The Terrace Apartments", "2 apartments · sleeps 6", "wall",
      "Two quiet apartments above the square, each with its own kitchen and a terrace that catches the " \
      "afternoon sun."]].each do |name, capacity, picture, blurb|
      group(keep_together: true) do
        row(gap: 14, align: :middle) do
          column(width: 150) { image photo(picture), width: 150, height: 96, fit: :cover, radius: 10, alt: name }
          column do
            text name, size: 13, weight: :bold, color: PRIMARY, heading: 3
            text capacity, size: 9, color: ACCENT
            spacer 4
            text blurb, color: MUTED
          end
        end
      end
      spacer 14
    end
  end

  def gallery
    %w[sea hills stone bay ridge dunes].each_slice(3) do |names|
      row(gap: 8) do
        names.each do |name|
          column(width: 1 / 3.0) do
            image photo(name), width: 161, height: 96, fit: :cover, radius: 8, alt: "Impression"
          end
        end
      end
      spacer 8
    end
  end

  def testimonials
    [["Three weeks in, I stopped checking the time. That has never happened to me on a holiday.", "Mara, Vienna"],
     ["Came for the sea, stayed for the Tuesday market and the people around the table.", "Jonas, Malmö"]]
      .each do |quote, author|
      group(keep_together: true) do
        box(role: :blockquote, background: BAND, radius: 12, padding: [14, 18]) do
          icon(:quote, size: 14, color: ACCENT, align: :center)
          spacer 6
          text %("#{quote}"), style: :italic, color: MUTED, align: :center
          spacer 4
          text author, size: 9, color: PRIMARY, align: :center
        end
      end
      spacer 10
    end
  end

  # A pill the whole shape of which is clickable, and the address spelled out
  # for the printed copy.
  def call_to_action
    url = "https://harbourside.example/apply"
    spacer 22
    group(keep_together: true) do
      box(background: BAND, outset: [0, MARGIN, 0, MARGIN], padding: [16, 0]) do
        text "Ready to come?", size: 19, weight: :bold, color: PRIMARY, align: :center, heading: 2
        spacer 6
        text "Applications open until the house is full. We read every one and reply within a week.",
             color: MUTED, align: :center
        spacer 12
        group(align: :center) do
          box(width: :auto, height: 26, background: PRIMARY, radius: 13, padding: [0, 28], valign: :middle,
              link: url) do
            text "Apply for a call", size: 11, color: PRIMARY_CONTENT, align: :center
          end
        end
        spacer 8
        text(size: 9, align: :center) { |t| t.link(url) { t.color(MUTED, "or write to hello@harbourside.example") } }
      end
    end
  end

  # ---- helpers -------------------------------------------------------------

  def page_width = Stationery::Page.new(size: :a4).width
  def photo(name) = File.join(ASSETS, "#{name}.png")

  # Decorative line icons; the label beside each one carries the meaning.
  def icon(name, size: 12, color: PRIMARY, align: nil)
    svg "#{SVG_OPEN}#{ICONS.fetch(name)}</svg>", width: size, height: size, color:, align:, alt: false
  end
end

if $PROGRAM_NAME == __FILE__
  flyer = ExampleFlyer.preview
  flyer.to_pdf(File.expand_path("flyer.pdf", __dir__))
  warn flyer.warnings.map(&:message) if flyer.warnings.any?
  puts "wrote examples/flyer.pdf"
end
