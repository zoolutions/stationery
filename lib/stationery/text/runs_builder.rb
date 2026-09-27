# frozen_string_literal: true

module Stationery
  module Text
    # Builds runs with Ruby instead of markup:
    #
    #   text { plain "Total "; b "due"; link("https://…") { i "pay" } }
    class RunsBuilder
      def self.build(style, &)
        new(style).tap { |builder| builder.capture(&) }.runs
      end

      def initialize(style)
        @styles = [style]
        @runs = []
      end

      def runs = Run.merge(@runs)

      # A block taking an argument is called with the builder (so it keeps its
      # own self and instance variables); one without is evaluated on it.
      # Once a block has taken the builder as an argument, nested blocks are
      # called as closures too, so `t.link(url) { t.color(tone, "go") }` can
      # still reach the caller's methods.
      def capture(&block)
        before = @runs.size
        result = if block.arity == 1 || @yielding
                   @yielding = true
                   block.arity.zero? ? yield : yield(self)
                 else
                   instance_exec(&block)
                 end
        plain(result) if result.is_a?(String) && @runs.size == before
      end

      def plain(text) = @runs << Run.new(text.to_s, @styles.last)
      def br = plain("\n")

      def b(text = nil, &) = styled({ weight: :bold }, text, &)
      def i(text = nil, &) = styled({ style: :italic }, text, &)
      def u(text = nil, &) = styled({ underline: true }, text, &)
      def strikethrough(text = nil, &) = styled({ strikethrough: true }, text, &)
      def sub(text = nil, &) = styled({ script: :sub }, text, &)
      def sup(text = nil, &) = styled({ script: :sup }, text, &)
      def color(value, text = nil, &) = styled({ color: value }, text, &)
      def size(value, text = nil, &) = styled({ size: value }, text, &)
      def font(family, text = nil, &) = styled({ family: family.to_s }, text, &)
      def link(url, text = nil, &) = styled({ link: url.to_s }, text, &)

      private

      def styled(overrides, text, &)
        @styles << @styles.last.with(**overrides)
        text ? plain(text) : capture(&)
      ensure
        @styles.pop
      end
    end
  end
end
