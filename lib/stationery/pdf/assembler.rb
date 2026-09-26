# frozen_string_literal: true

module Stationery
  module PDF
    # Writes finished pages, their shared resources and document info as PDF.
    class Assembler
      def initialize(pages:, resources:, info: {})
        @pages = pages
        @resources = resources
        @info = info
      end

      def render
        writer = Writer.new
        tree = writer.reserve
        refs = @resources.build(writer)
        kids = @pages.map { |page| write_page(writer, page, tree, refs) }
        writer.set(tree, { Type: :Pages, Kids: kids, Count: kids.size })
        root = writer.add({ Type: :Catalog, Pages: tree })
        writer.render(root:, info: writer.add(info_dictionary))
      end

      private

      def write_page(writer, page, tree, refs)
        dictionary = {
          Type: :Page, Parent: tree, MediaBox: [0, 0, *page.size],
          Contents: writer.add(Stream.new(page.content)), Resources: page_resources(page, refs)
        }
        dictionary[:Annots] = page.annotations.map { |link| writer.add(annotation(link)) } if page.annotations.any?
        writer.add(dictionary)
      end

      def page_resources(page, refs)
        page.resource_names.to_h do |category, names|
          [category, names.to_h { |name| [name, refs.fetch(category).fetch(name)] }]
        end
      end

      def annotation(link)
        { Type: :Annot, Subtype: :Link, Rect: link[:rect], Border: [0, 0, 0],
          A: { Type: :Action, S: :URI, URI: link[:url].b } }
      end

      def info_dictionary
        info = { Producer: "Stationery #{VERSION}" }.merge(@info.compact)
        info = info.transform_values { |value| TextString.new(value.to_s) }
        info[:CreationDate] = TextString.new(Time.now.utc.strftime("D:%Y%m%d%H%M%SZ"))
        info
      end
    end
  end
end
