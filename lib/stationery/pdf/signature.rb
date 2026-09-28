# frozen_string_literal: true

module Stationery
  module PDF
    # A digital signature over the whole file, as PAdES baseline B-B asks for
    # it: a signature dictionary with `/SubFilter /ETSI.CAdES.detached` whose
    # /Contents is a detached CMS over every byte but itself (see CMS).
    #
    # The file is written once with room for the signature (`contents_size:`
    # bytes) and a placeholder /ByteRange; #apply then fills both in place, so
    # no offset moves. Timestamps (PAdES-T), long-term validation data and a
    # second signature need incremental updates, which Stationery does not
    # write.
    #
    # OpenSSL is loaded when the first signature is made, never before.
    class Signature
      SUBFILTER = :"ETSI.CAdES.detached"
      CONTENTS_SIZE = 8192
      BYTE_RANGE = "[0 0000000000 0000000000 0000000000]"
      OPTIONS = %i[certificate key chain passphrase reason location contact name field at contents_size].freeze
      # Options a Symbol names a document method for; elsewhere it is a value.
      SECRETS = %i[certificate key chain passphrase].freeze
      # Print and Locked: the widget of a signature that fills no field.
      INVISIBLE = 132

      attr_reader :certificate, :key, :chain, :field, :at, :contents_size

      class << self
        # The signature for `spec` (the options of `sign` and `to_pdf(sign:)`,
        # or a block answering them) resolved for `document`; nil without one.
        def for(spec, document)
          return unless spec

          spec = resolve(spec, document) if spec.respond_to?(:call)
          spec = check(spec).to_h { |name, value| [name, resolve(value, document, method: SECRETS.include?(name))] }
          new(**spec)
        end

        # The options with Symbol keys; an unknown one raises.
        def check(spec)
          spec = spec.to_h.transform_keys(&:to_sym)
          unknown = spec.keys - OPTIONS
          return spec if unknown.empty?

          raise ArgumentError, "unknown sign option: #{unknown.join(", ")} (use #{OPTIONS.join(", ")})"
        end

        # Whether any of the options is only known when a document renders.
        def deferred?(spec)
          spec.any? { |name, value| value.respond_to?(:call) || (SECRETS.include?(name) && value.is_a?(Symbol)) }
        end

        # The first DER object in `bytes`: a signature's /Contents without the
        # zeros that pad it.
        def der(bytes)
          length = bytes.getbyte(1).to_i
          return bytes.byteslice(0, 2 + length) if length < 0x80

          size = length & 0x7F
          content = bytes.byteslice(2, size).unpack("C*").inject(0) { |sum, byte| (sum << 8) | byte }
          bytes.byteslice(0, 2 + size + content)
        end

        private

        def resolve(value, document, method: false)
          case value
          when Symbol then method ? document.send(value) : value
          when Proc then value.arity.zero? ? document.instance_exec(&value) : value.call(document)
          else value.respond_to?(:call) ? value.call(document) : value
          end
        end
      end

      def initialize(certificate: nil, key: nil, chain: [], passphrase: nil, field: nil, at: Time.now,
                     contents_size: CONTENTS_SIZE, **details)
        require "openssl"
        @certificate = certificate_for(certificate, "certificate:")
        @key = key_for(key, passphrase)
        @chain = Array(chain).map { |link| certificate_for(link, "chain:") }
        @field = field&.to_s
        @at = at
        @contents_size = contents_size
        @details = self.class.check(details)
        match!
      end

      # Whether it adds its own field, a widget nobody sees, to the first page.
      def invisible? = @field.nil?

      # The signer's name: `name:`, else the certificate's common name.
      def name
        @details[:name] || @certificate.subject.to_utf8[/(?:\A|,)CN=((?:\\.|[^,])*)/, 1]&.gsub(/\\(.)/, '\1')
      end

      # The signature dictionary, with placeholders #apply fills in. Its
      # /Contents and /ByteRange are written as they are, never encrypted.
      def dictionary
        entries = { Type: :Sig, Filter: :"Adobe.PPKLite", SubFilter: SUBFILTER,
                    ByteRange: Verbatim.new(BYTE_RANGE), Contents: Verbatim.new(placeholder),
                    M: TextString.new(@at.utc.strftime("D:%Y%m%d%H%M%SZ")) }
        text = { Name: name, Reason: @details[:reason], Location: @details[:location],
                 ContactInfo: @details[:contact] }.compact
        entries.merge(text.transform_values { |value| TextString.new(value.to_s) })
      end

      # Signs `pdf` (the file as written with #dictionary in it): fills in the
      # byte range and the signature over it, and answers the same String.
      def apply(pdf)
        range, first, last = gap(pdf)
        pdf.bytesplice(range, BYTE_RANGE.bytesize,
                       "[0 #{first} #{last} #{pdf.bytesize - last}]".ljust(BYTE_RANGE.bytesize))
        signature = CMS.new(@certificate, @key, @chain).sign(pdf.byteslice(0, first) + pdf.byteslice(last..))
        raise ArgumentError, too_large(signature) if signature.bytesize > @contents_size

        pdf.bytesplice(first + 1, @contents_size * 2, signature.unpack1("H*").upcase.ljust(@contents_size * 2, "0"))
        pdf
      end

      private

      def placeholder = "<#{"0" * (@contents_size * 2)}>"

      # Where the byte range is written, and where the /Contents string
      # starts and ends: the gap the signature does not cover.
      def gap(pdf)
        range = pdf.index("/ByteRange #{BYTE_RANGE}")
        contents = range && pdf.index("/Contents #{placeholder}", range)
        raise Error, "the signature dictionary is not in the file" unless contents

        first = contents + "/Contents ".bytesize
        [range + "/ByteRange ".bytesize, first, first + placeholder.bytesize]
      end

      def too_large(signature)
        "the signature takes #{signature.bytesize} bytes, more than contents_size: #{@contents_size} leaves for it; " \
          "pass a larger contents_size:"
      end

      def certificate_for(value, option)
        return value if value.is_a?(OpenSSL::X509::Certificate)

        OpenSSL::X509::Certificate.new(value.to_s)
      rescue OpenSSL::X509::CertificateError
        raise ArgumentError, "sign #{option} needs an OpenSSL::X509::Certificate or its PEM, #{got(value)}"
      end

      def key_for(value, passphrase)
        key = value.is_a?(OpenSSL::PKey::PKey) ? value : OpenSSL::PKey.read(value.to_s, passphrase.to_s)
        return key if key.is_a?(OpenSSL::PKey::RSA) || key.is_a?(OpenSSL::PKey::EC)

        raise ArgumentError, "sign key: needs an RSA or EC key, got #{key.class}"
      rescue OpenSSL::PKey::PKeyError
        raise ArgumentError, "sign key: needs an OpenSSL::PKey or its PEM (with passphrase: when encrypted), " \
                             "#{got(value)}"
      end

      def got(value) = value.nil? ? "got nil" : "got a #{value.class}"

      def match!
        return if @key.private? && @certificate.check_private_key(@key)

        raise ArgumentError, "sign key: is not the private key of certificate: (#{@certificate.subject.to_utf8})"
      end
    end
  end
end
