# frozen_string_literal: true

# A document base class wired to the spec fixture fonts.
class SpecDocument < Stationery::Document
  FONTS = File.expand_path("../fixtures/fonts", __dir__)

  page size: [300, 200], margin: 20
  font_family "Open Sans",
              regular: File.join(FONTS, "OpenSans-Regular.ttf"), bold: File.join(FONTS, "OpenSans-Bold.ttf"),
              italic: File.join(FONTS, "OpenSans-Italic.ttf"), bold_italic: File.join(FONTS, "OpenSans-BoldItalic.ttf")
  default_text font: "Open Sans", size: 10

  def self.build(&)
    Class.new(self) { define_method(:view_template, &) }.new
  end
end
