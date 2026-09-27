# frozen_string_literal: true

module Stationery
  # Font packs: `Fonts.install(:noto_sans)` copies a catalog pack into
  # vendor/fonts/noto_sans/, after which `font_family "Noto Sans"` finds it
  # through `Stationery.font_paths` (the Railtie adds vendor/fonts).
  module Fonts
    DEFAULT_DIR = "vendor/fonts"

    def self.catalog = Catalog::PACKS

    def self.install(key, into: DEFAULT_DIR, **) = Installer.new(into:, **).install(key)

    # { style => path } for a pack installed under dir.
    def self.paths(key, dir: DEFAULT_DIR)
      pack = Catalog.fetch(key)
      pack.files.transform_values { |(*, file)| File.join(dir, pack.key.to_s, file) }
    end

    # Ruby lines selecting an installed pack.
    def self.usage(key, dir)
      pack = Catalog.fetch(key)
      short = "font_family #{pack.family.inspect}"
      return [short] if Stationery.font_paths.include?(File.expand_path(dir))

      ["#{short}  # when #{dir} is in Stationery.font_paths (Rails adds vendor/fonts)",
       "#{short}, **Stationery::Fonts.paths(:#{pack.key}, dir: #{dir.inspect})"]
    end

    # Installed packs found by family name in Stationery.font_paths.
    module Packs
      def self.family(name)
        Catalog::PACKS.each do |pack|
          next unless pack.family.casecmp?(name.to_s)

          Stationery.font_paths.each do |dir|
            paths = Fonts.paths(pack.key, dir:).select { |_, path| File.file?(path) }
            return Family.new(pack.family, **paths) if paths[:regular]
          end
        end
        nil
      end
    end
  end
end
