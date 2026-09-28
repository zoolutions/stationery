# frozen_string_literal: true

module Stationery
  module PDF
    # The canvases of a PDF render: what the paginator, the page templates
    # and Structure ask for the canvas they paint a page on. A render to
    # another output hands them canvases of its own (Document#paint_on),
    # answering these three with canvases that include Canvas::Interface.
    class Canvases
      def initialize(resources, debug = false, tagging = nil, warnings = nil) # rubocop:disable Style/OptionalBooleanParameter
        @resources = resources
        @debug = debug
        @tagging = tagging
        @warnings = warnings
      end

      # The canvas the content of `page` is painted on.
      def body(page)
        Canvas.new(page, @resources, debug: @debug, tagging: @tagging, warnings: @warnings)
      end

      # Yields the canvas a header, a footer or a page template paints on,
      # once the content of `page` is painted; what it paints on the
      # `:background` layer goes under that content.
      def template(page, layer = :foreground)
        mark = page.content.bytesize
        yield Canvas.new(page, @resources, template: true, debug: @debug, tagging: @tagging, warnings: @warnings)
        page.lower(mark) if layer == :background
      end

      # The canvas a page number is drawn on, over everything on `page`.
      def over(page)
        Canvas.new(page, @resources, tagging: @tagging)
      end
    end
  end
end
