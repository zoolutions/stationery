# frozen_string_literal: true

module Stationery
  module PDF
    # Writes finished pages, their shared resources and document info as PDF.
    class Assembler
      # `tagging:` (a Tagging::Tree) writes the structure tree of a tagged PDF;
      # `lang:` is the document's natural language.
      def initialize(pages:, resources:, info: {}, outline: [], encryption: nil, tagging: nil, lang: nil)
        @tagging = tagging
        @lang = lang
        @pages = pages
        @resources = resources
        @info = info
        @outline = outline
        @encryption = encryption
      end

      def render
        writer = Writer.new(encryption: @encryption)
        @form = Forms::AcroForm.new(writer)
        tree = writer.reserve
        refs = @resources.build(writer)
        kids = @kids = @pages.map { writer.reserve }
        @structure = @tagging && Tagging::Writer.new(@tagging, pages: @pages, refs: kids)
        @pages.each_with_index { |page, index| write_page(writer, page, kids[index], tree, refs) }
        writer.set(tree, { Type: :Pages, Kids: kids, Count: kids.size })
        outlines = OutlineWriter.new(writer, @outline, kids).write
        root = writer.add(catalog(tree, outlines, @form.write).merge(accessibility(writer)))
        writer.render(root:, info: writer.add(info_dictionary))
      end

      private

      def catalog(tree, outlines, form)
        catalog = { Type: :Catalog, Pages: tree }
        catalog[:AcroForm] = form if form
        outlines ? catalog.merge(Outlines: outlines, PageMode: :UseOutlines) : catalog
      end

      def accessibility(writer)
        entries = @lang ? { Lang: PDF::TextString.new(@lang.to_s) } : {}
        return entries unless @structure

        entries.merge!(@structure.write(writer))
        @info[:Title] ? entries.merge(ViewerPreferences: { DisplayDocTitle: true }) : entries
      end

      def write_page(writer, page, ref, tree, refs)
        dictionary = {
          Type: :Page, Parent: tree, MediaBox: [0, 0, *page.size],
          Contents: writer.add(Stream.new(page.content)), Resources: page_resources(page, refs)
        }
        if page.annotations.any?
          dictionary[:Annots] = page.annotations.map { |annot| annotation_ref(writer, annot, ref) }
        end
        dictionary.merge!(@structure.page_entries(page)) if @structure
        writer.set(ref, dictionary)
      end

      def page_resources(page, refs)
        page.resource_names.to_h do |category, names|
          [category, names.to_h { |name| [name, refs.fetch(category).fetch(name)] }]
        end
      end

      def annotation_ref(writer, annotation, page)
        if annotation[:widget]
          return @form.add(annotation[:widget], annotation[:rect], page) do |widget_ref|
            @structure ? @structure.annotation(annotation, widget_ref) : {}
          end
        end

        ref = writer.reserve
        dictionary = annotation(annotation)
        dictionary = dictionary.merge(@structure.annotation(annotation, ref)) if @structure
        writer.set(ref, dictionary)
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
