# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "rack/mock"
require "stationery/rails"

class StationeryRailsApp < Rails::Application
  config.root = File.expand_path("../../tmp/rails", __dir__)
  config.eager_load = false
  config.secret_key_base = "test"
  config.hosts.clear
  config.logger = Logger.new(nil)
  config.action_dispatch.show_exceptions = :none
  config.stationery.font_paths = []
  config.stationery.show_previews = true
  config.stationery.preview_paths = [File.expand_path("../fixtures/previews", __dir__)]
end

StationeryRailsApp.initialize!

require_relative "../support/documents"
require_relative "../support/pdf_helpers"

class PdfController < ActionController::Base
  def document
    render pdf: SpecDocument.build { text "hi" }, filename: params[:filename]
  end

  def attachment
    render pdf: SpecDocument.build { text "hi" }, disposition: "attachment"
  end

  def name
    render pdf: "invoice"
  end

  def helper
    send_pdf SpecDocument.build { text "hi" }, filename: "helper.pdf"
  end
end

StationeryRailsApp.routes.draw do
  %w[document attachment name helper].each { |action| get "/pdf/#{action}", to: "pdf##{action}" }
end

module RailsRequestHelpers
  def get(path) = Rack::MockRequest.new(Rails.application).get(path)
end

RSpec.configure { |config| config.include RailsRequestHelpers }
