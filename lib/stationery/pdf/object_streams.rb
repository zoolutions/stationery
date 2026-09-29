# frozen_string_literal: true

module Stationery
  module PDF
    # The two stream objects of a compressed file (ISO 32000-1, 7.5.7 and
    # 7.5.8): an object stream holding objects that are not streams, and the
    # cross-reference stream that replaces the table and the trailer.
    module ObjectStreams
      # Objects in one object stream: a few hundred deflate to a tenth of
      # their size, and a reader inflates the whole stream to reach one.
      CAPACITY = 200
      # Bytes of an entry's type, offset or object stream number, and
      # generation or index.
      WIDTHS = [1, 4, 2].freeze
      FREE = [0, 0, 0xFFFF].freeze

      module_function

      # The object stream of `batch`, [number, value] pairs, its values
      # written without encryption: the stream is encrypted whole.
      def pack(batch)
        header = String.new(encoding: Encoding::BINARY)
        body = String.new(encoding: Encoding::BINARY)
        batch.each do |number, value|
          header << "#{number} #{body.bytesize} "
          body << Serializer.dump(value) << "\n"
        end
        Stream.new(header + body, { Type: :ObjStm, N: batch.size, First: header.bytesize })
      end

      # The cross-reference stream of `locations`, one per object from 1: an
      # Integer offset in the file, or [object stream, index] for a packed
      # object. `trailer` is what the trailer dictionary would hold.
      def xref(locations, trailer)
        fields = FREE.dup
        locations.each { |at| at.is_a?(Integer) ? fields.push(1, at, 0) : fields.push(2, at[0], at[1]) }
        Stream.new(fields.pack("CNn" * (fields.size / 3)), trailer.merge(Type: :XRef, W: WIDTHS))
      end
    end
  end
end
