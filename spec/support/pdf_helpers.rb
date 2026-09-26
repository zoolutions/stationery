# frozen_string_literal: true

require "stringio"
require "pdf/inspector"
require "pdf/reader"

module PdfHelpers
  FONTS = File.expand_path("../fixtures/fonts", __dir__)
  IMAGES = File.expand_path("../fixtures/images", __dir__)

  def font_path(name) = File.join(FONTS, name)
  def image_path(name) = File.join(IMAGES, name)

  def text_of(pdf)
    PDF::Inspector::Text.analyze(pdf).strings.join(" ")
  end

  def strings_of(pdf)
    PDF::Inspector::Text.analyze(pdf).strings
  end

  def positions_of(pdf)
    PDF::Inspector::Text.analyze(pdf).positions
  end

  def reader_for(pdf)
    PDF::Reader.new(StringIO.new(pdf))
  end

  def page_count(pdf)
    reader_for(pdf).page_count
  end

  def image_count(pdf)
    pdf.scan(%r{/Subtype /Image}).size
  end

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
