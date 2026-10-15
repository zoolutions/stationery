# frozen_string_literal: true

module Stationery
  # Where the gem's caches live: one value per key and per Ractor, shared by
  # that Ractor's threads, built by the block the first time it is asked for.
  #
  #   Stationery::Store.fetch(:stationery_fonts) { LRU.new(16) }
  #
  # A cache in a constant or a class instance variable cannot be read from a
  # non-main Ractor, so each Ractor keeps its own here and a cache's lock
  # lives inside it (see LRU and Memo). On Ruby 3.4+ this is
  # `Ractor.store_if_absent`, atomic and per Ractor. An engine without it
  # (JRuby, TruffleRuby: no Ractor at all) has one Hash behind a Mutex,
  # both made at load. conformance-kit's ConformanceKit::Store is the same
  # pattern; the gem cannot depend on the kit when it runs.
  module Store
    # A Hash whose every read and write holds one Mutex: the store of an
    # engine without Ractor.store_if_absent.
    class Locked
      def initialize
        @lock = Mutex.new
        @values = {}
      end

      def fetch(key)
        @lock.synchronize { @values.fetch(key) { @values[key] = yield } }
      end
    end

    def self.native? = defined?(::Ractor) ? ::Ractor.respond_to?(:store_if_absent) : false

    if native?
      def self.fetch(key, &) = ::Ractor.store_if_absent(key, &)
    else
      # Only where there is no Ractor to read it from: made once, at load.
      @locked = Locked.new

      # rubocop:disable-next ThreadSafety/ClassInstanceVariable -- written once at load; Locked holds its own Mutex
      def self.fetch(key, &) = @locked.fetch(key, &)
    end
  end
end
