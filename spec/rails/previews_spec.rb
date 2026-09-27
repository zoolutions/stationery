# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe Stationery::PreviewsController do
  it "lists every preview with a debug link" do
    response = get("/rails/stationery/previews")

    expect(response.status).to eq(200)
    expect(response.content_type).to start_with("text/html")
    expect(response.body).to include('href="/rails/stationery/previews/invoice_pdf/paid"')
      .and include('href="/rails/stationery/previews/invoice_pdf/paid?debug=1"')
  end

  it "renders a preview inline" do
    response = get("/rails/stationery/previews/invoice_pdf/paid")

    expect(response.status).to eq(200)
    expect(response.content_type).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to start_with("inline")
    expect(response.body).to start_with("%PDF")
  end

  it "renders documents without a debug: keyword when asked for debug" do
    expect(get("/rails/stationery/previews/invoice_pdf/paid?debug=1").body).to start_with("%PDF")
  end

  it "forwards debug: to documents that accept it" do
    Stationery::Preview.load(Rails.application.config.stationery.preview_paths)
    debug = Class.new(InvoicePdfPreview::Invoice) { def to_pdf(debug: false) = "%PDF debug=#{debug}" }
    allow(InvoicePdfPreview::Invoice).to receive(:new).and_return(debug.new)

    expect(get("/rails/stationery/previews/invoice_pdf/paid?debug=1").body).to eq("%PDF debug=true")
  end

  it "runs around_render around building and rendering the document" do
    Stationery::Preview.load(Rails.application.config.stationery.preview_paths)
    InvoicePdfPreview.class_eval do
      def around_render(_name, params)
        Thread.current[:preview_locale] = params.fetch("locale", "en")
        yield
      ensure
        Thread.current[:preview_locale] = nil
      end
    end
    document = Class.new(InvoicePdfPreview::Invoice) do
      def view_template = text("locale #{Thread.current[:preview_locale]}")
    end
    allow(InvoicePdfPreview::Invoice).to receive(:new).and_return(document.new)

    expect(text_of(get("/rails/stationery/previews/invoice_pdf/paid?locale=de").body)).to eq("locale de")
  end

  it "answers 404 for an unknown preview" do
    expect(get("/rails/stationery/previews/invoice_pdf/missing").status).to eq(404)
  end

  it "answers 404 when previews are off" do
    allow(Rails.application.config.stationery).to receive(:show_previews).and_return(false)

    expect(get("/rails/stationery/previews").status).to eq(404)
    expect(get("/rails/stationery/previews/invoice_pdf/paid").status).to eq(404)
  end
end
