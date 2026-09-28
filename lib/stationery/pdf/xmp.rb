# frozen_string_literal: true

module Stationery
  module PDF
    # The XMP metadata packet (ISO 16684-1) mirroring the document info:
    # Dublin Core title, creator, description, subject and language, the
    # `xmp:` dates and creator tool, and `pdf:` producer and keywords. Later
    # identification schemas (PDF/A, PDF/UA, Factur-X) go in `extensions:`.
    #
    # The packet is deterministic for the same info and time: no instance
    # ids, so two renders of one document are byte-identical.
    module XMP
      PACKET_ID = "W5M0MpCehiHzreSzNTczkc9d"
      PADDING = "#{" " * 63}\n" * 32 # 2 KB of whitespace, as the spec suggests
      DC = "http://purl.org/dc/elements/1.1/"
      XMP_NS = "http://ns.adobe.com/xap/1.0/"
      PDF_NS = "http://ns.adobe.com/pdf/1.3/"
      RDF = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

      module_function

      # `info` is the Info dictionary's keys (`:Title`, `:Author`, `:Subject`,
      # `:Keywords`, `:Creator`, `:Producer`), `lang` the catalog language,
      # `time` the creation instant, and `extensions` further schemas as
      # `{ namespace_uri => { prefix: "pdfaid", "part" => 3, "conformance" => "B" } }`:
      # each becomes one `rdf:Description`; Array values become an `rdf:Bag`.
      def packet(info: {}, lang: nil, time: Time.now, extensions: {})
        descriptions = [dublin_core(info, lang), xmp_schema(info, time), pdf_schema(info)]
        descriptions.concat(extensions.map { |uri, values| extension(uri, values) })
        body = <<~XML.gsub(/^ *\n/, "")
          <?xpacket begin="﻿" id="#{PACKET_ID}"?>
          <x:xmpmeta xmlns:x="adobe:ns:meta/">
           <rdf:RDF xmlns:rdf="#{RDF}">
          #{descriptions.compact.join("\n")}
           </rdf:RDF>
          </x:xmpmeta>
        XML
        "#{body}#{PADDING}<?xpacket end=\"w\"?>\n"
      end

      def escape(value)
        value.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub('"', "&quot;")
      end

      def dublin_core(info, lang)
        keywords = info[:Keywords].to_s.split(/,\s*/).reject(&:empty?)
        elements = [
          alt("dc:title", info[:Title]),
          seq("dc:creator", info[:Author]),
          alt("dc:description", info[:Subject]),
          bag("dc:subject", keywords),
          bag("dc:language", lang && [lang])
        ]
        description(DC, "dc", elements)
      end

      def xmp_schema(info, time)
        stamp = time.utc.strftime("%Y-%m-%dT%H:%M:%SZ")
        elements = [
          element("xmp:CreateDate", stamp), element("xmp:ModifyDate", stamp), element("xmp:MetadataDate", stamp),
          element("xmp:CreatorTool", info[:Creator])
        ]
        description(XMP_NS, "xmp", elements)
      end

      def pdf_schema(info)
        description(PDF_NS, "pdf", [element("pdf:Producer", info[:Producer]), element("pdf:Keywords", info[:Keywords])])
      end

      def extension(uri, values)
        prefix = values.fetch(:prefix) { raise ArgumentError, "XMP extension #{uri} needs a :prefix" }
        elements = values.except(:prefix).map do |name, value|
          value.is_a?(Array) ? bag("#{prefix}:#{name}", value) : element("#{prefix}:#{name}", value)
        end
        description(uri, prefix, elements)
      end

      def description(uri, prefix, elements)
        elements = elements.compact
        return if elements.empty?

        "  <rdf:Description rdf:about=\"\" xmlns:#{prefix}=\"#{escape(uri)}\">\n" \
          "#{elements.map { |line| "   #{line}\n" }.join}  </rdf:Description>"
      end

      def element(name, value)
        return if blank?(value)

        "<#{name}>#{escape(value)}</#{name}>"
      end

      def alt(name, value)
        return if blank?(value)

        "<#{name}><rdf:Alt><rdf:li xml:lang=\"x-default\">#{escape(value)}</rdf:li></rdf:Alt></#{name}>"
      end

      def seq(name, value) = list(name, "rdf:Seq", value)
      def bag(name, value) = list(name, "rdf:Bag", value)

      def list(name, container, values)
        values = Array(values).reject { |value| blank?(value) }
        return if values.empty?

        items = values.map { |value| "<rdf:li>#{escape(value)}</rdf:li>" }.join
        "<#{name}><#{container}>#{items}</#{container}></#{name}>"
      end

      def blank?(value) = value.nil? || value.to_s.empty?
    end
  end
end
