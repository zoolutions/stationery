# frozen_string_literal: true

require "digest/md5"

module Stationery
  module PDF
    # Collects numbered objects and writes them as a PDF file with a classic
    # cross-reference table. `render` returns the file as a String with the
    # objects in numbered order. With a `sink:` (anything answering
    # `call(bytes)`) the file goes there in pieces instead: `flush` writes every
    # object set so far and drops it, so objects leave in the order they were
    # flushed and the first bytes leave before the last page is assembled.
    class Writer
      HEADER = "%PDF-1.7\n%\xE2\xE3\xCF\xD3\n".b
      WRITTEN = Object.new.freeze

      # `encryption` (an Encryption::StandardSecurity) encrypts every string
      # and stream except those of its own /Encrypt dictionary.
      def initialize(encryption: nil, sink: nil)
        @objects = []
        @offsets = []
        @encryption = encryption
        @sink = sink
        @buffer = HEADER.dup unless sink
        @size = HEADER.bytesize
        @digest = Digest::MD5.new if sink && !encryption
        announce(HEADER) if sink
      end

      # Hands out a reference now and lets the object be set later, so a page
      # can point at its parent before the page tree exists.
      def reserve
        @objects << nil
        Reference.new(@objects.size)
      end

      def set(ref, value)
        raise Error, "object #{ref.id} is already written" if @objects[ref.id - 1].equal?(WRITTEN)

        @objects[ref.id - 1] = value
        ref
      end

      def add(value)
        set(reserve, value)
      end

      # With a sink: writes every object set and not yet written, lowest number
      # first, and drops it. References to objects still unset stay valid, as
      # the cross-reference table is written last. Without a sink it does
      # nothing: the String keeps its objects in numbered order.
      def flush
        return unless @sink

        @encrypt ||= reserve if @encryption
        write_pending
      end

      # Finishes the file: the remaining objects, the cross-reference table
      # and the trailer. Returns the whole file as a String when there is no
      # sink, else the number of bytes handed to it.
      def render(root:, info:)
        set(@encrypt ||= reserve, @encryption.dictionary) if @encryption
        if (missing = @objects.index(nil))
          raise Error, "object #{missing + 1} reserved but never set"
        end

        write_pending
        xref = @size
        id = HexString.new(file_id)

        emit("xref\n0 #{@objects.size + 1}\n0000000000 65535 f \n")
        @offsets.each { |offset| emit(format("%010d 00000 n \n", offset)) }
        emit("trailer\n#{Serializer.dump(trailer(root, info, id))}")
        emit("\nstartxref\n#{xref}\n%%EOF\n")
        @buffer || @size
      end

      private

      def write_pending
        @objects.each_with_index do |object, index|
          next if object.nil? || object.equal?(WRITTEN)

          write_object(index + 1, object)
          @objects[index] = WRITTEN
        end
      end

      def trailer(root, info, id)
        trailer = { Size: @objects.size + 1, Root: root, Info: info, ID: [id, id] }
        @encrypt ? trailer.merge(Encrypt: @encrypt) : trailer
      end

      def write_object(number, object)
        @offsets[number - 1] = @size
        crypt = crypt_for(number)
        emit("#{number} 0 obj\n")
        if object.is_a?(Stream)
          data = crypt ? crypt.call(object.data) : object.data
          emit(Serializer.dump(object.dictionary.merge(Length: data.bytesize), crypt))
          emit("\nstream\n")
          emit(data)
          emit("\nendstream")
        else
          emit(Serializer.dump(object, crypt))
        end
        emit("\nendobj\n")
      end

      def emit(bytes)
        @size += bytes.bytesize
        @sink ? announce(bytes) : @buffer << bytes
      end

      def announce(bytes)
        @digest&.update(bytes)
        @sink.call(bytes)
      end

      # The encryption's own identifier, else a digest of the file so far.
      def file_id
        return @encryption.file_id if @encryption

        @digest ? @digest.digest : Digest::MD5.digest(@buffer)
      end

      # The Serializer hook: encrypts a string or stream with this object's key.
      def crypt_for(number)
        return unless @encrypt && number != @encrypt.id

        ->(bytes) { @encryption.encrypt(bytes, number) }
      end
    end
  end
end
