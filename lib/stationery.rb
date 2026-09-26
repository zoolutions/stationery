# frozen_string_literal: true

require_relative "stationery/version"
require_relative "stationery/errors"
require_relative "stationery/pdf/types"
require_relative "stationery/pdf/serializer"
require_relative "stationery/pdf/stream"
require_relative "stationery/pdf/writer"
require_relative "stationery/fonts/true_type"
require_relative "stationery/fonts/cmap"
require_relative "stationery/fonts/name_table"
require_relative "stationery/fonts/subset"
require_relative "stationery/fonts/registry"
require_relative "stationery/fonts/font"
require_relative "stationery/fonts/family"
require_relative "stationery/images/images"
require_relative "stationery/images/cache"
require_relative "stationery/images/scanlines"
require_relative "stationery/images/jpeg"
require_relative "stationery/images/png"

# Pure-Ruby PDF documents built from Phlex-style components.
module Stationery
end
