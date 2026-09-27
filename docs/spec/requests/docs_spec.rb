# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Docs site" do
  it "renders the landing page" do
    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("stationery")
  end

  it "renders every registered docs page" do
    expect(Doc.all).not_to be_empty

    Doc.all.each do |doc|
      expect(doc.view_class).not_to be_nil, "expected a page class for /docs/#{doc.slug}"
      get "/docs/#{doc.slug}"

      expect(response).to have_http_status(:ok), "expected /docs/#{doc.slug} to render, got #{response.status}"
    end
  end

  it "serves every page as a Markdown twin" do
    Doc.all.each do |doc|
      get "/docs/#{doc.slug}.md"

      expect(response).to have_http_status(:ok), "expected /docs/#{doc.slug}.md to render, got #{response.status}"
    end
  end

  it "renders README and CHANGELOG content from the repo" do
    get "/docs/performance"
    expect(response.body).to include("Renders/s")

    get "/docs/changelog"
    expect(response.body).to include("0.1.0")
  end

  it "documents every public element" do
    get "/docs/elements"

    %w[text box row column group wrap table image svg rule spacer page_break canvas ul ol li anchor bookmark
       table_of_contents html markdown text_style text_field checkbox radio select
       signature_field].each do |element|
      expect(response.body).to include("<code>#{element}"), "expected the elements page to cover #{element}"
    end
  end

  it "serves the AI surfaces" do
    get "/llms.txt"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("stationery")

    get "/llms-full.txt"
    expect(response).to have_http_status(:ok)
  end

  it "answers the healthcheck" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
