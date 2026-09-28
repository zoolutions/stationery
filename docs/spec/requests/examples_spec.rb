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

  it "shows the whole source of every example on the docs page, folded" do
    get "/docs/examples"

    page = Nokogiri::HTML5(response.body)
    sources = page.css("#docs-content details").to_h { |fold| [ fold.at_css("summary").text, fold.at_css("pre").text ] }

    expect(sources.keys).to match_array(ExamplesController.names.map { |name| "The source: examples/#{name}.rb" })
    ExamplesController.names.each do |name|
      expect(sources.fetch("The source: examples/#{name}.rb").strip).to eq(SourceMarkdown.example_source("#{name}.rb").strip)
    end
    expect(page.css("#docs-content details[open]")).to be_empty
  end

  it "carries the sources in the Markdown twin of the page" do
    get "/docs/examples.md"

    expect(response).to have_http_status(:ok)
    ExamplesController.names.each do |name|
      source = SourceMarkdown.example_source("#{name}.rb").strip
      expect(response.body).to include("The source: examples/#{name}.rb\n\n```ruby\n#{source}\n```")
    end
  end

  it "carries the sources in /llms-full.txt, once" do
    get "/llms-full.txt"

    expect(response).to have_http_status(:ok)
    ExamplesController.names.each do |name|
      source = SourceMarkdown.example_source("#{name}.rb").strip
      expect(response.body.scan("```ruby\n#{source}\n```").size).to eq(1), "expected the source of #{name} once"
    end
  end
end
