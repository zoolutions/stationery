# frozen_string_literal: true

require "zlib"

module Stationery
  module PDF
    # A stream object. Data is Flate-compressed unless the dictionary already
    # names a filter (JPEG's DCTDecode, or PNG data that is already zlib) or
    # `compress: false` asks for it plain (XMP metadata, which PDF/A readers
    # scan for without decoding).
    class Stream
      attr_reader :dictionary, :data

      def initialize(data, dictionary = {}, compress: !dictionary.key?(:Filter))
        data = data.b
        dictionary = dictionary.dup

        if compress
          data = Zlib::Deflate.deflate(data)
          dictionary[:Filter] = :FlateDecode
        end

        dictionary[:Length] = data.bytesize
        @data = data
        @dictionary = dictionary
      end
    end
  end
end
