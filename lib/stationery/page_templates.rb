# frozen_string_literal: true

module Stationery
  # What a page template knows about the page it draws on.
  PageInfo = Data.define(:number, :count, :width, :height, :margin, :content_box)

  # Paints a document's headers, footers and page templates on every
  # finished page.
  class PageTemplates
    def initialize(document, book:, resources:, regions: nil, warnings: [])
      @document = document
      @book = book
      @resources = resources
      @regions = regions
      @warnings = warnings
      @templates = document.class.config[:templates]
    end

    def apply(pages)
      pages.each_with_index do |page, index|
        info = PageInfo.new(index + 1, pages.size, page.width, page.height, page.margin, page.content_box)
        paint_regions(page, info) if @regions
        @templates.each { |layer, block| paint(page, root(info, block), page.content_box, layer) }
      end
    end

    private

    def paint_regions(page, info)
      box = page.margin_box
      Regions::SLOTS.each do |slot|
        region = @regions.entry_for(slot, info.number, last: info.number == info.count)
        next unless region&.block

        root = root(info, region.block)
        height = root.measure(box.width)
        reserved = @regions.height_of(region, info.number)
        overflow(info.number, height, reserved)
        y = slot == :header ? box.y : box.bottom - height
        paint(page, root, Rect.new(box.x, y, box.width, height))
      end
    end

    def overflow(number, height, reserved)
      return if height <= reserved + Layout::EPSILON

      @warnings << Layout::Overflow.new(page: number, height:, available: reserved)
    end

    def root(info, block) = @document.template_root(info, book: @book, &block)

    def paint(page, root, rect, layer = :foreground)
      mark = page.content.bytesize
      root.paint(Canvas.new(page, @resources), rect.x, rect.y, rect.width)
      page.content.prepend(page.content.slice!(mark..)) if layer == :background
    end
  end
end
