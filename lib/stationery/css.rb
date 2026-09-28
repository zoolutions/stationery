# frozen_string_literal: true

require_relative "css/selector"
require_relative "css/stylesheet"

module Stationery
  # The CSS the svg and html elements read: `<style>` rules with element,
  # class and id selectors, and inline `style` declarations.
  module CSS
    module_function

    # `"a: 1; b : 2"` → `{ "a" => "1", "b" => "2" }`; names lowercased.
    def declarations(style)
      style.to_s.split(";").filter_map do |declaration|
        key, value = declaration.split(":", 2)&.map(&:strip)
        [key.downcase, value] if key && value && !key.empty?
      end.to_h
    end
  end
end
