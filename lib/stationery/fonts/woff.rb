# frozen_string_literal: true

require "zlib"

module Stationery
  module Fonts
    # Unwraps a WOFF 1.0 web font into the sfnt it was made from: each table is
    # inflated (or copied when stored) and laid out behind a fresh table
    # directory, 4-byte aligned in directory order. Metadata and private data
    # blocks are dropped.
    module WOFF
      SIGNATURE = "wOFF"
      HEADER = 44
      ENTRY = 20

      module_function

      def unpack(data)
        data = data.b
        flavor = data.byteslice(4, 4)
        tables = Array.new(data.byteslice(12, 2).unpack1("n")) do |i|
          tag, offset, compressed, length, checksum = data.byteslice(HEADER + (i * ENTRY), ENTRY).unpack("a4NNNN")
          [tag, checksum, table(tag, data.byteslice(offset, compressed), length)]
        end
        assemble(flavor, tables)
      end

      def table(tag, bytes, length)
        return bytes if bytes.bytesize >= length

        Zlib::Inflate.inflate(bytes)
      rescue Zlib::Error
        raise UnsupportedFont, "corrupt WOFF table #{tag}"
      end

      def assemble(flavor, tables)
        entry_selector = Math.log2(tables.size).floor
        search_range = (2**entry_selector) * 16
        directory = [flavor, tables.size, search_range, entry_selector, (tables.size * 16) - search_range]
                    .pack("a4nnnn")
        body = String.new(encoding: Encoding::BINARY)
        offset = 12 + (tables.size * 16)

        tables.each do |tag, checksum, bytes|
          directory << [tag, checksum, offset + body.bytesize, bytes.bytesize].pack("a4NNN")
          body << bytes << ("\0".b * (-bytes.bytesize % 4))
        end
        directory << body
      end
    end
  end
end
