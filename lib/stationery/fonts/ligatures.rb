# frozen_string_literal: true

module Stationery
  module Fonts
    # Chooses where a font's glyph substitutions come from. Every source
    # answers `substitute(gids, feature_tags)` with [[gid, source glyph
    # count], ...] and `features` with the tags it can apply.
    module Ligatures
      # For fonts without a usable GSUB table: every glyph stands for itself.
      module NONE
        def self.substitute(gids, _tags = Gsub::LIGA) = gids.map { |gid| [gid, 1] }
        def self.features = []
      end

      def self.for(ttf) = Gsub.parse(ttf) || NONE
    end
  end
end
