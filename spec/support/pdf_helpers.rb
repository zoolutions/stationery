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

  # Every text run of every page as [text, baseline y] (PDF bottom-up coordinates).
  def page_runs(pdf)
    reader_for(pdf).pages.map { |page| page.runs.map { |run| [run.text, run.origin.y.round(3)] } }
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

  # Every internal link as [page index it sits on, target page index, target top].
  def link_destinations(pdf)
    reader = reader_for(pdf)
    objects = reader.objects
    pages = objects.page_references
    reader.pages.each_with_index.flat_map do |page, index|
      Array(objects.deref(page.attributes[:Annots])).filter_map do |ref|
        dest = objects.deref(ref)[:Dest]
        dest && [index, pages.index(dest[0]), dest[3]]
      end
    end
  end

  # The document outline as nested hashes (title, target page index, top,
  # count, children), or nil when the catalog has none.
  def outline_of(pdf)
    objects = reader_for(pdf).objects
    root = objects.deref(objects.deref(objects.trailer[:Root])[:Outlines])
    root && outline_children(objects, root)
  end

  def outline_children(objects, parent)
    ref = parent[:First]
    items = []
    while ref
      node = objects.deref(ref)
      dest = node[:Dest]
      items << { title: node[:Title], page: objects.page_references.index(dest[0]), top: dest[3],
                 count: node[:Count], children: outline_children(objects, node) }
      ref = node[:Next]
    end
    items
  end

  # Decompressed content stream of every page, for operator-level assertions.
  def page_contents(pdf)
    reader_for(pdf).pages.map(&:raw_content)
  end
end

RSpec.configure { |config| config.include PdfHelpers }
