# frozen_string_literal: true

require "pdf/inspector"
require "stationery/testing/inspector"

module PdfHelpers
  FONTS = File.expand_path("../fixtures/fonts", __dir__)
  IMAGES = File.expand_path("../fixtures/images", __dir__)

  def font_path(name) = File.join(FONTS, name)
  def image_path(name) = File.join(IMAGES, name)

  def inspect_pdf(pdf) = Stationery::Testing::Inspector.new(pdf)
  def text_of(pdf) = inspect_pdf(pdf).text

  def strings_of(pdf)
    PDF::Inspector::Text.analyze(pdf).strings
  end

  def positions_of(pdf)
    PDF::Inspector::Text.analyze(pdf).positions
  end

  def reader_for(pdf) = inspect_pdf(pdf).reader
  def page_count(pdf) = inspect_pdf(pdf).page_count
  def image_count(pdf) = inspect_pdf(pdf).image_count

  # Every /Rect a link annotation wrote, as [x1, y1, x2, y2] in page space.
  def link_rects(pdf)
    pdf.scan(%r{/Rect \[([-\d.\s]+)\]}).flatten.map { |rect| rect.split.map(&:to_f) }
  end

  # Decompressed content stream of every page, for operator-level assertions.
  def page_contents(pdf)
    reader_for(pdf).pages.map(&:raw_content)
  end
end

RSpec.configure { |config| config.include PdfHelpers }
