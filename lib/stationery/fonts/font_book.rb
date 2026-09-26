# frozen_string_literal: true

module Stationery
  module Fonts
    # A document's font families and the Font objects it has drawn with. Each
    # document gets its own book so glyph usage (and so subsetting) is per
    # document, while the parsed TrueType data is shared through the Registry.
    class FontBook
      attr_reader :families

      def initialize(families = {})
        @families = families.dup
        @fonts = {}
      end

      def inspect = "#<#{self.class} families=#{@families.keys.inspect}>"

      def register(name, **paths)
        @families[name.to_s] = Family.new(name, **paths)
      end

      # Returns [Font, Family::Face] for a Text::Style.
      def resolve(style)
        face = family(style.family).face(weight: style.weight, style: style.style)
        [@fonts[face.path] ||= Font.new(Registry.load(face.path)), face]
      end

      private

      def family(name)
        @families[name.to_s] || @families.values.first ||
          raise(Error, "no font registered; declare one with `font_family \"Name\", regular: \"path/to/font.ttf\"`")
      end
    end
  end
end
