# frozen_string_literal: true

module Stationery
  module Text
    # Decodes the HTML character references markup text may carry: numeric
    # (`&#39;`, `&#x27;`, `&#X27;`) and named (the built-ins below, then the
    # HTML 4 table). Each reference is decoded once, so `&amp;#39;` yields the
    # literal text `&#39;`; an unknown name, a malformed reference or a code
    # point outside Unicode stays as written.
    module Entities
      NAMED = { "amp" => "&", "lt" => "<", "gt" => ">", "quot" => "\"", "apos" => "'", "nbsp" => " " }.freeze
      PATTERN = /&(#[xX]\h+|#\d+|[a-zA-Z]+);/
      MAX_CODE_POINT = 0x10FFFF
      SURROGATES = (0xD800..0xDFFF)

      module_function

      def decode(text)
        text.gsub(PATTERN) do |entity|
          name = Regexp.last_match(1)
          if name.start_with?("#x", "#X") then character(name[2..].to_i(16), entity)
          elsif name.start_with?("#") then character(name[1..].to_i, entity)
          else NAMED.fetch(name) { html4.fetch(name, entity) }
          end
        end
      end

      def character(code, entity)
        code.between?(1, MAX_CODE_POINT) && !SURROGATES.cover?(code) ? [code].pack("U") : entity
      end

      def html4
        require_relative "entities/html4" unless defined?(HTML4)
        HTML4
      end
    end
  end
end
