# frozen_string_literal: true

module Stationery
  # A reusable piece of a document, with Phlex's lifecycle:
  #
  #   class Callout < Stationery::Component
  #     def initialize(color:) = @color = color
  #     def view_template(&) = box(background: @color, padding: 12, radius: 6, &)
  #   end
  #
  #   render Callout.new(color: "#F3F4F6") { text "Amount due" }
  class Component
    include Elements

    def call(builder, &)
      @_builder = builder
      around_template do
        before_template
        view_template(&)
        after_template
      end
      nil
    end

    def around_template = yield
    def before_template = nil
    def after_template = nil
    def view_template(&) = yield_content(&)

    def render(renderable, &)
      case renderable
      when Component then renderable.call(@_builder, &)
      when Class then renderable < Component ? render(renderable.new, &) : cannot_render(renderable)
      when String then text(renderable)
      when Proc, Method then yield_content(&renderable)
      when Enumerable then renderable.each { |item| render(item, &) }
      else cannot_render(renderable)
      end
      nil
    end

    def yield_content(&block)
      return unless block

      block.arity.zero? ? yield : yield(self)
    end

    private

    def cannot_render(renderable)
      raise ArgumentError, "You can't render #{renderable.inspect}; render a component, class, string, proc or list."
    end
  end
end
