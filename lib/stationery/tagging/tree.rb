# frozen_string_literal: true

module Stationery
  module Tagging
    # One render's structure: the Document element and, per page, the element
    # each MCID belongs to (what the parent tree maps back from).
    class Tree
      HEADING = /\AH[1-6]\z/
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
        headings(@root, 0, pages, warnings)
      end

      private

      def figures(element)
        element.elements.flat_map { |kid| kid.type == :Figure ? [kid] : figures(kid) }
      end

      # Heading levels, as ISO 14289-1, 7.4.2 asks and veraPDF checks them
      # (rule 7.4.2-1): read in the order of the tree, which is not always
      # the order of the pages, a heading is at most one level below the
      # heading before it, and the first is H1. Going back up is free (H3,
      # then H1), and a heading that skipped is what the next is measured
      # against (H1, H3, H4 reports H3 alone). Headings of headers, footers
      # and page templates are artifacts and a heading without content is
      # not written: neither is in the tree, so neither counts.
      #
      # Answers the level of the last heading under `element`, `last` without one.
      def headings(element, last, pages, warnings)
        element.kids.each do |kid|
          next unless kid.is_a?(Element)

          level = level_of(kid)
          if level.nil?
            last = headings(kid, last, pages, warnings)
          elsif !kid.empty?
            skipped(kid, level, last + 1, pages, warnings) if level > last + 1
            last = level
          end
        end
        last
      end

      # A heading's level, nil for any other element: the digit of its type,
      # read where it is so that an audit that finds nothing allocates nothing.
      def level_of(element)
        name = element.type.name
        name.getbyte(1) - "0".ord if name.match?(HEADING)
      end

      def skipped(heading, level, allowed, pages, warnings)
        warnings << Warnings::SkippedHeading.new(level:, allowed:, page: pages.index(first_page(heading)) + 1)
      end

      # The page of an element's first content, its own or an element's inside it (a link's).
      def first_page(element)
        element.kids.each do |kid|
          page = kid.is_a?(Element) ? first_page(kid) : kid.page
          return page if page
        end
        nil
      end
    end
  end
end
