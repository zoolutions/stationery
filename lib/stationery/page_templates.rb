# frozen_string_literal: true

module Stationery
  # What a page template knows about the page it draws on.
  PageInfo = Data.define(:number, :count, :width, :height, :margin, :content_box)

  # Runs a document's page templates on every finished page.
  class PageTemplates
    def initialize(document, book:, resources:)
      @document = document
      @book = book
      @resources = resources
      @templates = document.class.config[:templates]
    end

    def apply(pages)
      return if @templates.empty?

      pages.each_with_index do |page, index|
        info = PageInfo.new(index + 1, pages.size, page.width, page.height, page.margin, page.content_box)
        @templates.each { |layer, block| draw(page, info, layer, block) }
      end
    end

    private

    def draw(page, info, layer, block)
      builder = Builder.new(book: @book, text: @document.class.config[:text])
      @document.build_with(builder) { @document.instance_exec(info, &block) }
      mark = page.content.bytesize
      box = page.content_box
      builder.root.paint(Canvas.new(page, @resources, template: true), box.x, box.y, box.width)
      page.content.prepend(page.content.slice!(mark..)) if layer == :background
    end
  end
end
