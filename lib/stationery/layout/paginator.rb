# frozen_string_literal: true

module Stationery
  module Layout
    # Lays a node tree out onto as many pages as it needs. Content placed
    # taller than a page is kept (never raised on) and recorded in #warnings.
    class Paginator
      attr_reader :warnings

      def initialize(resources:, page: {}, regions: nil)
        @resources = resources
        @page_options = page
        @regions = regions
        @warnings = []
      end

      def paginate(root)
        root = Flow.new([root]) unless root.is_a?(Flow)
        pages = []
        remaining = root
        while remaining
          page = new_page(pages.size + 1)
          head, remaining = remaining.split(page.content_box.width, page.content_box.height, fresh: true)
          place(page, head, pages.size + 1)
          pages << page
        end
        pages
      end

      private

      def new_page(number)
        page = Page.new(**@page_options, reserve: @regions ? @regions.reserve(number) : [0, 0])
        return page if page.reserve.sum < page.margin_box.height

        raise ArgumentError, "header and footer leave no room for content on page #{number}"
      end

      def place(page, head, number)
        return unless head

        box = page.content_box
        height = head.measure(box.width)
        @warnings << Overflow.new(page: number, height:, available: box.height) if height > box.height + EPSILON
        head.paint(Canvas.new(page, @resources), box.x, box.y, box.width)
      end
    end
  end
end
