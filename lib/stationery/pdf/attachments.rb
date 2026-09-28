# frozen_string_literal: true

require "digest/md5"

module Stationery
  module PDF
    # A file embedded in the document: its name, bytes, MIME type, an
    # optional description and how it relates to the document (the
    # /AFRelationship a Factur-X invoice or a PDF/A-3 attachment declares).
    Attachment = Data.define(:name, :data, :mime, :description, :relationship, :modified_at)

    # Builds and writes embedded files: each becomes a /Filespec with an
    # /EmbeddedFile stream, listed in the catalog's /Names /EmbeddedFiles
    # tree and its /AF array.
    module Attachments
      RELATIONSHIPS = { alternative: :Alternative, source: :Source, data: :Data, supplement: :Supplement,
                        unspecified: :Unspecified }.freeze

      module_function

      def build(name, data, mime: "application/octet-stream", description: nil, relationship: :unspecified,
                modified_at: nil)
        name = name.to_s
        raise ArgumentError, "an attachment needs a name" if name.empty?
        raise ArgumentError, "attachment #{name.inspect} needs its data as a String" unless data.is_a?(String)
        unless RELATIONSHIPS.key?(relationship)
          raise ArgumentError, "unknown attachment relationship #{relationship.inspect}; use one of " \
                               "#{RELATIONSHIPS.keys.map(&:inspect).join(", ")}"
        end

        Attachment.new(name:, data: data.b, mime: mime.to_s, description: description&.to_s, relationship:,
                       modified_at:)
      end

      # One list from class-level attachments and per-render hashes
      # (`{ name:, data:, mime:, … }`); the same name twice raises.
      def merge(*lists)
        lists.flatten.compact.map { |item| item.is_a?(Attachment) ? item : from_hash(item) }.tap do |all|
          duplicate = all.map(&:name).tally.find { |_, count| count > 1 }&.first
          raise ArgumentError, "attachment #{duplicate.inspect} is given twice" if duplicate
        end
      end

      def from_hash(hash)
        hash = hash.to_h.transform_keys(&:to_sym)
        build(hash[:name], hash[:data], **hash.except(:name, :data))
      end

      # The catalog entries for the files, written through `writer`; empty without any.
      def write(writer, attachments)
        return {} if attachments.nil? || attachments.empty?

        refs = attachments.sort_by(&:name).map do |attachment|
          [attachment.name, writer.add(filespec(writer, attachment))]
        end
        { Names: { EmbeddedFiles: { Names: refs.flatten } }, AF: refs.map(&:last) }
      end

      def filespec(writer, attachment)
        spec = { Type: :Filespec, F: attachment.name.b, UF: TextString.new(attachment.name),
                 AFRelationship: RELATIONSHIPS.fetch(attachment.relationship),
                 EF: { F: writer.add(stream(attachment)) } }
        spec[:Desc] = TextString.new(attachment.description) if attachment.description
        spec
      end

      def stream(attachment)
        params = { Size: attachment.data.bytesize, CheckSum: HexString.new(Digest::MD5.digest(attachment.data)) }
        if attachment.modified_at
          params[:ModDate] = TextString.new(attachment.modified_at.utc.strftime("D:%Y%m%d%H%M%SZ"))
        end
        Stream.new(attachment.data, Type: :EmbeddedFile, Subtype: attachment.mime.to_sym, Params: params)
      end
    end
  end
end
