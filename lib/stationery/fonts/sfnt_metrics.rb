# frozen_string_literal: true

module Stationery
  module Fonts
    # The hhea, post and OS/2 metrics of an sfnt font, with fallbacks for the
    # optional tables. Included by TrueType.
    module SfntMetrics
      private

      def parse_hhea
        t = table_offset("hhea")
        @ascender = i16(t + 4)
        @descender = i16(t + 6)
        @line_gap = i16(t + 8)
        @number_of_hmetrics = u16(t + 34)
      end

      def parse_post
        if (t = table_offset("post"))
          @italic_angle = i16(t + 4) + (u16(t + 6) / 65_536.0)
          @underline_position = i16(t + 8)
          @underline_thickness = i16(t + 10)
          @fixed_pitch = u32(t + 12) != 0
        else
          @italic_angle = 0
          @underline_position = -@units_per_em / 10
          @underline_thickness = @units_per_em / 20
          @fixed_pitch = false
        end
      end

      def parse_os2
        if (t = table_offset("OS/2"))
          @weight = u16(t + 4)
          @strikeout_size = i16(t + 26)
          @strikeout_position = i16(t + 28)
          if u16(t) >= 2
            @x_height = i16(t + 86)
            @cap_height = i16(t + 88)
          end
        end

        @weight ||= 400
        @strikeout_size ||= @underline_thickness
        @strikeout_position ||= (@ascender * 0.25).round
        @x_height ||= (@ascender * 0.5).round
        @cap_height = (@ascender * 0.7).round if @cap_height.nil?
      end
    end
  end
end
