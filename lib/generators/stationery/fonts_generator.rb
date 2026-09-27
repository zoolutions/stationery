# frozen_string_literal: true

require "rails/generators"
require "stationery"

module Stationery
  module Generators
    # bin/rails generate stationery:fonts noto_sans liberation_serif [--into vendor/fonts] [--force]
    class FontsGenerator < ::Rails::Generators::Base
      desc "Install pinned, SHA-256-checked font packs (#{Stationery::Fonts.catalog.map(&:key).join(", ")})"
      argument :names, type: :array, banner: "PACK PACK"
      class_option :into, type: :string, default: Stationery::Fonts::DEFAULT_DIR, desc: "Where packs live"
      class_option :force, type: :boolean, default: false, desc: "Replace files that are already installed"

      def install_packs
        dir = File.expand_path(options[:into], destination_root)
        names.each do |name|
          Stationery::Fonts.install(name, into: dir, force: options[:force], out: $stdout)
          say "Use it with: #{Stationery::Fonts.usage(name, options[:into]).last}"
        end
      end
    end
  end
end
