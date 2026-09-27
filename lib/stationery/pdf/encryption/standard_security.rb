# frozen_string_literal: true

require "openssl"

module Stationery
  module PDF
    module Encryption
      # The standard security handler: passwords, permissions and the
      # /Encrypt dictionary, plus the per-object encryption the writer applies
      # to every string and stream.
      #
      #   StandardSecurity.new(owner_password: "s3cret", permissions: %i[print copy])
      class StandardSecurity
        PERMISSIONS = { print: 3, modify: 4, copy: 5, annotate: 6, fill_forms: 9, extract_accessible: 10,
                        assemble: 11, print_high: 12 }.freeze
        ALGORITHMS = {
          aes_256: { V: 5, R: 6, Length: 256, CFM: :AESV3, key: 32 },
          aes_128: { V: 4, R: 4, Length: 128, CFM: :AESV2, key: 16 },
          rc4_128: { V: 2, R: 3, Length: 128 }
        }.freeze

        # Checks and normalizes the options without deriving any keys.
        def self.options(owner_password:, user_password: "", permissions: PERMISSIONS.keys, algorithm: :aes_256)
          raise ArgumentError, "encryption needs an owner_password" if owner_password.to_s.empty?

          permissions = Array(permissions).map(&:to_sym)
          unknown = permissions - PERMISSIONS.keys
          raise ArgumentError, "unknown permission #{unknown.first.inspect}" if unknown.any?
          raise ArgumentError, "unknown algorithm #{algorithm.inspect}" unless ALGORITHMS.key?(algorithm)

          { owner_password: owner_password.to_s, user_password: user_password.to_s, permissions:, algorithm: }
        end

        # The signed 32-bit /P value: granted bits set, bits 1-2 clear, the rest set.
        def self.permission_bits(permissions)
          masks = PERMISSIONS.transform_values { |bit| 1 << (bit - 1) }
          bits = 0xFFFFFFFC & ~masks.values.sum
          bits |= permissions.sum { |name| masks.fetch(name) }
          [bits].pack("L").unpack1("l")
        end

        attr_reader :file_id

        def initialize(**)
          options = self.class.options(**)
          @algorithm = ALGORITHMS.fetch(options[:algorithm])
          @permissions = self.class.permission_bits(options[:permissions])
          @file_id = OpenSSL::Random.random_bytes(16)
          @handler = handler(options[:user_password], options[:owner_password], options[:algorithm])
        end

        def dictionary
          { Filter: :Standard, **@algorithm.slice(:V, :R, :Length), P: @permissions, **@handler.entries,
            **crypt_filters }
        end

        def encrypt(data, number, generation = 0) = @handler.encrypt(data, number, generation)

        private

        def handler(user, owner, algorithm)
          if algorithm == :aes_256
            Revision6.new(user:, owner:, permissions: @permissions)
          else
            Revision4.new(user:, owner:, permissions: @permissions, file_id: @file_id, aes: algorithm == :aes_128)
          end
        end

        def crypt_filters
          return {} unless @algorithm[:CFM]

          filter = { CFM: @algorithm[:CFM], AuthEvent: :DocOpen, Length: @algorithm[:key] }
          { CF: { StdCF: filter }, StmF: :StdCF, StrF: :StdCF }
        end
      end
    end
  end
end
