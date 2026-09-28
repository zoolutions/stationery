# frozen_string_literal: true

# One-page PDFs written by hand, for what Stationery itself never writes: a
# rotated page, a form the page draws, a widget whose appearance has states.
module RawPdf
  HELVETICA = { Type: :Font, Subtype: :Type1, BaseFont: :Helvetica, Encoding: :WinAnsiEncoding }.freeze

  # A 300 × 200 page showing `content`, with Helvetica as /F1. The block is
  # given the writer and the font's reference, and answers what else the
  # page dictionary holds.
  def raw_pdf(content)
    writer = Stationery::PDF::Writer.new
    font = writer.add(HELVETICA)
    pages = writer.reserve
    page = { Type: :Page, Parent: pages, MediaBox: [0, 0, 300, 200], Resources: { Font: { F1: font } },
             Contents: writer.add(Stationery::PDF::Stream.new(content)) }
    page = page.merge(yield(writer, font)) if block_given?
    writer.set(pages, { Type: :Pages, Kids: [writer.add(page)], Count: 1 })
    writer.render(root: writer.add({ Type: :Catalog, Pages: pages }), info: writer.add({}))
  end

  # A form XObject 100 × 20 showing `content`, with Helvetica as /F1.
  def raw_form(writer, font, content, **entries)
    dictionary = { Type: :XObject, Subtype: :Form, BBox: [0, 0, 100, 20], Resources: { Font: { F1: font } } }
    writer.add(Stationery::PDF::Stream.new(content, dictionary.merge(entries)))
  end

  # An image XObject of one black pixel.
  def raw_image(writer)
    dictionary = { Type: :XObject, Subtype: :Image, Width: 1, Height: 1, ColorSpace: :DeviceGray, BitsPerComponent: 8 }
    writer.add(Stationery::PDF::Stream.new("\x00", dictionary))
  end
end

RSpec.configure { |config| config.include RawPdf }
