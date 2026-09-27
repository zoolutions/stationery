# frozen_string_literal: true

require "stationery"

# Stands in for a Document#to_pdf without `debug:`.
class CliNoDebugDocument < Stationery::Document
  page size: [200, 120], margin: 10
  font_family "Open Sans", regular: File.expand_path("../fonts/OpenSans-Regular.ttf", __dir__)
  default_text font: "Open Sans", size: 10

  def to_pdf(target = nil) = super

  def view_template = text("plain")
end
