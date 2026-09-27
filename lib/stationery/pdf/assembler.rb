# frozen_string_literal: true

module Stationery
  module PDF
    # Writes finished pages, their shared resources and document info as PDF.
    class Assembler
      def initialize(pages:, resources:, info: {}, outline: [])
        @pages = pages
        @resources = resources
        @info = info
        @outline = outline
      end

      def render
        writer = Writer.new
        tree = writer.reserve
        refs = @resources.build(writer)
        kids = @kids = @pages.map { writer.reserve }
        @pages.each_with_index { |page, index| write_page(writer, page, kids[index], tree, refs) }
        writer.set(tree, { Type: :Pages, Kids: kids, Count: kids.size })
        root = writer.add(catalog(tree, OutlineWriter.new(writer, @outline, kids).write))
        writer.render(root:, info: writer.add(info_dictionary))
      end

      private

      def catalog(tree, outlines)
        catalog = { Type: :Catalog, Pages: tree }
        outlines ? catalog.merge(Outlines: outlines, PageMode: :UseOutlines) : catalog
      end

      def write_page(writer, page, ref, tree, refs)
        dictionary = {
          Type: :Page, Parent: tree, MediaBox: [0, 0, *page.size],
          Contents: writer.add(Stream.new(page.content)), Resources: page_resources(page, refs)
        }
        dictionary[:Annots] = page.annotations.map { |link| writer.add(annotation(link)) } if page.annotations.any?
        writer.set(ref, dictionary)
      end

      def page_resources(page, refs)
        page.resource_names.to_h do |category, names|
          [category, names.to_h { |name| [name, refs.fetch(category).fetch(name)] }]
        end
      end

      def annotation(link)
        target = if (dest = link[:dest])
                   { Dest: [@kids.fetch(dest.page), :XYZ, nil, dest.top, nil] }
                 else
                   { A: { Type: :Action, S: :URI, URI: link[:url].b } }
                 end
        { Type: :Annot, Subtype: :Link, Rect: link[:rect], Border: [0, 0, 0], **target }
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
