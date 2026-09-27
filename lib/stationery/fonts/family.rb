# frozen_string_literal: true

module Stationery
  module Fonts
    # A named set of up to four TrueType files. A style without its own file is
    # drawn from the nearest one with synthetic bold (stroked outlines) and/or
    # synthetic oblique (sheared text matrix).
    class Family
      STYLES = %i[regular bold italic bold_italic].freeze

      Face = Data.define(:path, :synthetic_bold, :synthetic_oblique)

      attr_reader :name, :paths

      # A family from explicit files, or a bundled one when no files are given.
      def self.build(name, **paths)
        return new(name, **paths) if paths.any?

        Bundled.family(name) ||
          raise(ArgumentError, "font family #{name} needs a regular face (bundled: #{Bundled.names.join(", ")})")
      end

      def initialize(name, **paths)
        unknown = paths.keys - STYLES
        raise ArgumentError, "unknown font style #{unknown.join(", ")} (use #{STYLES.join(", ")})" if unknown.any?
        raise ArgumentError, "font family #{name} needs a regular face" unless paths[:regular]

        @name = name.to_s
        @paths = paths.transform_values(&:to_s).freeze
      end

      def face(weight: :regular, style: :normal)
        bold = bold?(weight)
        italic = style.to_sym == :italic
        candidates(bold, italic).each do |key, synthetic_bold, synthetic_oblique|
          return Face.new(@paths[key], synthetic_bold, synthetic_oblique) if @paths[key]
        end
      end

      private

      def bold?(weight)
        weight.is_a?(Numeric) ? weight >= 600 : %i[bold semibold].include?(weight.to_sym)
      end

      def candidates(bold, italic)
        if bold && italic
          [[:bold_italic, false, false], [:bold, false, true], [:italic, true, false], [:regular, true, true]]
        elsif bold
          [[:bold, false, false], [:regular, true, false]]
        elsif italic
          [[:italic, false, false], [:regular, false, true]]
        else
          [[:regular, false, false]]
        end
      end
    end
  end
end
