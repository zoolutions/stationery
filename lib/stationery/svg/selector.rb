# frozen_string_literal: true

module Stationery
  module SVG
    # A compound CSS selector: an element name or `*`, then any number of
    # `.class` and `#id` parts. Combinators, pseudo-classes and attribute
    # selectors are not read.
    class Selector
      PATTERN = /\A(\*|[a-zA-Z][\w-]*)?((?:[.#][\w-]+)*)\z/

      def self.parse(text)
        match = text.match(PATTERN)
        return nil if match.nil? || text.empty?

        parts = match[2].scan(/[.#][\w-]+/)
        new(match[1], parts.grep(/\A#/).map { |id| id[1..] }, parts.grep(/\A\./).map { |name| name[1..] })
      end

      def initialize(name, ids, classes)
        @name = name == "*" ? nil : name
        @ids = ids
        @classes = classes
      end

      # [ids, classes, element names], compared in that order.
      def specificity = [@ids.size, @classes.size, @name ? 1 : 0]

      def match?(element)
        attributes = element.attributes
        return false if @name && @name != element.name
        return false unless @ids.all?(attributes["id"])

        (@classes - attributes["class"].to_s.split).empty?
      end
    end
  end
end
