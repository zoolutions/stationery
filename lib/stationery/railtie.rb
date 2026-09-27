# frozen_string_literal: true

module Stationery
  # Loaded by stationery/rails inside a Rails app. Adds `render pdf:` and the
  # app's font directories. Configure in config/application.rb:
  #
  #   config.stationery.renderer = false            # keep another gem's render pdf:
  #   config.stationery.font_paths = ["app/fonts"]  # relative to Rails.root
  class Railtie < ::Rails::Railtie
    config.stationery = ActiveSupport::OrderedOptions.new
    config.stationery.renderer = true
    config.stationery.font_paths = ["vendor/fonts"]

    initializer "stationery.font_paths" do |app|
      Railtie.add_font_paths(app.root, app.config.stationery.font_paths)
    end

    initializer "stationery.renderer" do |app|
      Railtie.add_renderer if app.config.stationery.renderer
    end

    def self.add_font_paths(root, dirs)
      dirs.each do |dir|
        path = root.join(dir).to_s
        Stationery.font_paths << path if File.directory?(path) && !Stationery.font_paths.include?(path)
      end
    end

    def self.add_renderer
      ActiveSupport.on_load(:action_controller) do
        ActionController::Renderers.add(:pdf) do |document, options|
          unless document.respond_to?(:to_pdf)
            raise ArgumentError, "render pdf: expects a Stationery::Document (got #{document.class})"
          end

          send_pdf(document, **{ filename: options[:filename],
                                 disposition: options.fetch(:disposition, "inline") }.compact)
        end
      end
    end
  end
end
