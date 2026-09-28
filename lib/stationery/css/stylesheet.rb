# frozen_string_literal: true

module Stationery
  module CSS
    # The rules of a document's <style> elements. An element's declarations
    # are those of every matching rule, the more specific winning and the
    # later winning among equals. At-rules are skipped (`@import`, `@font-face`,
    # `@page`, `@media screen`), except that the rules inside `@media print`
    # and `@media all` are read; `!important` is read as a plain declaration;
    # rules whose selectors use combinators are ignored and listed in
    # #unsupported.
    class Stylesheet
      Rule = Data.define(:selector, :declarations, :index)

      RULE = /([^{}]+)\{([^{}]*)\}/
      COMMENT = %r{/\*.*?\*/}m
      STATEMENT = /@[\w-]+[^;{}]*;/
      AT_BLOCK = /@([\w-]+)([^{};]*)\{((?:[^{}]*\{[^{}]*\})*[^{}]*)\}/
      PRINTED = /\b(print|all)\b/i

      def self.parse(css)
        rules = []
        unsupported = []
        plain(css).scan(RULE).each do |selectors, body|
          next if selectors.strip.start_with?("@")

          declarations = CSS.declarations(body).transform_values { |value| value.sub(/\s*!important\z/, "") }
          selectors.split(",").map(&:strip).each do |text|
            selector = Selector.parse(text)
            selector ? rules << Rule.new(selector, declarations, rules.size) : unsupported << text
          end
        end
        new(rules, unsupported)
      end

      # The rules outside at-rules, plus those a print medium would read.
      def self.plain(css)
        css.gsub(COMMENT, "").gsub(STATEMENT, "").gsub(AT_BLOCK) do
          Regexp.last_match(1).casecmp?("media") && Regexp.last_match(2).match?(PRINTED) ? Regexp.last_match(3) : ""
        end
      end

      attr_reader :unsupported

      def initialize(rules, unsupported)
        @rules = rules
        @unsupported = unsupported
      end

      EMPTY = new([], []).freeze

      def empty? = @rules.empty?

      def declarations(element)
        rules_for(element).reduce({}) { |merged, rule| merged.merge(rule.declarations) }
      end

      # The declarations of every rule that matches, the one that wins last.
      def matching(element) = rules_for(element).map(&:declarations)

      private

      def rules_for(element)
        @rules.select { |rule| rule.selector.match?(element) }
              .sort_by { |rule| [rule.selector.specificity, rule.index] }
      end
    end
  end
end
