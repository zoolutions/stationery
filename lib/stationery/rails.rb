# frozen_string_literal: true

require "stationery"

module Stationery
  # Controller helper:
  #
  #   def show
  #     send_pdf InvoicePdf.new(@invoice), filename: "invoice.pdf"
  #   end
  module Rails
    def send_pdf(document, disposition: "inline", type: "application/pdf", **)
      send_data(document.to_pdf, type:, disposition:, **)
    end
  end
end

if defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load)
  ActiveSupport.on_load(:action_controller) { include Stationery::Rails }
end

require_relative "railtie" if defined?(Rails::Railtie)
