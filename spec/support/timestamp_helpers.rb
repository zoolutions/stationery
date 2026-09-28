# frozen_string_literal: true

require "openssl"
require "socket"

# A throwaway RFC 3161 time-stamping authority for specs: a certificate with
# the timestamping purpose and a factory that answers requests the way a real
# TSA would (OpenSSL::Timestamp::Factory), as a `client:` callable or behind a
# small HTTP server on localhost.
module TimestampHelpers
  TSA = Data.define(:certificate, :key)
  LOCK = Mutex.new

  def self.tsa
    LOCK.synchronize do
      @tsa ||= begin
        key = OpenSSL::PKey::RSA.new(2048)
        certificate = OpenSSL::X509::Certificate.new
        certificate.version = 2
        certificate.serial = OpenSSL::BN.rand(64)
        certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse("/C=SE/O=Stationery/CN=Test TSA")
        certificate.public_key = key
        certificate.not_before = Time.now - 60
        certificate.not_after = Time.now + 3600
        factory = OpenSSL::X509::ExtensionFactory.new(certificate, certificate)
        certificate.add_extension(factory.create_extension("extendedKeyUsage", "timeStamping", true))
        certificate.sign(key, "SHA256")
        TSA.new(certificate, key)
      end
    end
  end

  # Answers a TimeStampReq DER with a TimeStampResp DER. `tamper:` makes the
  # answer wrong in one way: :status (refused), :nonce, :imprint or :garbage.
  class FakeTSA
    attr_reader :requests

    def initialize(tamper: nil, at: Time.now)
      @tamper = tamper
      @at = at
      @requests = []
    end

    def call(der)
      request = OpenSSL::Timestamp::Request.new(der)
      @requests << request
      return "not a response".b if @tamper == :garbage
      return refusal.to_der if @tamper == :status

      request.nonce = request.nonce + 1 if @tamper == :nonce
      request.message_imprint = OpenSSL::Digest.digest("SHA256", "other") if @tamper == :imprint
      factory = OpenSSL::Timestamp::Factory.new
      factory.gen_time = @at
      factory.serial_number = @requests.size
      factory.default_policy_id = "1.2.3.4.5"
      factory.allowed_digests = %w[sha256 sha384 sha512]
      factory.create_timestamp(TimestampHelpers.tsa.key, TimestampHelpers.tsa.certificate, request).to_der
    end

    private

    # PKIStatusInfo status 2 (rejection), failInfo badRequest (bit 2).
    def refusal
      asn1 = OpenSSL::ASN1
      text = asn1::Sequence.new([asn1::UTF8String.new("not today")])
      status = asn1::Sequence.new([asn1::Integer.new(2), text, asn1::BitString.new("\x20".b)])
      asn1::Sequence.new([status])
    end
  end

  # A minimal HTTP server on localhost handing every POST body to `tsa`,
  # for the built-in HTTP client. Yields its URL, then closes.
  def with_tsa_server(tsa = FakeTSA.new)
    server = TCPServer.new("127.0.0.1", 0)
    seen = []
    thread = Thread.new do
      loop do
        socket = server.accept
        request = read_request(socket)
        seen << request
        body = tsa.call(request[:body])
        socket.write("HTTP/1.1 200 OK\r\nContent-Type: application/timestamp-reply\r\n" \
                     "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n")
        socket.write(body)
        socket.close
      end
    rescue IOError, Errno::EBADF
      nil
    end
    yield "http://127.0.0.1:#{server.addr[1]}/tsr", seen
  ensure
    server&.close
    thread&.kill
  end

  def read_request(socket)
    line = socket.gets
    headers = {}
    while (header = socket.gets) && header != "\r\n"
      name, value = header.split(":", 2)
      headers[name.downcase] = value.strip
    end
    { line: line, headers: headers, body: socket.read(headers["content-length"].to_i) }
  end

  # The timestamp token (an ASN1 ContentInfo) carried by the signature's CMS, or nil.
  def timestamp_token(cms)
    info = OpenSSL::ASN1.decode(cms).value[1].value[0].value[4].value[0].value
    unsigned = info[6..].to_a.find { |item| item.tag == 1 }
    attribute = unsigned&.value&.find { |one| one.value[0].oid == "1.2.840.113549.1.9.16.2.14" }
    attribute && attribute.value[1].value.first
  end
end

RSpec.configure { |config| config.include TimestampHelpers }
