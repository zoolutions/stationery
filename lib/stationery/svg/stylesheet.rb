# frozen_string_literal: true

module Stationery
  module SVG
    # The rules of a document's <style> elements. An element's declarations
    # are those of every matching rule, the more specific winning and the
    # later winning among equals. At-rules are skipped and `!important` is
    # read as a plain declaration; rules whose selectors use combinators are
    # ignored and listed in #unsupported.
    class Stylesheet
      Rule = Data.define(:selector, :declarations, :index)

      RULE = /([^{}]+)\{([^{}]*)\}/
      COMMENT = %r{/\*.*?\*/}m

      def self.parse(css)
        rules = []
        unsupported = []
        css.gsub(COMMENT, "").scan(RULE).each do |selectors, body|
          next if selectors.strip.start_with?("@")

          declarations = Style.declarations(body).transform_values { |value| value.sub(/\s*!important\z/, "") }
          selectors.split(",").map(&:strip).each do |text|
            selector = Selector.parse(text)
            selector ? rules << Rule.new(selector, declarations, rules.size) : unsupported << text
          end
        end
        new(rules, unsupported)
      end

      attr_reader :unsupported

      def initialize(rules, unsupported)
        @rules = rules
        @unsupported = unsupported
      end

      EMPTY = new([], []).freeze

      def declarations(element)
        @rules.select { |rule| rule.selector.match?(element) }
              .sort_by { |rule| [rule.selector.specificity, rule.index] }
              .reduce({}) { |merged, rule| merged.merge(rule.declarations) }
      end
    end
  end
end
