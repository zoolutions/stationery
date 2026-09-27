# frozen_string_literal: true

class InvoicePdfPreview < Stationery::Preview
  class Invoice < Stationery::Document
    page size: [300, 200], margin: 20
    font_family "Open Sans", regular: File.expand_path("../fonts/OpenSans-Regular.ttf", __dir__)
    default_text font: "Open Sans", size: 10

    def view_template = text("Paid")
  end

  def paid = Invoice.new
end
