# frozen_string_literal: true

module Stationery
  module Fonts
    # Chooses where a font's pair kerning comes from. Every source answers
    # `adjust(left_gid, right_gid)` with an extra advance in font units.
    module Kerning
      # For fonts without kerning data.
      module NONE
        def self.adjust(_left, _right) = 0
      end

      # A GPOS `kern` feature takes precedence over the legacy `kern` table.
      def self.for(ttf) = Gpos.parse(ttf) || KernTable.parse(ttf) || NONE
    end
  end
end
