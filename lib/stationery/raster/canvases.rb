# frozen_string_literal: true

module Stationery
  module Raster
    # The canvases of a raster render (what Document#paint_on is handed, as
    # PDF::Canvases is for a PDF): every canvas of a page records into that
    # page's list, which stays open until the render has painted everything
    # (page numbers are drawn last) and is then replayed (see Painter). A
    # page keeps a list of calls, not pixels, which is far less than a
    # bitmap of every page of a long document. `monochrome` is the
    # Monochrome::Rules of a monochrome render.
    class Canvases
      def initialize(debug: false, warnings: nil, monochrome: nil)
        @debug = debug
        @warnings = warnings
        @monochrome = monochrome
        @lists = {}.compare_by_identity
      end

      # What was drawn on `page`, bottom first.
      def list(page) = @lists[page] ||= []

      # The list of `page`, let go of here.
      def release(page) = @lists.delete(page) || []

      def body(page) = canvas(page, debug: @debug)

      # What a template paints on the `:background` layer goes under
      # everything painted on the page before it.
      def template(page, layer = :foreground)
        calls = list(page)
        mark = calls.size
        yield canvas(page, template: true, debug: @debug)
        calls.unshift(*calls.slice!(mark..)) if layer == :background
      end

      def over(page) = canvas(page)

      private

      def canvas(page, template: false, debug: false)
        options = { template:, debug:, warnings: @warnings }
        return Canvas.new(page, list(page), **options) unless @monochrome

        MonochromeCanvas.new(page, list(page), @monochrome, **options)
      end
    end
  end
end
