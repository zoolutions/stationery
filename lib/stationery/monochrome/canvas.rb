# frozen_string_literal: true

module Stationery
  module Monochrome
    # The PDF canvas of a monochrome render: what it paints goes through the
    # render's Rules first (see Painting). Made by PDF::Canvases only when
    # the render is monochrome.
    class Canvas < Stationery::Canvas
      include Painting

      def initialize(page, resources, rules, template: false, debug: false, tagging: nil, warnings: nil)
        super(page, resources, template:, debug:, tagging:, warnings:)
        @monochrome = rules
        @ctm = nil
        rules.page_number(page)
      end
    end
  end
end
