# frozen_string_literal: true

require "pathname"
require "stringio"
require "stationery"
require_relative "structure_reader"

module Stationery
  module Testing
    # Reads a rendered PDF back for assertions. The subject is a
    # Stationery::Document, PDF bytes, a path (String or Pathname) or an IO.
    # Needs the pdf-reader gem, loaded on first use.
    class Inspector
      UTF16_BOM = "\xFE\xFF".b
      # id-aa-signatureTimeStampToken: a signature's RFC 3161 timestamp.
      TIMESTAMP_TOKEN = "1.2.840.113549.1.9.16.2.14"
      XMP_PROPERTY = %r{^\s*<((?!rdf:)[\w.-]+:[\w.-]+)>(.*?)</\1>$}
      XMP_ITEM = %r{<rdf:li[^>]*>(.*?)</rdf:li>}
      XMP_ENTITIES = { "&amp;" => "&", "&lt;" => "<", "&gt;" => ">", "&quot;" => '"' }.freeze

      def initialize(subject)
        @subject = subject
      end

      def pdf
        @pdf ||= case @subject
                 when Document then @subject.to_pdf
                 when String then @subject.start_with?("%PDF") ? @subject : File.binread(@subject)
                 when Pathname then File.binread(@subject)
                 else @subject.read
                 end
      end

      def reader
        @reader ||= begin
          require "pdf/reader"
          ::PDF::Reader.new(StringIO.new(pdf))
        rescue LoadError
          raise Stationery::Error, 'Stationery::Testing needs pdf-reader: add gem "pdf-reader" to your test group'
        end
      end

      def page_count = reader.page_count
      def page_texts = @page_texts ||= reader.pages.map { |page| MarkedText.read(page).layout.squeeze(" ").strip }
      def text = page_texts.join("\n")
      def metadata = reader.info

      # The XMP packet (the catalog's /Metadata stream) as a String, or nil.
      def xmp
        return unless catalog[:Metadata]

        objects.deref!(catalog[:Metadata]).unfiltered_data.dup.force_encoding(Encoding::UTF_8)
      end

      # The packet's properties by prefixed name (`"dc:title"`): a plain value
      # as a String, an rdf:Alt as its default String, an rdf:Seq or rdf:Bag as
      # an Array. Reads the packets Stationery writes (one property per line).
      def xmp_values
        packet = xmp
        return {} unless packet

        packet.scan(XMP_PROPERTY).to_h { |name, body| [name, xmp_value(body)] }
      end

      # The conformance levels the XMP packet claims, as PDF::Conformance
      # names them: `[:pdf_a3b, :pdf_ua1]`, or [] without a claim.
      def conformance
        values = xmp_values
        part, level, accessible = values.values_at("pdfaid:part", "pdfaid:conformance", "pdfuaid:part")
        [part && :"pdf_a#{part}#{level.to_s.downcase}", accessible && :"pdf_ua#{accessible}"].compact
      end

      # The Factur-X / ZUGFeRD invoice the XMP packet names: `{ profile:
      # :en16931, filename:, version:, xml: }` (xml nil when the file it
      # names is not embedded), or nil for any other PDF.
      def factur_x
        values = xmp_values
        filename = values["fx:DocumentFileName"]
        return unless filename

        file = attachments.find { |attachment| attachment[:name] == filename }
        { profile: PDF::FacturX::PROFILES.key(values["fx:ConformanceLevel"]), filename:,
          version: values["fx:Version"], xml: file && file[:bytes].dup.force_encoding(Encoding::UTF_8) }
      end

      def image_count = pdf.scan(%r{/Subtype\s*/Image\b}).size

      def warnings
        return [] unless @subject.is_a?(Document)

        pdf
        @subject.warnings.to_a
      end

      def links
        annotations.filter_map { |annot| annot.dig(:A, :URI) if annot.dig(:A, :S) == :URI }
      end

      def internal_links
        annotations.filter_map do |annot|
          dest = annot[:Dest] || (annot.dig(:A, :D) if annot.dig(:A, :S) == :GoTo)
          destination(dest) if dest
        end
      end

      def bookmarks
        outlines = catalog[:Outlines]
        outlines ? titles(outlines[:First]) : []
      end

      # The catalog /Lang written by `metadata lang:`, or nil.
      def lang
        lang = catalog[:Lang]
        decode(lang) if lang
      end

      # One label per page from the catalog /PageLabels ("i", "A-1", …), nil
      # for pages before the first labelled range; empty without labels.
      def page_labels
        labels = catalog[:PageLabels]
        return [] unless labels

        nums = objects.deref_array(objects.deref_hash(labels)[:Nums]).map { |value| objects.deref(value) }
        nums = nums.map { |value| value.is_a?(Hash) ? value.transform_values { |v| decode_value(v) } : value }
        PDF::PageLabels.labels(nums, page_count)
      end

      # Every embedded file from the catalog's /EmbeddedFiles name tree:
      # `{ name:, mime:, bytes:, description:, relationship: }` (bytes inflated).
      def attachments
        names = catalog.dig(:Names, :EmbeddedFiles)
        return [] unless names

        entries = objects.deref_array(objects.deref_hash(names)[:Names])
        entries.each_slice(2).map { |_name, ref| attachment(objects.deref_hash(ref)) }
      end

      # Every signed signature field: `{ field:, name:, reason:, location:,
      # signed_at:, subfilter:, byte_range:, signer:, valid:, timestamp: }`.
      # `signer` is the signing certificate's subject ("CN=…,O=…"). `valid` is
      # whether the signature covers the whole file and verifies against the
      # certificate it carries; the certificate's own trust is not judged.
      # `timestamp` is nil, or `{ time:, tsa:, valid: }` for the RFC 3161 token
      # a signature carries: `valid` when the token is over this signature
      # and verifies against the TSA certificate it carries.
      def signatures
        form = catalog[:AcroForm]
        return [] unless form

        require "openssl"
        signature_fields(objects.deref_hash(form)[:Fields], nil)
      end

      # The structure tree of a tagged PDF as nested arrays; see StructureReader.
      def structure = @structure ||= StructureReader.new(reader).tree

      # Whether the catalog marks the PDF as tagged and holds a structure tree.
      def tagged?
        catalog.dig(:MarkInfo, :Marked) == true && !catalog[:StructTreeRoot].nil?
      end

      # Text shown outside any marked content (neither tagged nor an artifact).
      def untagged_text
        @untagged_text ||= reader.pages.flat_map { |page| MarkedText.read(page).unmarked }
      end

      private

      def objects = reader.objects
      def catalog = objects.deref!(objects.trailer[:Root])

      def annotations
        reader.pages.flat_map do |page|
          Array(objects.deref_array(page.attributes[:Annots])).map do |ref|
            annot = objects.deref_hash(ref)
            annot.merge(A: objects.deref_hash(annot[:A]))
          end
        end
      end

      def attachment(spec)
        stream = objects.deref(objects.deref_hash(spec[:EF])[:F])
        relationship = PDF::Attachments::RELATIONSHIPS.key(spec[:AFRelationship]) || spec[:AFRelationship]
        { name: decode(spec[:UF] || spec[:F]), mime: stream.hash[:Subtype].to_s, bytes: stream.unfiltered_data,
          description: spec[:Desc] && decode(spec[:Desc]), relationship: }
      end

      def signature_fields(refs, prefix)
        Array(objects.deref_array(refs)).flat_map do |ref|
          field = objects.deref_hash(ref)
          name = [prefix, field[:T] && decode(field[:T])].compact.join(".")
          kids = Array(objects.deref_array(field[:Kids])).select { |kid| objects.deref_hash(kid).key?(:T) }
          next signature_fields(kids, name) if kids.any?

          field[:FT] == :Sig && field[:V] ? [signature(name, objects.deref_hash(field[:V]))] : []
        end
      end

      def signature(field, value)
        range = objects.deref_array(value[:ByteRange])
        text = value.slice(:Name, :Reason, :Location).transform_values { |string| decode(string) }
        { field:, name: text[:Name], reason: text[:Reason], location: text[:Location],
          signed_at: signing_time(value[:M]), subfilter: value[:SubFilter], byte_range: range, **verdict(range) }
      end

      def signing_time(date)
        digits = date.to_s[/\AD:(\d{14})/, 1]
        digits && Time.utc(*digits.unpack("a4a2a2a2a2a2").map(&:to_i))
      end

      # The signature is read from the file by its byte range, not from the
      # parsed dictionary: it is the one string encryption leaves alone.
      def verdict(range)
        contents = pdf.byteslice(range[1], range[2] - range[1]).to_s
        der = PDF::Signature.der([contents[1..-2]].pack("H*"))
        cms = OpenSSL::PKCS7.new(der)
        signed = pdf.byteslice(range[0], range[1]) + pdf.byteslice(range[2], range[3])
        flags = OpenSSL::PKCS7::NOVERIFY | OpenSSL::PKCS7::BINARY
        whole = range[0].zero? && range[2] + range[3] == pdf.bytesize && contents.start_with?("<")
        { signer: signer(cms), valid: whole && cms.verify([], OpenSSL::X509::Store.new, signed, flags),
          timestamp: timestamp(der) }
      rescue OpenSSL::OpenSSLError, ArgumentError, TypeError
        { signer: nil, valid: false, timestamp: nil }
      end

      # The timestamp token among the first SignerInfo's unsigned attributes,
      # judged against that SignerInfo's signature value; nil without one.
      def timestamp(der)
        info = OpenSSL::ASN1.decode(der).value[1].value[0].value[4].value[0].value
        unsigned = info[6..].to_a.find { |item| item.tag == 1 && item.tag_class == :CONTEXT_SPECIFIC }
        attribute = unsigned&.value&.find { |one| one.value[0].oid == TIMESTAMP_TOKEN }
        attribute && timestamp_verdict(attribute.value[1].value.first, info[5].value)
      end

      # The token verified as a TimeStampResp would be, against the signature
      # value it should cover. The certificates it carries are the trust
      # anchors (a TSA sends its chain, often without the root), so this
      # says the token is sound, not that the TSA is one to trust.
      def timestamp_verdict(token, signature)
        granted = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(0)])
        response = OpenSSL::Timestamp::Response.new(OpenSSL::ASN1::Sequence.new([granted, token]).to_der)
        info = response.token_info
        covers = info.message_imprint == OpenSSL::Digest.digest(info.algorithm, signature)
        { time: info.gen_time, tsa: signer(response.token), valid: covers && timestamp_verifies?(response) }
      end

      def timestamp_verifies?(response)
        info = response.token_info
        request = OpenSSL::Timestamp::Request.new
        request.algorithm = info.algorithm
        request.message_imprint = info.message_imprint
        request.nonce = info.nonce if info.nonce
        store = OpenSSL::X509::Store.new
        store.flags = OpenSSL::X509::V_FLAG_PARTIAL_CHAIN
        response.token.certificates.to_a.each { |certificate| store.add_cert(certificate) }
        response.verify(request, store)
        true
      rescue OpenSSL::OpenSSLError
        false
      end

      def signer(cms)
        info = cms.signers.first
        certificate = cms.certificates.find { |one| one.serial == info.serial && one.issuer == info.issuer }
        certificate&.subject&.to_utf8
      end

      def xmp_value(body)
        items = body.scan(XMP_ITEM).flatten.map { |item| xmp_text(item) }
        return xmp_text(body) if items.empty?

        body.start_with?("<rdf:Alt>") ? items.first : items
      end

      def xmp_text(value) = value.gsub(/&(amp|lt|gt|quot);/, XMP_ENTITIES)

      def destination(dest)
        return dest.to_s unless dest.is_a?(Array)

        objects.page_references.index(dest.first) + 1
      end

      def titles(item)
        return [] unless item

        [decode(item[:Title]), *titles(item[:First]), *titles(item[:Next])]
      end

      def decode_value(value) = value.is_a?(String) ? decode(value) : value

      def decode(title)
        return title.dup.force_encoding(Encoding::UTF_8) unless title.b.start_with?(UTF16_BOM)

        title.b.byteslice(2..).force_encoding(Encoding::UTF_16BE).encode(Encoding::UTF_8)
      end
    end
  end
end
