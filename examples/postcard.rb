# frozen_string_literal: true

# An A5 landscape postcard: a photo collage of one large picture with two
# tilted, white-framed snapshots overlapping its corners, beside a greeting.
# Run it to write examples/postcard.pdf:
#
#   ruby -Ilib examples/postcard.rb
#   ruby -Ilib exe/stationery render examples/postcard.rb
require "stationery"

class ExamplePostcard < Stationery::Document
  ASSETS = File.expand_path("assets", __dir__)
  PAPER = "#FFFBEB"
  INK = "#1F2937"
  MUTED = "#6B7280"
  ACCENT = "#B45309"
  OVERHANG = 18

  page size: :a5, layout: :landscape, margin: 36
  default_text size: 10.5, color: INK
  metadata title: "Greetings from Sardinia", author: "stationery example", lang: "en"
  tagged

  # Cream card stock: a background layer painted under every page.
  page_template(layer: :background) do |page|
    canvas(at: [0, 0], width: page.width, height: page.height) do |c, rect|
      c.fill_rect(rect.x, rect.y, rect.width, rect.height, color: PAPER)
    end
  end

  def self.preview = new

  def view_template
    spacer 30
    row(gap: 20, align: :middle) do
      column(width: 0.55) { collage }
      column { greeting }
    end
  end

  private

  # The site-style collage: a base photo with rounded corners and a shadow, a
  # 4:3 snapshot hanging off the bottom-left corner and a square one off the
  # top-right, each tilted in its white frame. The stack's layers overhang by
  # OVERHANG points, so the box around it keeps them on the page.
  def collage
    box(padding: OVERHANG) do
      stack do
        box(width: :auto, radius: 16, shadow: true) do
          image photo("sea"), width: 228, height: 171, fit: :cover, radius: 16, alt: "The bay at dawn"
        end
        layer(bottom: -OVERHANG, left: -OVERHANG, width: 0.4, rotate: -3, **frame) do
          image photo("hills"), width: 83, height: 62, fit: :cover, radius: 8, alt: "Hills above the village"
        end
        layer(top: -OVERHANG, right: -OVERHANG, width: 1/3r, rotate: 2, **frame) do
          image photo("stone"), width: 68, height: 68, fit: :cover, radius: 8, alt: "A sandstone wall"
        end
      end
    end
  end

  def frame = { padding: 4, background: "#FFFFFF", radius: 12, shadow: true }
  def photo(name) = File.join(ASSETS, "#{name}.png")

  def greeting
    text "Greetings from Sardinia", size: 22, weight: :bold, color: ACCENT, heading: 1
    spacer 6
    text "October 2026", size: 9, color: MUTED
    spacer 14
    text "The sea is still warm enough to swim before breakfast, the hills smell of myrtle and the village " \
         "square fills up every evening. Wish you were here.", leading: 3
    spacer 14
    text "With love, the whole crew", style: :italic, color: MUTED
  end
end

if $PROGRAM_NAME == __FILE__
  postcard = ExamplePostcard.preview
  postcard.to_pdf(File.expand_path("postcard.pdf", __dir__))
  warn postcard.warnings.map(&:message) if postcard.warnings.any?
  puts "wrote examples/postcard.pdf"
end
