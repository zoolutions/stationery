# frozen_string_literal: true

require_relative "tokenizer"
require_relative "tree_builder"

module Stationery
  # Lenient HTML to rich-text blocks (see Stationery::Rich).
  module HTML
    def self.parse(source)
      Stationery.instrument("parse.stationery", format: :html, bytes: source.bytesize) do
        TreeBuilder.parse(Tokenizer.tokenize(source))
      end
    end
  end
end
