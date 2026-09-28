# frozen_string_literal: true

module Stationery
  module Rich
    # How deep one html or markdown source may nest, and how deep it went.
    # Parsing, layout and painting all recurse over the nesting, so a parser
    # flattens what lies deeper than `limit` into the deepest element it kept
    # (text stays, structure goes) and records the depth it saw here.
    class Nesting
      DEFAULT = 64

      attr_reader :limit, :deepest

      def initialize(limit = DEFAULT)
        unless limit.is_a?(Integer) && limit.positive?
          raise ArgumentError, "max_depth must be a positive Integer (got #{limit.inspect})"
        end

        @limit = limit
        @deepest = 0
      end

      def record(depth)
        @deepest = depth if depth > @deepest
      end

      def exceeded? = @deepest > @limit
    end
  end
end
