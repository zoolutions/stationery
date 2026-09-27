# frozen_string_literal: true

require_relative "marked_text"

module Stationery
  module Testing
    # Reads a tagged PDF's structure tree as nested arrays, each element's
    # text taken from the marked content it owns:
    #
    #   [[:Document, [[:H1, "Intro"], [:P, ["Read", [:Link, "the docs"], "now"]], [:Figure, "Logo"]]]]
    #
    # An element is [type, text] when it holds only text, [type, [kids]]
    # when it holds elements (with its own text between them), [type] when
    # empty. A Figure reads as its alt text. Untagged PDFs read as [].
    class StructureReader
      def initialize(reader)
        @reader = reader
        @objects = reader.objects
        @texts = {}
      end

      def tree
        root = @objects.deref(@objects.deref(@objects.trailer[:Root])[:StructTreeRoot])
        root ? kids_of(root).grep(Array) : []
      end

      private

      def element(dictionary)
        return [dictionary[:S], dictionary[:Alt]].compact if dictionary[:Alt]

        kids = merge(kids_of(dictionary, dictionary[:Pg]))
        return [dictionary[:S]] if kids.empty?

        [dictionary[:S], kids.size == 1 && kids.first.is_a?(String) ? kids.first : kids]
      end

      def kids_of(dictionary, page = nil)
        Array(@objects.deref(dictionary[:K])).filter_map do |kid|
          kid = @objects.deref(kid)
          case kid
          when Integer then text(page, kid)
          when Hash then kid[:Type] == :MCR ? text(kid[:Pg], kid[:MCID]) : kid_element(kid)
          end
        end
      end

      def kid_element(kid) = kid[:Type] == :OBJR ? nil : element(kid)

      # Adjacent strings (one element's marked content on two lines or pages) join with a space.
      def merge(kids)
        kids.each_with_object([]) do |kid, merged|
          next if kid.is_a?(String) && kid.strip.empty?

          if kid.is_a?(String) && merged.last.is_a?(String)
            merged[-1] = "#{merged.last} #{kid.strip}"
          else
            merged << (kid.is_a?(String) ? kid.strip : kid)
          end
        end
      end

      def text(page, mcid) = page_texts(page)[mcid]

      def page_texts(page)
        index = @objects.page_references.index(page)
        @texts[index] ||= MarkedText.read(@reader.page(index + 1)).texts
      end
    end
  end
end
