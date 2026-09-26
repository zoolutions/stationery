# frozen_string_literal: true

require "digest/md5"

module Stationery
  module Images
    # Process-wide cache of decoded images keyed by content digest, so a logo
    # drawn on every invoice is parsed once. Decoded images are immutable after
    # construction apart from memoized derived data, which is deterministic.
    module Cache
      SIZE = 16
      @cache = {}
      @mutex = Mutex.new

      class << self
        def fetch(data)
          key = Digest::MD5.digest(data)
          @mutex.synchronize do
            image = @cache.delete(key) || yield
            @cache[key] = image
            @cache.shift while @cache.size > SIZE
            image
          end
        end

        def clear
          @mutex.synchronize { @cache.clear }
        end
      end
    end
  end
end
