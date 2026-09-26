# frozen_string_literal: true

module Stationery
  class Error < StandardError; end

  # A font file stationery cannot read or embed (CFF, collections, WOFF, …).
  class UnsupportedFont < Error; end

  # An image format stationery cannot embed (WebP, GIF, interlaced PNG, …).
  class UnsupportedImage < Error; end
end
