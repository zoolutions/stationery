# frozen_string_literal: true

module Stationery
  module Layout
    # Lays a node tree out onto as many pages as it needs. Content placed
    # taller than a page is kept (never raised on) and recorded in #warnings.
    class Paginator
      attr_reader :warnings

      def initialize(resources:, page: {}, warnings: Warnings.new, debug: false)
        @resources = resources
        @debug = debug
        @page_options = page
        @warnings = warnings
      end

      def paginate(root)
        root = Flow.new([root]) unless root.is_a?(Flow)
        pages = []
        remaining = root
        while remaining
          page = Page.new(**@page_options)
          head, remaining = remaining.split(page.content_box.width, page.content_box.height, fresh: true)
          place(page, head, pages.size + 1)
          pages << page
        end
        pages
      end

      private

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
