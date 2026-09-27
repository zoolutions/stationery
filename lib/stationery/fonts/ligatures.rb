# frozen_string_literal: true

module Stationery
  module Fonts
    # Chooses where a font's ligatures come from. Every source answers
    # `substitute(gids)` with [[gid, source glyph count], ...].
    module Ligatures
      # For fonts without ligatures: every glyph stands for itself.
      module NONE
        def self.substitute(gids) = gids.map { |gid| [gid, 1] }
      end

      def self.for(ttf) = Gsub.parse(ttf) || NONE
    end
  end
end
