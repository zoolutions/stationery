# frozen_string_literal: true

require "erb"
require "stationery/preview"

module Stationery
  # Serves Stationery::Preview classes at /rails/stationery/previews. Loaded
  # by the Railtie when config.stationery.show_previews is on.
  class PreviewsController < ActionController::Base
    before_action :require_previews
    before_action :load_previews

    def index
      paths = Preview.all.flat_map { |klass| klass.pdfs.map { "#{klass.preview_name}/#{it}" } }
      render html: page(paths).html_safe
    end

    def show
      klass, pdf = Preview.find(params[:path])
      return head(:not_found) unless klass

      document = klass.new.render(pdf, request.query_parameters.except("debug"))
      send_data document.to_pdf(**debug_option(document)), type: "application/pdf", disposition: "inline"
    end

    private

    def config = ::Rails.application.config.stationery

    def require_previews
      head :not_found unless config.show_previews
    end

    def load_previews
      Preview.load(Railtie.preview_paths(::Rails.root, config.preview_paths))
    end

    def debug_option(document)
      debug = params[:debug].present? && document.method(:to_pdf).parameters.include?(%i[key debug])
      debug ? { debug: true } : {}
    end

    def page(paths)
      items = paths.map do |path|
        href = ERB::Util.html_escape("#{request.path.chomp("/")}/#{path}")
        %(<li><a href="#{href}">#{ERB::Util.html_escape(path)}</a> <a href="#{href}?debug=1">debug</a></li>)
      end
      <<~HTML
        <!doctype html>
        <html>
          <head><meta charset="utf-8"><title>PDF previews</title></head>
          <body style="font-family: system-ui, sans-serif; margin: 2rem">
            <h1>PDF previews</h1>
            <ul>#{items.join("\n")}</ul>
            #{"<p>No previews found in #{ERB::Util.html_escape(config.preview_paths.join(", "))}.</p>" if items.empty?}
          </body>
        </html>
      HTML
    end
  end
end
