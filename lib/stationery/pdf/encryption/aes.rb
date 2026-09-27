# frozen_string_literal: true

require "openssl"

module Stationery
  module PDF
    module Encryption
      # AES as PDF uses it: object data is CBC with a random IV in front and
      # PKCS#5 padding; key material (UE, OE, Perms) is unpadded.
      module AES
        ZERO_IV = ("\0" * 16).b

        module_function

        def encrypt(key, data)
          iv = OpenSSL::Random.random_bytes(16)
          iv + run(cipher(key, "CBC", iv), data)
        end

        def raw(key, data, iv: ZERO_IV, mode: "CBC")
          aes = cipher(key, mode, mode == "ECB" ? nil : iv)
          aes.padding = 0
          run(aes, data)
        end

        def cipher(key, mode, iv)
          aes = OpenSSL::Cipher.new("AES-#{key.bytesize * 8}-#{mode}").encrypt
          aes.key = key
          aes.iv = iv if iv
          aes
        end

        def run(aes, data) = aes.update(data.b) + aes.final
      end
    end
  end
end
