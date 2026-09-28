# frozen_string_literal: true

module Stationery
  module PDF
    class Signature
      # The signature value: a detached CMS SignedData (RFC 5652) over the
      # signed bytes, as CAdES and PAdES baseline ask for it. The signed
      # attributes are the content type, the SHA-256 message digest and the
      # ESS signing-certificate-v2 (RFC 5035) that binds the signature to the
      # signer's certificate; there is no signing-time attribute, a PDF keeps
      # that in the signature dictionary's /M.
      #
      # A timestamp token over the signature value (see Timestamp) goes into
      # the unsigned attributes, which makes the signature PAdES baseline B-T.
      #
      # Ruby's OpenSSL::PKCS7 cannot add signed attributes, so the structure
      # is built with OpenSSL::ASN1. RSA keys sign with PKCS #1 v1.5, EC keys
      # with ECDSA, both over SHA-256.
      class CMS
        OIDS = {
          data: "1.2.840.113549.1.7.1", signed_data: "1.2.840.113549.1.7.2",
          content_type: "1.2.840.113549.1.9.3", message_digest: "1.2.840.113549.1.9.4",
          signing_certificate_v2: "1.2.840.113549.1.9.16.2.47", sha256: "2.16.840.1.101.3.4.2.1",
          signature_timestamp_token: "1.2.840.113549.1.9.16.2.14",
          rsa: "1.2.840.113549.1.1.1", ecdsa_sha256: "1.2.840.10045.4.3.2"
        }.freeze

        # `chain` are the certificates between the signer's and its root.
        def initialize(certificate, key, chain = [])
          @certificate = certificate
          @key = key
          @chain = chain
        end

        # The DER of the SignedData signing `data`. `timestamp:` is a callable
        # given the signature value and answering a timestamp token (DER).
        def sign(data, timestamp: nil)
          attributes = attributes(OpenSSL::Digest::SHA256.digest(data))
          signature = @key.sign("SHA256", asn1::Set.new(attributes).to_der)
          unsigned = timestamp && [attribute(:signature_timestamp_token, asn1.decode(timestamp.call(signature)))]
          content = asn1::Sequence.new([
                                         asn1::Integer.new(1),
                                         asn1::Set.new([algorithm(:sha256)]),
                                         asn1::Sequence.new([oid(:data)]),
                                         implicit(certificates),
                                         asn1::Set.new([signer(attributes, signature, unsigned)])
                                       ])
          asn1::Sequence.new([oid(:signed_data), asn1::ASN1Data.new([content], 0, :CONTEXT_SPECIFIC)]).to_der
        end

        private

        def asn1 = OpenSSL::ASN1
        def oid(name) = asn1::ObjectId.new(OIDS.fetch(name))
        def implicit(items, tag = 0) = asn1::Set.new(items, tag, :IMPLICIT, :CONTEXT_SPECIFIC)
        def certificates = [@certificate, *@chain].map { |certificate| asn1.decode(certificate.to_der) }

        # RSA and the digests carry an explicit NULL parameter, ECDSA none.
        def algorithm(name, null: true) = asn1::Sequence.new(null ? [oid(name), asn1::Null.new(nil)] : [oid(name)])

        def attribute(name, value) = asn1::Sequence.new([oid(name), asn1::Set.new([value])])

        # DER orders the members of a SET OF by their encoding.
        def attributes(digest)
          [
            attribute(:content_type, oid(:data)),
            attribute(:message_digest, asn1::OctetString.new(digest)),
            attribute(:signing_certificate_v2, signing_certificate)
          ].sort_by(&:to_der)
        end

        # SigningCertificateV2 with one ESSCertIDv2: the certificate's SHA-256
        # (the default hash algorithm, so it is left out).
        def signing_certificate
          hash = asn1::OctetString.new(OpenSSL::Digest::SHA256.digest(@certificate.to_der))
          asn1::Sequence.new([asn1::Sequence.new([asn1::Sequence.new([hash])])])
        end

        def signer(attributes, signature, unsigned)
          issuer = asn1.decode(@certificate.issuer.to_der)
          info = [
            asn1::Integer.new(1),
            asn1::Sequence.new([issuer, asn1::Integer.new(@certificate.serial)]),
            algorithm(:sha256),
            implicit(attributes),
            @key.is_a?(OpenSSL::PKey::EC) ? algorithm(:ecdsa_sha256, null: false) : algorithm(:rsa),
            asn1::OctetString.new(signature)
          ]
          info << implicit(unsigned, 1) if unsigned
          asn1::Sequence.new(info)
        end
      end
    end
  end
end
