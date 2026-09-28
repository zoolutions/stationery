# frozen_string_literal: true

module Stationery
  # Events a render emits, named `<phase>.stationery` so tools that group by
  # the last segment (AppSignal, Skylight, Rails log subscribers) file them
  # together. With ActiveSupport::Notifications loaded they go there and
  # subscribers see the same payload the block filled in; otherwise a Null
  # instrumenter yields and costs one method call.
  module Instrumentation
    class Null
      def instrument(_name, payload = {})
        yield payload
      end
    end

    class << self
      # Any object answering `instrument(name, payload) { |payload| }`; set
      # once at boot, so a plain module attribute is enough.
      attr_writer :instrumenter # rubocop:disable ThreadSafety/ClassAndModuleAttributes

      def instrumenter
        @instrumenter ||= defined?(::ActiveSupport::Notifications) ? ::ActiveSupport::Notifications : Null.new # rubocop:disable ThreadSafety/ClassInstanceVariable
      end

      def instrument(name, payload = {}, &)
        instrumenter.instrument(name, payload, &)
      end
    end
  end

  class << self
    def instrumenter = Instrumentation.instrumenter

    def instrumenter=(value)
      Instrumentation.instrumenter = value
    end

    # Runs the block as one `name` event; the block may add to `payload`.
    def instrument(name, payload = {}, &) = Instrumentation.instrument(name, payload, &)
  end
end
