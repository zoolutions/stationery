# frozen_string_literal: true

require "zlib"

module Stationery
  module PDF
    # A stream object. Data is Flate-compressed unless the dictionary already
    # names a filter (JPEG's DCTDecode, or PNG data that is already zlib).
    class Stream
      attr_reader :dictionary, :data

      def initialize(data, dictionary = {})
        data = data.b
        dictionary = dictionary.dup

        unless dictionary.key?(:Filter)
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
