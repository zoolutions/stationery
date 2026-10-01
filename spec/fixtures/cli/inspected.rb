# frozen_string_literal: true

require "stationery"

class CliInspectedDocument < Stationery::Document
  page size: [200, 160], margin: 10
  font_family "Open Sans", regular: File.expand_path("../fonts/OpenSans-Regular.ttf", __dir__)
  default_text font: "Open Sans", size: 10
  metadata title: "Inspected", lang: "en"
  print copies: 2

  def view_template
    text "Hello", bookmark: "Start"
    image File.expand_path("../images/rgb.jpg", __dir__), width: 20
    text "Visit", link: "https://example.com"
    text_field "name", value: "Astrid", width: 80
    text_field "price", value: "9 kr", width: 80, align: :center, font_size: :auto, color: "#DC2626"
    page_break
    text "The end", bookmark: "End"
  end
end
