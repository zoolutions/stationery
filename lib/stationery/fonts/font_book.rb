# frozen_string_literal: true

module Stationery
  module Fonts
    # A document's font families and the Font objects it has drawn with. Each
    # document gets its own book so glyph usage (and so subsetting) is per
    # document, while the parsed TrueType data is shared through the Registry.
    class FontBook
      attr_reader :families, :fallbacks, :warnings

      # `fallbacks:` names the families tried, in order, for a character the
      # run's own family has no glyph for.
      def initialize(families = {}, fallbacks: [], warnings: Warnings.new)
        @families = families.dup
        @fallbacks = fallbacks.map(&:to_s).freeze
        @warnings = warnings
        @fonts = {}
        @resolved = {}
        @split = {}.compare_by_identity
      end

      def inspect = "#<#{self.class} families=#{@families.keys.inspect}>"

      def register(name, **paths)
        @resolved.clear
        @families[name.to_s] = Family.build(name, **paths)
      end

      # Returns [Font, Family::Face] for a Text::Style, memoised per style.
      def resolve(style)
        @resolved[style] ||= begin
          face = family(style.family).face(weight: style.weight, style: style.style)
          [@fonts[face.path] ||= Font.new(Registry.load(face.path)), face].freeze
        end
      end

      # The runs split so every character is drawn by a font that has it. Runs
      # this book already split come back as they are.
      def fallback(runs)
        return runs if @split.key?(runs)

        (@fallback ||= Fallback.new(self)).apply(runs).tap { |split| @split[split] = true }
      end

      private

      # Registered by name, bundled by name, an installed pack by name, then
      # the first registered family, then the bundled default.
      def family(name)
        @families[name.to_s] || bundled(name) || pack(name) || substitute(name)
      end

      # An unknown name draws with the first registered family, else bundled
      # Inter, and says so once.
      def substitute(name)
        used = @families.values.first || bundled(Bundled::DEFAULT)
        @warnings << Warnings::UnknownFamily.new(requested: name.to_s, used: used.name)
        used
      end

      def bundled(name)
        @bundled ||= {}
        @bundled[name.to_s] ||= Bundled.family(name)
      end

      def pack(name)
        @packs ||= {}
        return @packs[name.to_s] if @packs.key?(name.to_s)

        @packs[name.to_s] = Packs.family(name)
      end
    end
  end
end
