# frozen_string_literal: true

require_relative "../rich/nesting"
require_relative "tokenizer"
require_relative "tree_builder"

module Stationery
  # Lenient HTML to rich-text blocks (see Stationery::Rich).
  module HTML
    # Elements nested deeper than `max_depth` are flattened into the deepest
    # one kept; the block is then given how deep the source went.
    def self.parse(source, max_depth: Rich::Nesting::DEFAULT)
      nesting = Rich::Nesting.new(max_depth)
      Stationery.instrument("parse.stationery", format: :html, bytes: source.bytesize) do
        TreeBuilder.parse(Tokenizer.tokenize(source), nesting).tap do
          yield nesting.deepest if nesting.exceeded? && block_given?
        end
      end
    end
  end
end
