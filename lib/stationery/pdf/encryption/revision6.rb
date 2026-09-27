# frozen_string_literal: true

require "digest/sha2"
require "openssl"

module Stationery
  module PDF
    module Encryption
      # Security handler revision 6 (ISO 32000-2, AES-256): a random file key
      # wrapped once per password, with salted SHA-2 hashes that run through
      # the hash iteration of algorithm 2.B. Every object uses the file key.
      class Revision6
        DIGESTS = [Digest::SHA256, Digest::SHA384, Digest::SHA512].freeze

        def initialize(user:, owner:, permissions:)
          @key = random(32)
          user = password(user)
          owner = password(owner)
          validation = random(8)
          key_salt = random(8)
          @user_key = hash(user, validation) + validation + key_salt
          @user_wrapped = AES.raw(hash(user, key_salt), @key)
          validation = random(8)
          key_salt = random(8)
          @owner_key = hash(owner, validation, @user_key) + validation + key_salt
          @owner_wrapped = AES.raw(hash(owner, key_salt, @user_key), @key)
          @perms = AES.raw(@key, "#{[permissions, 0xFFFFFFFF].pack("l<V")}Tadb#{random(4)}", mode: "ECB")
        end

        def entries
          { O: @owner_key, U: @user_key, OE: @owner_wrapped, UE: @user_wrapped, Perms: @perms }
            .transform_values { |bytes| HexString.new(bytes) }
        end

        def encrypt(data, _number, _generation) = AES.encrypt(@key, data)

        private

        def random(size) = OpenSSL::Random.random_bytes(size)

        def password(value) = value.encode(Encoding::UTF_8).b.byteslice(0, 127)

        def hash(password, salt, user_key = "".b)
          key = Digest::SHA256.digest(password + salt + user_key)
          round = 0
          loop do
            block = AES.raw(key.byteslice(0, 16), (password + key + user_key) * 64, iv: key.byteslice(16, 16))
            key = DIGESTS[block.byteslice(0, 16).bytes.sum % 3].digest(block)
            round += 1
            return key.byteslice(0, 32) if round >= 64 && block.getbyte(-1) <= round - 32
          end
        end
      end
    end
  end
end
