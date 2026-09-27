# frozen_string_literal: true

require "stationery"

class CliOverflowDocument < Stationery::Document
  page size: [200, 120], margin: 10
  font_family "Open Sans", regular: File.expand_path("../fonts/OpenSans-Regular.ttf", __dir__)
  default_text font: "Open Sans", size: 10

  def view_template = box(break_inside: :avoid) { 40.times { text "x" } }
end
