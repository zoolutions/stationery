# frozen_string_literal: true

require_relative "../../rich/nodes"
require_relative "../whitespace"

module Stationery
  module HTML
    class TreeBuilder
      # Gathers the blocks of one container: loose inline content between blocks becomes a paragraph,
      # with its whitespace collapsed the way a browser would.
      class Collector
        def initialize
          @blocks = []
          @pending = []
        end

        def text(string, marks) = @pending << Rich::Inline.new(text: string, marks:)

        def inline(item)
          @pending << item if item
        end

        def block(block)
          return unless block

          flush
          @blocks << block
        end

        def boundary
          flush
          yield
          flush
        end

        def blocks
          flush
          @blocks
        end

        private

        def flush
          @blocks.concat(Rich::Inlines.paragraphs(@pending) { |run| Whitespace.collapse(run) })
          @pending = []
        end
      end
    end
  end
end
