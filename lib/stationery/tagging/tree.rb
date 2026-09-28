# frozen_string_literal: true

module Stationery
  module Tagging
    # One render's structure: the Document element and, per page, the element
    # each MCID belongs to (what the parent tree maps back from).
    class Tree
      # What an alt text has when it describes anything: a character that is not whitespace.
      DESCRIPTION = /[^[:space:]]/

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

      # Records the accessibility gaps `strict` should catch, which PDF/UA
      # refuses (PDF::Conformance#audit!). A figure needs an alt text (ISO
      # 14289-1, 7.3): veraPDF fails one that is missing or empty (rule
      # 7.3-1), and one of whitespace alone describes as little.
      def audit(pages, warnings, lang:)
        warnings << Warnings::MissingLanguage.new unless lang
        figures(@root).each do |figure|
          next if figure.alt.to_s.match?(DESCRIPTION)

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
