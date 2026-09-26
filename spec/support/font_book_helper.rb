# frozen_string_literal: true

module FontBookHelper
  def open_sans_book
    Stationery::Fonts::FontBook.new.tap do |book|
      book.register(
        "Open Sans",
        regular: font_path("OpenSans-Regular.ttf"), bold: font_path("OpenSans-Bold.ttf"),
        italic: font_path("OpenSans-Italic.ttf"), bold_italic: font_path("OpenSans-BoldItalic.ttf")
      )
    end
  end

  def base_style(**overrides)
    Stationery::Text::Style.new(family: "Open Sans", size: 10, **overrides)
  end
end

RSpec.configure { |config| config.include FontBookHelper }
