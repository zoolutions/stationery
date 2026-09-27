# frozen_string_literal: true

module Stationery
  module Rich
    class Renderer
      # Which hrefs become link annotations: `#anchor` always, otherwise only
      # the allowed URL schemes (case-insensitive). A dropped href keeps its
      # text and is reported once as a DroppedLink warning. `:all` keeps every
      # href, for trusted sources.
      class Links
        SCHEME = /\A([a-z][a-z0-9+.-]*):/i

        def initialize(schemes, warnings)
          @schemes = schemes == :all ? :all : Array(schemes).map { |scheme| scheme.to_s.downcase }
          @warnings = warnings
        end

        def allowed?(href)
          return true if @schemes == :all || href.start_with?("#")
          return true if @schemes.include?(href[SCHEME, 1].to_s.downcase)

          @warnings << Warnings::DroppedLink.new(href:)
          false
        end
      end
    end
  end
end
