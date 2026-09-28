# frozen_string_literal: true

module Stationery
  module PDF
    # The canvases of a PDF render: what the paginator, the page templates
    # and Structure ask for the canvas they paint a page on. A render to
    # another output hands them canvases of its own (Document#paint_on),
    # answering these three with canvases that include Canvas::Interface.
    # `monochrome` is the Monochrome::Rules of a monochrome render: its
    # canvases paint through them.
    class Canvases
      def initialize(resources, debug = false, tagging = nil, warnings = nil, monochrome: nil) # rubocop:disable Style/OptionalBooleanParameter
        @resources = resources
        @debug = debug
        @tagging = tagging
        @warnings = warnings
        @monochrome = monochrome
      end

      # Whether the canvases build a structure tree.
      def tagging? = !@tagging.nil?

      # The canvas the content of `page` is painted on.
      def body(page)
        canvas(page, debug: @debug, tagging: @tagging, warnings: @warnings)
      end

      # Yields the canvas a header, a footer or a page template paints on,
      # once the content of `page` is painted; what it paints on the
      # `:background` layer goes under that content.
      def template(page, layer = :foreground)
        mark = page.content.bytesize
        yield canvas(page, template: true, debug: @debug, tagging: @tagging, warnings: @warnings)
        page.lower(mark) if layer == :background
      end

      # The canvas a page number is drawn on, over everything on `page`.
      def over(page)
        canvas(page, tagging: @tagging)
      end

      private

      def canvas(page, template: false, debug: false, tagging: nil, warnings: nil)
        return Canvas.new(page, @resources, template:, debug:, tagging:, warnings:) unless @monochrome

        Monochrome::Canvas.new(page, @resources, @monochrome, template:, debug:, tagging:, warnings:)
      end
    end
  end
end
