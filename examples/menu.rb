# frozen_string_literal: true

# A restaurant menu on one page: an introduction wrapped around a floated
# photo, the dishes poured through two balanced columns, a floated box for
# the dish of the day, and headings set in the heavier weights of Inter. Run
# it to write examples/menu.pdf:
#
#   ruby -Ilib examples/menu.rb
#   ruby -Ilib exe/stationery render examples/menu.rb
#
# The type is the bundled Inter. For a font pack, install it
# (`stationery fonts install noto_serif`) and name it:
# `font_family "Noto Serif"`, then `default_text font: "Noto Serif"`.
require "stationery"

class ExampleMenu < Stationery::Document
  PHOTO = File.expand_path("assets/bay.png", __dir__)
  INK = "#1C1917"
  MUTED = "#78716C"
  ACCENT = "#9A3412"
  CREAM = "#FFF7ED"
  LINE = "#E7E5E4"

  COURSES = {
    "Starters" => [
      ["Smoked mackerel", "Rye crisp, pickled cucumber, horseradish cream", 145],
      ["Beetroot tartare", "Goat's cheese, walnuts, dill oil", 135],
      ["Fish soup", "Saffron broth, mussels, aioli, toasted sourdough", 165],
      ["Chanterelles on toast", "Brown butter, thyme, aged cheese", 155]
    ],
    "Mains" => [
      ["Pan-fried cod", "Brown butter, capers, new potatoes, peas", 295],
      ["Slow-cooked lamb", "Root vegetables, rosemary jus, crispy kale", 325],
      ["Barley risotto", "Mushrooms, parsley, pecorino, lemon", 245],
      ["Char with sorrel sauce", "Fennel, dill potatoes, roe", 310],
      ["Harbour burger", "Aged beef, cheddar, onions, fries", 225]
    ],
    "Desserts" => [
      ["Cloudberry parfait", "Almond crumble, warm cloudberries", 125],
      ["Chocolate cake", "Sea salt, crème fraîche", 115],
      ["Cheese from the island", "Three cheeses, crispbread, quince", 145]
    ],
    "To drink" => [
      ["House lemonade", "Elderflower or rhubarb", 55],
      ["Local cider", "Dry, 33 cl", 85],
      ["Coffee or tea", "Refills are free", 40]
    ],
    "Wine by the glass" => [
      ["Grüner Veltliner", "Crisp and peppery, with the fish", 125],
      ["Pinot noir", "Light and red-fruited, with the lamb", 135],
      ["Sparkling cider", "Méthode traditionnelle, from the island", 110]
    ]
  }.freeze

  page size: :a4, margin: [56, 56, 48, 56]
  default_text size: 9.5, color: INK, leading: 2
  metadata title: "Menu · The Harbour Kitchen", author: "The Harbour Kitchen", creator: "stationery example"

  def self.preview = new(special: ["Grilled herring", "Mustard sauce, mashed potatoes, lingonberries", 185])

  def initialize(special:)
    super()
    @special = special
  end

  def view_template
    masthead
    introduction
    spacer 16
    # One flow of courses poured through two columns: column one top to
    # bottom, then column two, ending level where the dishes run out.
    columns(count: 2, gap: 28, rule: { color: LINE }) do
      COURSES.each { |course, dishes| course(course, dishes) }
    end
    spacer 14
    rule color: LINE
    spacer 6
    text "Tell us about allergies before you order. All prices in SEK, service included.",
         size: 8, color: MUTED, align: :center
  end

  private

  def masthead
    text "THE HARBOUR KITCHEN", size: 10, weight: :bold, color: ACCENT, letter_spacing: 3, align: :center
    spacer 4
    text "Autumn menu", size: 34, weight: :bold, align: :center
    spacer 14
  end

  # The photo floats left and the text wraps beside it; the dish of the day
  # floats right, between them, in a box of its own.
  def introduction
    image PHOTO, float: :left, width: 0.34, height: 104, fit: :cover, radius: 6, margin: 14
    box(float: :right, width: 150, margin: { left: 14, bottom: 6 }, background: CREAM, radius: 6, padding: 10) do
      text "DISH OF THE DAY", size: 7, weight: :bold, color: ACCENT, letter_spacing: 1
      spacer 3
      name, description, price = @special
      text name, size: 11, weight: :bold
      text description, size: 8.5, color: MUTED
      spacer 3
      text price.to_s, weight: :bold, color: ACCENT
    end
    text "Everything on this menu comes from within a day's drive of the harbour: the fish from the boats " \
         "you can see from your table, the vegetables from two farms on the island and the cheese from the " \
         "dairy up the hill. The menu changes with the catch and the season, so some dishes may run out " \
         "before the evening does.", align: :justify, hyphenate: true, size: 10.5, leading: 3
  end

  # A course is kept together, so a column never starts in the middle of one.
  def course(title, dishes)
    group(keep_together: true) do
      text title, size: 18, weight: :bold, color: ACCENT
      spacer 8
      dishes.each do |name, description, price|
        row(gap: 8) do
          column { text name, size: 10.5, weight: :bold }
          column(width: :auto) { text price.to_s, size: 10.5, weight: :bold }
        end
        text description, size: 9, color: MUTED, style: :italic
        spacer 10
      end
      spacer 14
    end
  end
end

if $PROGRAM_NAME == __FILE__
  menu = ExampleMenu.preview
  menu.to_pdf(File.expand_path("menu.pdf", __dir__))
  warn menu.warnings.map(&:message) if menu.warnings.any?
  puts "wrote examples/menu.pdf"
end
