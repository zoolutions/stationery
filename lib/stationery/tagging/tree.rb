# frozen_string_literal: true

module Stationery
  module Tagging
    # One render's structure: the Document element and, per page, the element
    # each MCID belongs to (what the parent tree maps back from).
    class Tree
      attr_reader :root

      def initialize
        @root = Element.new(:Document)
        @pages = {}.compare_by_identity
      end

      # The next MCID on `page`, recorded as marked content of `element`.
      def mark(page, element)
        marked = (@pages[page] ||= [])
        marked << element
        element.kids << MarkedContent.new(page, marked.size - 1)
        marked.size - 1
      end

      def marked(page) = @pages.fetch(page, [])

      # Records the accessibility gaps `strict` should catch.
      def audit(pages, warnings, lang:)
        warnings << Warnings::MissingLanguage.new unless lang
        figures(@root).each do |figure|
          next if figure.alt

          page = pages.index(figure.marked_content.first.page) + 1
          warnings << Warnings::MissingAlt.new(kind: figure.kind, page:)
        end
      end

      private

      def figures(element)
        element.elements.flat_map { |kid| kid.type == :Figure ? [kid] : figures(kid) }
      end
    end
  end
end
