# frozen_string_literal: true

require "stationery"

class CliNeedsArgsDocument < Stationery::Document
  font_family "Open Sans", regular: File.expand_path("../fonts/OpenSans-Regular.ttf", __dir__)
  default_text font: "Open Sans", size: 10

  def initialize(thing)
    super()
    @thing = thing
  end

  def view_template = text(@thing)
end
