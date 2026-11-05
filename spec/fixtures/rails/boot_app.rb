# frozen_string_literal: true

# Boots a Rails app rooted at ARGV[0], previews on when ARGV[1] is "true", and
# writes what it found as JSON to ARGV[2]. spec/rails/previews_boot_spec.rb runs it in a
# fresh process. ActionController::Base is loaded during boot twice over: here
# at require time, as a gem does, and in the app's config/initializers.
require "json"
require "rails"
require "action_controller/railtie"
require "rack/mock"
require "stationery/rails"
ActionController::Base.config

root = ARGV.fetch(0)
show_previews = ARGV.fetch(1) == "true"
report_path = ARGV.fetch(2)

class BootApp < Rails::Application
  config.eager_load = false
  config.secret_key_base = "test"
  config.hosts.clear
  config.logger = Logger.new(nil)
  config.action_dispatch.show_exceptions = :none
  config.stationery.font_paths = []
  config.stationery.preview_paths = [File.expand_path("../previews", __dir__)]
end
BootApp.config.root = root
# Helper paths set before the app's initializers run, as a non-isolated engine
# sets them: a controller defined during boot constantizes the helpers in them.
BootApp.config.helpers_paths << File.join(root, "app/helpers")
BootApp.config.stationery.show_previews = show_previews
BootApp.initialize!

report = { "autoload" => Stationery.autoload?(:PreviewsController) }

# An unrouted path raises under show_exceptions = :none: it is reported as such.
def get(path)
  response = Rack::MockRequest.new(BootApp).get(path)
  [response.status, response.body[0, 4]]
rescue ActionController::RoutingError
  ["unrouted", nil]
end

index, = get("/rails/stationery/previews")
pdf, body = get("/rails/stationery/previews/invoice_pdf/paid")
# Routes load lazily: they are drawn by the first request.
report.merge!("index" => index, "pdf" => pdf, "pdf_body" => body,
              "routed" => BootApp.routes.named_routes.key?(:stationery_previews))
report["helpers"] = Stationery::PreviewsController._helpers.include?(ApplicationHelper) if show_previews
File.write(report_path, JSON.generate(report))
