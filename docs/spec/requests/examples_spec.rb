# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Live example PDFs" do
  it "streams every example as a PDF" do
    expect(ExamplesController.names).to include("invoice", "flyer", "postcard", "newsletter")

    ExamplesController.names.each do |name|
      get "/examples/#{name}.pdf"

      expect(response).to have_http_status(:ok), "expected /examples/#{name}.pdf to render, got #{response.status}"
      expect(response.media_type).to eq("application/pdf")
      expect(response.body).to start_with("%PDF")
    end
  end

  it "renders each example once per process" do
    get "/examples/invoice.pdf"
    first = ExamplesController::CACHE.fetch("invoice")
    get "/examples/invoice.pdf"

    expect(ExamplesController::CACHE.fetch("invoice")).to equal(first)
    expect(response.body).to eq(first[:pdf])
  end

  it "answers 404 for anything that is not an example" do
    get "/examples/missing.pdf"
    expect(response).to have_http_status(:not_found)

    get "/examples/..%2Flib.pdf"
    expect(response).to have_http_status(:not_found)
  end

  it "lists every example on the docs page with its preview and links" do
    get "/docs/examples"

    expect(response).to have_http_status(:ok)
    ExamplesController.names.each do |name|
      expect(response.body).to include("/examples/#{name}.pdf")
      expect(response.body).to include("/examples/#{name}.png")
      expect(response.body).to include("examples/#{name}.rb")
    end
  end
end
