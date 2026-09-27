# frozen_string_literal: true

require "digest/md5"

module Stationery
  module PDF
    # Collects numbered objects and writes them as a PDF file with a classic
    # cross-reference table.
    class Writer
      HEADER = "%PDF-1.7\n%\xE2\xE3\xCF\xD3\n".b

      # `encryption` (an Encryption::StandardSecurity) encrypts every string
      # and stream except those of its own /Encrypt dictionary.
      def initialize(encryption: nil)
        @objects = []
        @encryption = encryption
      end

      # Hands out a reference now and lets the object be set later, so a page
      # can point at its parent before the page tree exists.
      def reserve
        @objects << nil
        Reference.new(@objects.size)
      end

      def set(ref, value)
        @objects[ref.id - 1] = value
        ref
      end

      def add(value)
        set(reserve, value)
      end

      def render(root:, info:)
        if (missing = @objects.index(nil))
          raise Error, "object #{missing + 1} reserved but never set"
        end

        @encrypt = @encryption && add(@encryption.dictionary)
        out = HEADER.dup
        offsets = @objects.each_with_index.map { |object, index| write_object(out, index + 1, object) }
        xref = out.bytesize
        id = HexString.new(@encryption ? @encryption.file_id : Digest::MD5.digest(out))

        out << "xref\n0 #{@objects.size + 1}\n0000000000 65535 f \n"
        offsets.each { |offset| out << format("%010d 00000 n \n", offset) }
        out << "trailer\n" << Serializer.dump(trailer(root, info, id))
        out << "\nstartxref\n#{xref}\n%%EOF\n"
      end

      private

      def trailer(root, info, id)
        trailer = { Size: @objects.size + 1, Root: root, Info: info, ID: [id, id] }
        @encrypt ? trailer.merge(Encrypt: @encrypt) : trailer
      end

      def write_object(out, number, object)
        offset = out.bytesize
        crypt = crypt_for(number)
        out << "#{number} 0 obj\n"
        if object.is_a?(Stream)
          data = crypt ? crypt.call(object.data) : object.data
          out << Serializer.dump(object.dictionary.merge(Length: data.bytesize), crypt)
          out << "\nstream\n" << data << "\nendstream"
        else
          out << Serializer.dump(object, crypt)
        end
        out << "\nendobj\n"
        offset
      end

      # The Serializer hook: encrypts a string or stream with this object's key.
      def crypt_for(number)
        return unless @encrypt && number != @encrypt.id

        ->(bytes) { @encryption.encrypt(bytes, number) }
      end
    end
  end
end
