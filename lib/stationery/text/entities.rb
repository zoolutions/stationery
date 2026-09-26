# frozen_string_literal: true

module Stationery
  module Text
    # Decodes the HTML entities markup text may carry.
    module Entities
      NAMED = { "amp" => "&", "lt" => "<", "gt" => ">", "quot" => "\"", "apos" => "'", "nbsp" => " " }.freeze
      PATTERN = /&(#x\h+|#\d+|[a-zA-Z]+);/

      module_function

      def decode(text)
        text.gsub(PATTERN) do |entity|
          name = Regexp.last_match(1)
          if name.start_with?("#x") then [name[2..].to_i(16)].pack("U")
          elsif name.start_with?("#") then [name[1..].to_i].pack("U")
          else NAMED.fetch(name, entity)
          end
        end
      end
    end
  end
end
