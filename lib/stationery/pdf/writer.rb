# frozen_string_literal: true

require "digest/md5"

module Stationery
  module PDF
    # Collects numbered objects and writes them as a PDF file with a classic
    # cross-reference table.
    class Writer
      HEADER = "%PDF-1.7\n%\xE2\xE3\xCF\xD3\n".b

      def initialize
        @objects = []
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

        out = HEADER.dup
        offsets = @objects.each_with_index.map { |object, index| write_object(out, index + 1, object) }
        xref = out.bytesize
        id = HexString.new(Digest::MD5.digest(out))

        out << "xref\n0 #{@objects.size + 1}\n0000000000 65535 f \n"
        offsets.each { |offset| out << format("%010d 00000 n \n", offset) }
        out << "trailer\n" << Serializer.dump({ Size: @objects.size + 1, Root: root, Info: info, ID: [id, id] })
        out << "\nstartxref\n#{xref}\n%%EOF\n"
      end

      private

      def write_object(out, number, object)
        offset = out.bytesize
        out << "#{number} 0 obj\n"
        if object.is_a?(Stream)
          out << Serializer.dump(object.dictionary) << "\nstream\n" << object.data << "\nendstream"
        else
          out << Serializer.dump(object)
        end
        out << "\nendobj\n"
        offset
      end
    end
  end
end
