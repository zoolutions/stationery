# frozen_string_literal: true

module Stationery
  module Layout
    # Lays a node tree out onto as many pages as it needs. Content placed
    # taller than a page is kept (never raised on) and recorded in #warnings.
    class Paginator
      attr_reader :warnings

      def initialize(resources:, page: {}, warnings: Warnings.new, debug: false, regions: nil)
        @resources = resources
        @debug = debug
        @page_options = page
        @regions = regions
        @warnings = warnings
      end

      def paginate(root)
        root = Flow.new([root]) unless root.is_a?(Flow)
        pages = []
        remaining = root
        while remaining
          number = pages.size + 1
          page, head, remaining = next_page(remaining, number)
          place(page, head, number)
          pages << page
        end
        pages
      end

      private

      # A page whose regions differ when it is the last one tries the
      # last-page box first: if everything left fits, it is the last page.
      # Content that fits a normal page but not the last one moves partly on,
      # so the last page follows.
      def next_page(remaining, number)
        page = new_page(number)
        return [page, *fill(page, remaining)] unless @regions&.last_sensitive?(number)

        last = new_page(number, last: true)
        head, rest = fill(last, remaining)
        return [last, head, nil] unless rest

        normal_head, normal_rest = fill(page, remaining)
        normal_rest ? [page, normal_head, normal_rest] : [page, head, rest]
      end

      def fill(page, remaining) = remaining.split(page.content_box.width, page.content_box.height, fresh: true)

      def new_page(number, last: false)
        page = Page.new(**@page_options, reserve: @regions ? @regions.reserve(number, last:) : [0, 0])
        return page if page.reserve.sum < page.margin_box.height

        raise ArgumentError, "header and footer leave no room for content on page #{number}"
      end

      def place(page, head, number)
        return unless head

        box = page.content_box
        height = head.measure(box.width)
        @warnings << Overflow.new(page: number, height:, available: box.height) if height > box.height + EPSILON
        canvas = Canvas.new(page, @resources, debug: @debug)
        head.paint(canvas, box.x, box.y, box.width)
        canvas.debug_rect(box.x, box.y, box.width, box.height, :page)
      end
    end
  end
end
