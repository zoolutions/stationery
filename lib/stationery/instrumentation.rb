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

    # Frozen, so a render in any Ractor can use it.
    NULL = Null.new.freeze

    # None set: the default below is asked for on every read and never
    # written, so a non-main Ractor can read it.
    @instrumenter = nil

    class << self
      # Any object answering `instrument(name, payload) { |payload| }`; nil
      # gives the default back. A render inside a non-main Ractor can reach
      # only a shareable one: a module (ActiveSupport::Notifications) or a
      # frozen object.
      # Set at boot, on the main Ractor, so a plain module attribute is enough.
      attr_writer :instrumenter # rubocop:disable ThreadSafety/ClassAndModuleAttributes

      # The one set, else ActiveSupport::Notifications when it is loaded,
      # else NULL.
      # rubocop:disable-next ThreadSafety/ClassInstanceVariable -- only read here; written at boot on the main Ractor
      def instrumenter = @instrumenter || default

      def default = defined?(::ActiveSupport::Notifications) ? ::ActiveSupport::Notifications : NULL

      # Keeps the instrumenter in use, so one loaded after boot is not picked
      # up (Stationery.finalize!).
      def finalize!
        # rubocop:disable-next ThreadSafety/ClassInstanceVariable -- written at boot on the main Ractor, before any render
        @instrumenter = instrumenter
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
