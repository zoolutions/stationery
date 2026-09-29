# frozen_string_literal: true

require "stationery"

class CliEncryptedTaggedDocument < Stationery::Document
  page size: [200, 120], margin: 10
  font_family "Open Sans", regular: File.expand_path("../fonts/OpenSans-Regular.ttf", __dir__)
  default_text font: "Open Sans", size: 10
  metadata title: "Tagged", lang: "en"
  tagged
  encrypt owner_password: "o"

  def view_template
    text "one"
    page_break
    text "two"
  end
end
