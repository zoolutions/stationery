# frozen_string_literal: true

module Stationery
  # Collects the nodes a component tree describes. Holds the container stack
  # (where the next node goes) and the text defaults in effect.
  class Builder
    STYLE_KEYS = %i[size color weight style letter_spacing underline strikethrough link opacity kerning
                    ligatures features hyphenate].freeze

    # Collects a row's columns; anything that is not already a column box is
    # wrapped in one.
    class Columns
      attr_reader :nodes

      def initialize = @nodes = []

      def <<(node)
        @nodes << (node.is_a?(Layout::Box) ? node : Layout::Box.new(Layout::Flow.new([node])))
        self
      end
    end

    # Collects a list's items: every node added becomes one item.
    class Items
      attr_reader :nodes

      def initialize = @nodes = []

      def <<(node)
        @nodes << node
        self
      end
    end

    # `images` are the document's bitmap defaults (max_ppi:, downscale:).
    attr_reader :root, :book, :list_depth, :images

    # `tagged:` is whether the render writes a structure tree; without one
    # the nodes built here carry no Tagging::Element.
    def initialize(book:, text: {}, images: {}, tagged: true)
      @book = book
      @images = images
      @tagged = tagged
      @root = Layout::Flow.new
      @containers = [@root]
      @text = [text]
      @list_depth = 0
    end

    def nested_list
      @list_depth += 1
      yield
    ensure
      @list_depth -= 1
    end

    def add(node)
      @containers.last << node
      node
    end

    # Hands the finished root over and forgets it: the paginator is then the
    # only holder of the nodes, so those of a painted page can be collected.
    def release
      root = @root
      @root = nil
      @containers = []
      root
    end

    def within(container)
      @containers << container
      yield
      container
    ensure
      @containers.pop
    end

    # Whether nodes are being added straight into a stack's flow (where a
    # layer may go).
    def in_stack? = stacks.include?(@containers.last)

    def stack(flow, &)
      stacks << flow
      within(flow, &)
    ensure
      stacks.delete(flow)
    end

    def with_text(**overrides)
      @text << text_defaults.merge(overrides.compact)
      yield
    ensure
      @text.pop
    end

    def text_defaults = @text.last
    def stacks = @stacks ||= []
    def outline = @outline ||= Outline.new
    def warnings = @book.warnings

    def style(options = {})
      options = text_defaults.merge(options)
      family = options[:font] || @book.families.keys.first || Fonts::Bundled::DEFAULT
      Text::Style.new(family: family.to_s, **options.slice(*STYLE_KEYS))
    end

    def context(style = self.style) = Layout::Context.new(book: @book, style:, tagged: @tagged)

    def tagged? = @tagged

    # A structure element for a node, nil when the render writes no tree. An
    # element with attributes is built where it is asked for: forwarding
    # keywords would cost a Hash more than building it there.
    def element(type) = @tagged ? Tagging::Element.new(type) : nil
  end
end
