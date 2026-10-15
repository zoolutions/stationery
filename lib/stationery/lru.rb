# frozen_string_literal: true

module Stationery
  # The `size` most recently used entries of a cache, for the threads of one
  # Ractor (the image and font caches keep one per Ractor in Store). Every
  # read and write holds the cache's own Mutex, and so does building a
  # value, so a value is built once however many threads ask for it.
  class LRU
    def initialize(size)
      @size = size
      @entries = {}
      @lock = Mutex.new
    end

    # The value for `key`, made the most recently used: what the block
    # answers when given the value held for it (nil when there is none), so
    # a caller keeps a value or replaces a stale one. Past `size` entries
    # the least recently used goes. A block that raises stores nothing.
    def fetch(key)
      @lock.synchronize do
        value = yield @entries.delete(key)
        @entries[key] = value
        @entries.shift while @entries.size > @size
        value
      end
    end

    def size = @lock.synchronize { @entries.size }
    def clear = @lock.synchronize { @entries.clear }
  end
end
