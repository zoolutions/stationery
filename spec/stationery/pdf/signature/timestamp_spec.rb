# frozen_string_literal: true

RSpec.describe Stationery::PDF::Signature::Timestamp do
  let(:signature) { "signature value".b }
  let(:digest) { OpenSSL::Digest::SHA256.digest(signature) }

  describe ".for" do
    it "takes a URL, a Hash of options, or nothing" do
      expect(described_class.for(nil)).to be_nil
      expect(described_class.for("https://tsa.example/tsr").url).to eq("https://tsa.example/tsr")
      timestamp = described_class.for({ "url" => "https://tsa.example/tsr", hash: "sha384" })
      expect(timestamp.url).to eq("https://tsa.example/tsr")
      expect(timestamp.hash).to eq(:sha384)
    end

    it "refuses unknown options, a missing URL and an unknown hash" do
      expect { described_class.for({ url: "https://tsa.example", tsa: "x" }) }
        .to raise_error(ArgumentError, /unknown timestamp option: tsa \(use url, username, password, hash, client\)/)
      expect { described_class.for({ username: "u" }) }.to raise_error(ArgumentError, /needs the TSA's url:/)
      expect { described_class.for({ url: "https://tsa.example", hash: :md5 }) }
        .to raise_error(ArgumentError, /hash: is sha256, sha384, sha512, got :md5/)
    end
  end

  describe "#token" do
    it "asks the TSA for a token over the signature's digest, with a nonce and the certificate, and answers it" do
      tsa = TimestampHelpers::FakeTSA.new(at: Time.utc(2026, 9, 28, 12, 0, 0))

      token = described_class.for({ client: tsa }).token(signature)

      request = tsa.requests.first
      expect(request.message_imprint).to eq(digest)
      expect(request.algorithm).to eq("SHA256")
      expect(request.nonce).to be_a(OpenSSL::BN)
      expect(request).to be_cert_requested
      wrapped = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Integer.new(0)]),
                                             OpenSSL::ASN1.decode(token)])
      response = OpenSSL::Timestamp::Response.new(wrapped.to_der)
      expect(response.token_info.gen_time).to eq(Time.utc(2026, 9, 28, 12, 0, 0))
      expect(response.token_info.message_imprint).to eq(digest)
      expect(response.token.certificates.map { it.subject.to_utf8 }).to eq(["CN=Test TSA,O=Stationery,C=SE"])
    end

    it "hashes with sha384 or sha512 when asked" do
      tsa = TimestampHelpers::FakeTSA.new

      described_class.for({ client: tsa, hash: :sha512 }).token(signature)

      expect(tsa.requests.first.algorithm).to eq("SHA512")
      expect(tsa.requests.first.message_imprint).to eq(OpenSSL::Digest::SHA512.digest(signature))
    end

    it "raises when the TSA refuses, answers another request, timestamps something else or talks nonsense" do
      expect { described_class.for({ client: TimestampHelpers::FakeTSA.new(tamper: :status) }).token(signature) }
        .to raise_error(Stationery::SignatureError, /the TSA refused the timestamp \(status 2: not today/)
      expect { described_class.for({ client: TimestampHelpers::FakeTSA.new(tamper: :nonce) }).token(signature) }
        .to raise_error(Stationery::SignatureError, /answered another request \(nonce differs\)/)
      expect { described_class.for({ client: TimestampHelpers::FakeTSA.new(tamper: :imprint) }).token(signature) }
        .to raise_error(Stationery::SignatureError, /timestamped something else \(message imprint differs\)/)
      expect { described_class.for({ client: TimestampHelpers::FakeTSA.new(tamper: :garbage) }).token(signature) }
        .to raise_error(Stationery::SignatureError, /did not answer with a timestamp response/)
    end

    it "posts the request over HTTP as RFC 3161 asks, with basic auth when given" do
      with_tsa_server do |url, seen|
        token = described_class.for({ url:, username: "acme", password: "s3cret" }).token(signature)

        expect(OpenSSL::ASN1.decode(token)).to be_a(OpenSSL::ASN1::Sequence)
        request = seen.first
        expect(request[:line]).to start_with("POST /tsr HTTP/1.1")
        expect(request[:headers]).to include("content-type" => "application/timestamp-query",
                                             "accept" => "application/timestamp-reply",
                                             "authorization" => "Basic #{["acme:s3cret"].pack("m0")}")
        expect(OpenSSL::Timestamp::Request.new(request[:body]).message_imprint).to eq(digest)
      end
    end

    it "raises when the TSA cannot be reached or answers an error" do
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      server.close

      expect { described_class.for("http://127.0.0.1:#{port}/tsr").token(signature) }
        .to raise_error(Stationery::SignatureError, %r{timestamp: http://127.0.0.1:#{port}/tsr could not be reached})
    end
  end
end
