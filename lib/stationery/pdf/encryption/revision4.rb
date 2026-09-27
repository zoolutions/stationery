# frozen_string_literal: true

require "digest/md5"

module Stationery
  module PDF
    module Encryption
      # The MD5 key derivation of security handler revisions 3 and 4
      # (ISO 32000-1 algorithms 1-5) with a 128-bit key. Each object is
      # encrypted with its own key: RC4 for R3, AES-128 (AESV2) for R4.
      class Revision4
        PADDING = ["28BF4E5E4E758A4164004E56FFFA01082E2E00B6D0683E802F0CA9FE6453697A"].pack("H*").freeze

        def initialize(user:, owner:, permissions:, file_id:, aes:)
          @aes = aes
          user = pad(user)
          @owner_key = rounds(stretch(Digest::MD5.digest(pad(owner))), user)
          @key = stretch(Digest::MD5.digest(user + @owner_key + [permissions].pack("l<") + file_id))
          @user_key = rounds(@key, Digest::MD5.digest(PADDING + file_id)) + PADDING.byteslice(0, 16)
        end

        def entries = { O: HexString.new(@owner_key), U: HexString.new(@user_key) }

        def encrypt(data, number, generation)
          key = object_key(number, generation)
          @aes ? AES.encrypt(key, data) : RC4.crypt(key, data)
        end

        private

        def pad(password) = (password.b + PADDING).byteslice(0, 32)

        def stretch(digest) = 50.times.reduce(digest) { |previous, _| Digest::MD5.digest(previous) }

        def rounds(key, data)
          20.times.reduce(data) { |previous, round| RC4.crypt(xor(key, round), previous) }
        end

        def xor(key, value) = key.bytes.map { |byte| byte ^ value }.pack("C*")

        def object_key(number, generation)
          seed = @key + [number].pack("V").byteslice(0, 3) + [generation].pack("v")
          Digest::MD5.digest(@aes ? "#{seed}sAlT" : seed)
        end
      end
    end
  end
end
