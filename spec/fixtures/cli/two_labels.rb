# frozen_string_literal: true

require "stationery"

class CliTwoLabelsDocument < Stationery::Document
  page size: [200, 120], margin: 10
  max_pages 1
  font_family "Open Sans", regular: File.expand_path("../fonts/OpenSans-Regular.ttf", __dir__)
  default_text font: "Open Sans", size: 10

  def view_template
    text "one"
    page_break
    text "two"
  end
end
