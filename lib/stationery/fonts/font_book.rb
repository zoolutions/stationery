# frozen_string_literal: true

module Stationery
  module Fonts
    # A document's font families and the Font objects it has drawn with. Each
    # document gets its own book so glyph usage (and so subsetting) is per
    # document, while the parsed TrueType data is shared through the Registry.
    class FontBook
      attr_reader :families, :warnings

      def initialize(families = {}, warnings: Warnings.new)
        @families = families.dup
        @warnings = warnings
        @fonts = {}
      end

      def inspect = "#<#{self.class} families=#{@families.keys.inspect}>"

      def register(name, **paths)
        @families[name.to_s] = Family.build(name, **paths)
      end

      # Returns [Font, Family::Face] for a Text::Style.
      def resolve(style)
        face = family(style.family).face(weight: style.weight, style: style.style)
        [@fonts[face.path] ||= Font.new(Registry.load(face.path)), face]
      end

      private

      # Registered by name, bundled by name, then the first registered family,
      # then the bundled default.
      def family(name)
        @families[name.to_s] || bundled(name) || @families.values.first || bundled(Bundled::DEFAULT)
      end

      def bundled(name)
        @bundled ||= {}
        @bundled[name.to_s] ||= Bundled.family(name)
      end
    end
  end
end
