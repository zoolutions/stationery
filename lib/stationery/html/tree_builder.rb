# frozen_string_literal: true

require_relative "tree_builder/blocks"

module Stationery
  module HTML
    # Builds a lenient element tree from tokens, closing what HTML5 closes implicitly (a p before a block,
    # an li before the next li, cells and rows before the next), ignoring stray end tags, then converts
    # the tree into rich-text blocks.
    class TreeBuilder
      Element = Data.define(:name, :attributes, :children)

      CLOSES_P = %w[
        address article aside blockquote dd details div dl dt fieldset figcaption figure footer form
        h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section table ul
      ].freeze
      HEADINGS = %w[h1 h2 h3 h4 h5 h6].freeze
      SECTIONS = %w[thead tbody tfoot].freeze
      IMPLIED = {
        "li" => [%w[li], %w[ul ol]],
        "dt" => [%w[dt dd], %w[dl]], "dd" => [%w[dt dd], %w[dl]],
        "td" => [%w[td th], %w[tr table]], "th" => [%w[td th], %w[tr table]],
        "tr" => [%w[tr], %w[table]],
        "thead" => [SECTIONS, %w[table]], "tbody" => [SECTIONS, %w[table]], "tfoot" => [SECTIONS, %w[table]]
      }.freeze

      def self.parse(tokens) = Blocks.convert(new.build(tokens))

      def initialize
        @root = Element.new("#root", {}, [])
        @stack = [@root]
      end

      def build(tokens)
        tokens.each do |type, *args|
          case type
          when :start then start(*args)
          when :end then finish(*args)
          else @stack.last.children << args.first
          end
        end
        @root
      end

      private

      def start(name, attributes, self_closing)
        close_nearest(%w[p], %w[table td th caption]) if CLOSES_P.include?(name)
        close_nearest(HEADINGS, []) if HEADINGS.include?(name) && HEADINGS.include?(@stack.last.name)
        close_nearest(*IMPLIED[name]) if IMPLIED.key?(name)
        push("tr", {}, false) if %w[td th].include?(name) && %w[table thead tbody tfoot].include?(@stack.last.name)
        push(name, attributes, self_closing)
      end

      def push(name, attributes, self_closing)
        element = Element.new(name, attributes, [])
        @stack.last.children << element
        @stack << element unless self_closing
      end

      def finish(name)
        index = @stack.rindex { |element| element.name == name }
        @stack.slice!(index..) if index&.positive?
      end

      def close_nearest(names, boundary)
        index = @stack.rindex { |element| names.include?(element.name) || boundary.include?(element.name) }
        @stack.slice!(index..) if index&.positive? && names.include?(@stack[index].name)
      end
    end
  end
end
