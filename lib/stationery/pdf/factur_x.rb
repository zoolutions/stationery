# frozen_string_literal: true

module Stationery
  module PDF
    # A Factur-X / ZUGFeRD e-invoice: the invoice's Cross Industry Invoice XML
    # embedded in a PDF/A-3b file and identified in XMP, so the one document
    # is read by people and booked by machines.
    #
    # Stationery carries the XML, it does not write or validate it: `xml` is
    # the finished document as a String, or a method name, block or callable
    # that answers it for the document being rendered.
    class FacturX
      NAMESPACE = "urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#"
      PROFILES = { minimum: "MINIMUM", basic_wl: "BASIC WL", basic: "BASIC", en16931: "EN 16931",
                   extended: "EXTENDED", xrechnung: "XRECHNUNG" }.freeze
      # Profiles too small to stand for the invoice: their XML is data beside
      # the page, not an alternative to it.
      DATA_ONLY = %i[minimum basic_wl].freeze
      FILENAMES = { xrechnung: "xrechnung.xml" }.freeze
      DEFAULT_FILENAME = "factur-x.xml"
      DESCRIPTION = "Factur-X Invoice"
      ROOTS = ["<?xml", "<rsm:CrossIndustryInvoice"].freeze
      SCHEMA = {
        name: "Factur-X PDFA Extension Schema", uri: NAMESPACE, prefix: "fx",
        properties: [
          { name: "DocumentFileName", type: "Text", category: "external",
            description: "The name of the embedded XML document" },
          { name: "DocumentType", type: "Text", category: "external",
            description: "The type of the hybrid document in capital letters, e.g. INVOICE or ORDER" },
          { name: "Version", type: "Text", category: "external",
            description: "The actual version of the standard applying to the embedded XML document" },
          { name: "ConformanceLevel", type: "Text", category: "external",
            description: "The conformance level of the embedded XML document" }
        ].freeze
      }.freeze

      attr_reader :xml, :profile, :filename, :version

      # The invoice for `spec` (`{ xml:, profile:, filename:, version:,
      # relationship: }`, as `factur_x` and `to_pdf(factur_x:)` take it)
      # resolved for `document`; nil without a spec.
      def self.for(spec, document)
        return unless spec

        spec = spec.to_h.transform_keys(&:to_sym)
        new(resolve(spec[:xml], document), **spec.except(:xml))
      end

      def self.resolve(xml, document)
        case xml
        when Symbol then document.send(xml)
        when Proc then xml.arity.zero? ? document.instance_exec(&xml) : xml.call(document)
        else xml.respond_to?(:call) ? xml.call(document) : xml
        end
      end

      def self.profile(name)
        name = name.to_s.downcase.to_sym
        return name if PROFILES.key?(name)

        raise ArgumentError, "unknown Factur-X profile #{name.inspect} (use #{PROFILES.keys.map(&:inspect).join(", ")})"
      end

      def self.invoice?(xml) = xml.is_a?(String) && xml.delete_prefix("﻿").lstrip.start_with?(*ROOTS)

      def initialize(xml, profile: :en16931, filename: nil, version: "1.0", relationship: nil)
        @profile = self.class.profile(profile)
        unless self.class.invoice?(xml)
          raise ArgumentError, "factur_x needs the invoice XML (a String starting with #{ROOTS.join(" or ")}), " \
                               "#{got(xml)}"
        end

        @xml = xml
        @filename = (filename || FILENAMES.fetch(@profile, DEFAULT_FILENAME)).to_s
        @version = version.to_s
        @relationship = relationship || (DATA_ONLY.include?(@profile) ? :data : :alternative)
      end

      # The fx:ConformanceLevel of the profile ("EN 16931").
      def level = PROFILES.fetch(@profile)

      # The declared conformance levels with the PDF/A-3b the invoice needs.
      def conformance(levels)
        levels = Array(levels).flatten.compact.map(&:to_sym)
        if levels.include?(:pdf_a2b)
          raise ArgumentError, "Factur-X embeds its XML, which needs PDF/A-3b: drop conformance :pdf_a2b"
        end

        levels.include?(:pdf_a3b) ? levels : levels + [:pdf_a3b]
      end

      # The XML as the file to embed, stamped `at` (its /ModDate).
      def attachment(at: Time.now)
        Attachments.build(@filename, @xml, mime: "text/xml", description: DESCRIPTION, relationship: @relationship,
                                           modified_at: at)
      end

      # The invoice's identification for the XMP packet (see XMP.packet).
      def xmp_extensions
        { NAMESPACE => { prefix: "fx", "DocumentType" => "INVOICE", "DocumentFileName" => @filename,
                         "Version" => @version, "ConformanceLevel" => level } }
      end

      # The description of the `fx` schema PDF/A asks for.
      def xmp_schema = SCHEMA

      private

      def got(xml)
        return "got #{xml.nil? ? "nil" : "a #{xml.class}"}" unless xml.is_a?(String)
        return "got an empty String" if xml.strip.empty?

        "got #{xml[0, 40].inspect}"
      end
    end
  end
end
