# frozen_string_literal: true

module Stationery
  # Values built once per key, for the threads of one Ractor (the parsed
  # colours and the hyphenation patterns keep one per Ractor in Store).
  # Every read and write holds the memo's own Mutex, and so does building a
  # value. With `limit:` the memo starts over once it holds that many.
  class Memo
    def initialize(limit: nil)
      @limit = limit
      @values = {}
      @lock = Mutex.new
    end

    # The value for `key`, built by the block the first time. A block that
    # raises stores nothing. A Hash keeps a frozen copy of a String key, so
    # a String changed after it was used does not change what is held.
    def fetch(key)
      @lock.synchronize do
        @values.fetch(key) do
          @values.clear if @limit && @values.size >= @limit
          @values[key] = yield
        end
      end
    end

    def key?(key) = @lock.synchronize { @values.key?(key) }
    def size = @lock.synchronize { @values.size }
    def clear = @lock.synchronize { @values.clear }
  end
end
