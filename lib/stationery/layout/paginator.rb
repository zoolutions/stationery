# frozen_string_literal: true

module Stationery
  module Layout
    # Lays a node tree out onto as many pages as it needs. Content placed
    # taller than a page is kept (never raised on) and recorded in #warnings.
    class Paginator
      attr_reader :warnings

      # What `max_pages` takes: a count of pages, or nil for any number.
      def self.limit(count)
        return count if count.nil? || (count.is_a?(Integer) && count.positive?)

        raise ArgumentError, "max_pages is an Integer of 1 or more, or nil, not #{count.inspect}"
      end

      # `canvases:` makes the canvas of each page (see PDF::Canvases); without
      # them the pages are painted for a PDF that names what it draws in
      # `resources:`. A render that needs more than `max_pages` pages lays
      # them all out and reports Warnings::TooManyPages.
      def initialize(resources: nil, canvases: nil, page: {}, warnings: Warnings.new, debug: false, regions: nil,
                     tagging: nil, max_pages: nil)
        @canvases = canvases || PDF::Canvases.new(resources, debug, tagging, warnings)
        @page_options = page
        @regions = regions
        @warnings = warnings
        @max_pages = self.class.limit(max_pages)
      end

      # With a block, each page is handed to it as soon as it is painted.
      # Only what is still to be placed is held on to, so the nodes of a
      # painted page can be collected once the caller lets go of the root.
      def paginate(root)
        remaining = root.is_a?(Flow) ? root : Flow.new([root])
        root = nil # rubocop:disable Lint/UselessAssignment -- or this frame holds every node until the last page
        pages = []
        while remaining
          number = pages.size + 1
          page, head, remaining = next_page(remaining, number)
          moved = Opening.of(head) if number == @max_pages&.succ
          place(page, head, number)
          head = nil
          yield page if block_given?
          pages << page
        end
        too_many(pages.size, moved)
        pages
      end

      private

      def too_many(count, moved)
        return unless @max_pages && count > @max_pages

        @warnings << Warnings::TooManyPages.new(limit: @max_pages, pages: count, moved:)
      end

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
        canvas = @canvases.body(page)
        head.paint(canvas, box.x, box.y, box.width)
        canvas.debug_rect(box.x, box.y, box.width, box.height, :page)
      end
    end
  end
end
