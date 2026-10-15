# frozen_string_literal: true

require "digest/md5"

module Stationery
  module Images
    # The decoded images of one Ractor (see Store), the SIZE most recently
    # used, keyed by content digest, so a logo drawn on every invoice is
    # parsed once. Decoded images are immutable after construction apart
    # from memoized derived data, which each image guards with its own lock.
    module Cache
      SIZE = 16

      class << self
        def fetch(data)
          lru.fetch(Digest::MD5.digest(data)) { |held| held || yield }
        end

        def clear = lru.clear

        private

        def lru = Store.fetch(:stationery_images) { LRU.new(SIZE) }
      end
    end
  end
end
