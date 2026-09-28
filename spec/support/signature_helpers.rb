# frozen_string_literal: true

require "openssl"
require "open3"
require "tempfile"

# Throwaway signing identities: a key and a certificate for it, made once per
# kind for the whole run (an RSA key takes a moment to generate).
module SignatureHelpers
  Identity = Data.define(:certificate, :key)

  IDENTITIES = {} # rubocop:disable Style/MutableConstant
  LOCK = Mutex.new

  def self.identity(kind)
    LOCK.synchronize do
      IDENTITIES[kind] ||= begin
        key = kind == :ec ? OpenSSL::PKey::EC.generate("prime256v1") : OpenSSL::PKey::RSA.new(2048)
        Identity.new(certificate(key, "Test Signer #{kind}"), key)
      end
    end
  end

  # A certificate for `key`, self-signed unless `issuer:` (an Identity) signs it.
  def self.certificate(key, name, issuer: nil)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = OpenSSL::BN.rand(64)
    certificate.subject = OpenSSL::X509::Name.parse("/C=SE/O=Stationery/CN=#{name}")
    certificate.issuer = issuer ? issuer.certificate.subject : certificate.subject
    certificate.public_key = key
    certificate.not_before = Time.now - 60
    certificate.not_after = Time.now + 3600
    certificate.sign(issuer ? issuer.key : key, "SHA256")
    certificate
  end

  def signer(kind = :rsa) = SignatureHelpers.identity(kind)

  # The signature's CMS (DER, without its zero padding), the bytes it signs
  # and the /ByteRange they were read from the file by.
  def signed_parts(pdf)
    range = pdf[%r{/ByteRange \[([\d ]+)\]}, 1].split.map(&:to_i)
    contents = pdf.byteslice(range[1], range[2] - range[1])
    cms = Stationery::PDF::Signature.der([contents[1..-2]].pack("H*"))
    [cms, pdf.byteslice(range[0], range[1]) + pdf.byteslice(range[2], range[3]), range]
  end

  # What `openssl cms -verify` says about the signature, or nil without openssl.
  def openssl_verdict(pdf)
    return unless system("which openssl > /dev/null 2>&1")

    cms, content, = signed_parts(pdf)
    Tempfile.create(["sig", ".der"], binmode: true) do |signature|
      Tempfile.create(["signed", ".bin"], binmode: true) do |data|
        signature.write(cms) && signature.flush
        data.write(content) && data.flush
        output, = Open3.capture2e("openssl", "cms", "-verify", "-inform", "DER", "-in", signature.path, "-content",
                                  data.path, "-binary", "-noverify", "-out", File::NULL)
        output.strip
      end
    end
  end
end

RSpec.configure { |config| config.include SignatureHelpers }
