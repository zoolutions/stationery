# frozen_string_literal: true

module Stationery
  module PDF
    class Signature
      # A signature timestamp from an RFC 3161 time-stamping authority (TSA):
      # the TSA signs the digest of the signature value and the time it saw
      # it, and the token goes into the signature's unsigned attributes, which
      # makes it PAdES baseline B-T. A reader can then trust the signing time
      # even after the signer's certificate expires.
      #
      # `sign timestamp: "https://tsa.example/tsr"`, or a Hash with `url:`,
      # `username:`/`password:` for a TSA that wants HTTP basic auth, `hash:`
      # (:sha256, the default, :sha384 or :sha512) and `client:`, a callable
      # given the request DER and answering the response DER, in place of
      # the built-in HTTP client. Anything short of a token over exactly what
      # was asked raises SignatureError: a document is never quietly written
      # without the timestamp it was asked for.
      class Timestamp
        OPTIONS = %i[url username password hash client].freeze
        DIGESTS = { sha256: "SHA256", sha384: "SHA384", sha512: "SHA512" }.freeze
        # Status values a TSA answers with when it did grant the token
        # (granted, grantedWithMods).
        GRANTED = [0, 1].freeze
        REQUEST_TYPE = "application/timestamp-query"
        REPLY_TYPE = "application/timestamp-reply"

        attr_reader :url, :hash

        # The timestamp for `spec`: a URL String, a Hash of OPTIONS, or nil.
        def self.for(spec)
          return unless spec

          spec = { url: spec.to_s } unless spec.is_a?(Hash)
          spec = spec.transform_keys(&:to_sym)
          unknown = spec.keys - OPTIONS
          unless unknown.empty?
            raise ArgumentError, "unknown timestamp option: #{unknown.join(", ")} (use #{OPTIONS.join(", ")})"
          end

          new(**spec)
        end

        def initialize(url: nil, username: nil, password: nil, hash: :sha256, client: nil)
          raise ArgumentError, "sign timestamp: needs the TSA's url:" if url.to_s.empty? && client.nil?

          @url = url&.to_s
          @username = username
          @password = password
          @hash = hash.to_sym
          @client = client
          return if DIGESTS[@hash]

          raise ArgumentError,
                "timestamp hash: is #{DIGESTS.keys.join(", ")}, got #{hash.inspect}"
        end

        # The timestamp token (a ContentInfo, DER) the TSA issued over
        # `signature`, checked against what was asked.
        def token(signature)
          request = request_for(OpenSSL::Digest.digest(DIGESTS.fetch(@hash), signature))
          response = parse((@client || method(:post)).call(request.to_der))
          check!(response, request)
          response.token.to_der
        end

        private

        def request_for(digest)
          request = OpenSSL::Timestamp::Request.new
          request.algorithm = DIGESTS.fetch(@hash)
          request.message_imprint = digest
          request.nonce = OpenSSL::BN.rand(64)
          request.cert_requested = true
          request
        end

        def parse(der)
          OpenSSL::Timestamp::Response.new(der.to_s)
        rescue OpenSSL::Timestamp::TimestampError, TypeError => e
          raise SignatureError, "#{tsa} did not answer with a timestamp response: #{e.message}"
        end

        def check!(response, request)
          status = response.status.to_i
          unless GRANTED.include?(status) && response.token
            text = [*response.status_text, response.failure_info].compact.map(&:to_s).reject(&:empty?)
            raise SignatureError,
                  "#{tsa} refused the timestamp (status #{status}#{": #{text.join(", ")}" unless text.empty?})"
          end

          info = response.token_info
          raise SignatureError, "#{tsa} answered another request (nonce differs)" unless info.nonce == request.nonce
          return if info.message_imprint == request.message_imprint

          raise SignatureError, "#{tsa} timestamped something else (message imprint differs)"
        end

        def tsa = "timestamp: #{@url || "the TSA"}"

        # POSTs the request as RFC 3161 over HTTP asks for it.
        def post(body)
          require "net/http"
          uri = URI.parse(@url)
          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = REQUEST_TYPE
          request["Accept"] = REPLY_TYPE
          request.basic_auth(@username, @password.to_s) if @username
          request.body = body
          response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.request(request) }
          raise SignatureError, "#{tsa} answered HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

          response.body
        rescue SystemCallError, IOError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError => e
          raise SignatureError, "#{tsa} could not be reached: #{e.message}"
        end
      end
    end
  end
end
