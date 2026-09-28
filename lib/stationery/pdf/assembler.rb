# frozen_string_literal: true

module Stationery
  module PDF
    # Writes finished pages, their shared resources and document info as PDF.
    class Assembler
      # `tagging:` (a Tagging::Tree) writes the structure tree of a tagged PDF;
      # `lang:` is the document's natural language; `page_labels:` is the
      # /PageLabels number tree from PageLabels.entries; `attachments:` are
      # PDF::Attachment files to embed; `xmp:` (true) writes the XMP packet,
      # with `xmp_extensions:` as further schemas (see XMP); `conformance:` (a
      # PDF::Conformance) adds what PDF/A and PDF/UA ask of the file.
      def initialize(pages:, resources:, info: {}, outline: [], encryption: nil, tagging: nil, lang: nil,
                     page_labels: nil, attachments: [], xmp: true, xmp_extensions: {}, conformance: nil)
        @conformance = conformance
        @tagging = tagging
        @lang = lang
        @page_labels = page_labels
        @attachments = attachments
        @xmp = xmp
        @xmp_extensions = xmp_extensions
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
        now = Time.now
        info = info_dictionary(now)
        entries = catalog(tree, outlines, @form.write)
                  .merge(accessibility(writer), metadata(writer, info, now), Attachments.write(writer, @attachments))
        entries.merge!(@conformance.catalog_entries(writer)) if @conformance
        writer.render(root: writer.add(entries), info: writer.add(info))
      end

      private

      def catalog(tree, outlines, form)
        catalog = { Type: :Catalog, Pages: tree }
        catalog[:PageLabels] = @page_labels if @page_labels
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
        dictionary.merge!(@conformance.page_entries(page)) if @conformance
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
        dictionary = dictionary.merge(@conformance.annotation_entries(annotation)) if @conformance
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

      def info_dictionary(now)
        info = { Producer: "Stationery #{VERSION}" }.merge(@info.compact)
        info = info.transform_values { |value| TextString.new(value.to_s) }
        info[:CreationDate] = TextString.new(now.utc.strftime("D:%Y%m%d%H%M%SZ"))
        info
      end

      def extensions = (@conformance&.xmp_extensions || {}).merge(@xmp_extensions)

      # The XMP packet as an uncompressed /Metadata stream, mirroring the Info
      # dictionary at the same instant. An encrypted document encrypts it like
      # every other stream (/EncryptMetadata defaults to true).
      def metadata(writer, info, now)
        return {} unless @xmp

        values = info.except(:CreationDate).transform_values(&:value)
        packet = XMP.packet(info: values, lang: @lang, time: now, extensions:, schemas: @conformance&.xmp_schemas || [])
        { Metadata: writer.add(Stream.new(packet, { Type: :Metadata, Subtype: :XML }, compress: false)) }
      end
    end
  end
end
