# frozen_string_literal: true

require_relative "tokenizer"
require_relative "tree_builder"

module Stationery
  # Lenient HTML to rich-text blocks (see Stationery::Rich).
  module HTML
    def self.parse(source) = TreeBuilder.parse(Tokenizer.tokenize(source))
  end
end
