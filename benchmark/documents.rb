# frozen_string_literal: true

# The Stationery documents the benchmarks and the metrics gate render. They
# need nothing but the gem, so the gate runs without Prawn.
require "stationery"

module Bench
  FONTS = File.expand_path("../spec/fixtures/fonts", __dir__)
  FONT = File.join(FONTS, "OpenSans-Regular.ttf")
  FONT_BOLD = File.join(FONTS, "OpenSans-Bold.ttf")

  TABLE_HEADER = %w[ID Customer City Quantity Amount].freeze
  TABLE_ROWS = Array.new(1_500) do |i|
    [(i + 1).to_s, "Customer #{i % 97}", %w[Stockholm Berlin Oslo Paris Madrid][i % 5],
     ((i * 7) % 40).to_s, format("%.2f", (i * 13.37) % 5000)]
  end.freeze
  TABLE = [TABLE_HEADER, *TABLE_ROWS].freeze

  ASSETS = File.expand_path("../examples/assets", __dir__)
  COVER = File.join(ASSETS, "dunes.png")
  PHOTOS = %w[sea hills stone].map { |name| File.join(ASSETS, "#{name}.png") }.freeze

  PARAGRAPH = "We believe a good month feels natural rather than scheduled. Breakfast is long, the sea is a " \
              "short walk away and the evenings belong to whoever brings a guitar. Guests shop at the market, " \
              "cook for themselves or for everyone, and eat out in the harbour when the mood takes them."

  # A 1,500-row table with a repeating header row, 46 A4 pages.
  class StationeryTable < Stationery::Document
    page size: :a4, margin: 36
    font_family "Open Sans", regular: FONT, bold: FONT_BOLD
    default_text font: "Open Sans", size: 9

    def view_template
      table(TABLE, header: true, width: :full) { |t| t.row(0).weight = :bold }
    end
  end

  # Headings and paragraphs, ten A4 pages.
  class StationeryText < Stationery::Document
    page size: :a4, margin: 48
    font_family "Open Sans", regular: FONT, bold: FONT_BOLD
    default_text font: "Open Sans", size: 9.5

    def view_template
      50.times do |section|
        text "Section #{section + 1}", size: 16, weight: :bold
        3.times { text PARAGRAPH }
      end
    end
  end

  # The same text justified, with words hyphenated where a line breaks.
  class StationeryHyphenated < StationeryText
    default_text font: "Open Sans", size: 9.5, hyphenate: true, align: :justify
  end

  # A cover photo, then six sections of a heading, three paragraphs and a row
  # of three photos: what a brochure or a flyer does with images.
  class StationeryPhotos < Stationery::Document
    page size: :a4, margin: 48
    font_family "Open Sans", regular: FONT, bold: FONT_BOLD
    default_text font: "Open Sans", size: 9.5

    def view_template
      image COVER, width: 499, height: 200, fit: :cover
      6.times do
        text "Healthy Living", size: 16, weight: :bold
        3.times { text PARAGRAPH }
        row(gap: 8) do
          PHOTOS.each { |photo| column(width: 1 / 3.0) { image photo, width: 161, height: 90, fit: :cover } }
        end
        spacer 10
      end
    end
  end
end
