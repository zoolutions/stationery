# frozen_string_literal: true

module Stationery
  module PDF
    # Seals pages as the paginator finishes them, so a long document holds a
    # page's operators only while that page is painted.
    #
    # With a `writer:` every page is sealed and its body written at once: the
    # incremental render, whose pages get what is painted later (headers,
    # footers, page numbers) as streams of their own. Without one a page is
    # sealed only when `final:` says nothing paints on a page after its body
    # and no page number is waiting on it, so the file is the same bytes.
    class PageSealer
      attr_reader :writer

      def initialize(writer: nil, final: false)
        @writer = writer
        @final = final
      end

      def call(page)
        return write(page) if @writer

        page.seal if @final && page.slots.empty?
      end

      private

      def write(page)
        page.seal { |stream| @writer.add(stream) }
        @writer.flush
      end
    end
  end
end
