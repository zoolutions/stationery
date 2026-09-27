# frozen_string_literal: true

module Stationery
  module PDF
    module Encryption
      # RC4 in Ruby: OpenSSL 3 builds drop it from the default provider.
      module RC4
        module_function

        def crypt(key, data)
          state = schedule(key.b.bytes)
          i = j = 0
          data.b.bytes.map do |byte|
            i = (i + 1) & 0xFF
            j = (j + state[i]) & 0xFF
            state[i], state[j] = state[j], state[i]
            byte ^ state[(state[i] + state[j]) & 0xFF]
          end.pack("C*")
        end

        def schedule(key)
          state = (0..255).to_a
          j = 0
          256.times do |i|
            j = (j + state[i] + key[i % key.size]) & 0xFF
            state[i], state[j] = state[j], state[i]
          end
          state
        end
      end
    end
  end
end
