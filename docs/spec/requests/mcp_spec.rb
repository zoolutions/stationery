# frozen_string_literal: true

require "rails_helper"

# The docs over MCP: docs-kit's read-only server at POST /mcp, stateless
# JSON-RPC, one request per call. An agent adds the URL once and the pages
# are its tools (list_pages, get_page, search_docs).
RSpec.describe "The docs over MCP" do
  def rpc(method, params = {}, id: 1)
    post "/mcp", params: { jsonrpc: "2.0", id:, method:, params: }.to_json,
                 headers: { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
    expect(response).to have_http_status(:ok), "expected #{method} to answer 200, got #{response.status}"
    expect(response.media_type).to eq("application/json")
    JSON.parse(response.body)
  end

  def tool_text(name, arguments)
    result = rpc("tools/call", { name:, arguments: }).fetch("result")
    expect(result["isError"]).to be_falsey
    JSON.parse(result.fetch("content").first.fetch("text"))
  end

  it "initializes as the stationery docs" do
    reply = rpc("initialize", { protocolVersion: "2025-06-18", capabilities: {},
                                clientInfo: { name: "spec", version: "0" } })

    expect(reply.dig("result", "serverInfo", "name")).to eq("stationery")
    expect(reply.dig("result", "capabilities")).to include("tools")
    expect(reply.dig("result", "instructions")).to include("Pure-Ruby PDF", "search_docs", "/llms.txt")
  end

  it "offers the three read-only tools" do
    tools = rpc("tools/list").dig("result", "tools").map { |tool| tool["name"] }

    expect(tools).to match_array(%w[list_pages get_page search_docs])
  end

  it "lists every registered page" do
    pages = tool_text("list_pages", {})

    expect(pages.map { |page| page["slug"] }).to match_array(Doc.all.map(&:slug))
    expect(pages.find { |page| page["slug"] == "examples" }).to include("title" => "Examples", "group" => "Getting started")
  end

  it "reads a page as its Markdown twin" do
    page = tool_text("get_page", { slug: "getting-started" })

    get "/docs/getting-started.md"
    expect(page).to include("slug" => "getting-started", "title" => "Getting started")
    expect(page.fetch("markdown")).to eq(response.body)
  end

  it "searches the pages" do
    hits = tool_text("search_docs", { query: "table of contents" })

    expect(hits).not_to be_empty
    expect(hits.first.keys).to include("page_title", "section_title", "url", "snippet")
    expect(hits.map { |hit| hit["url"] }).to include(a_string_including("/docs/links"))
  end

  it "advertises the endpoint in /llms.txt" do
    get "/llms.txt"

    expect(response.body).to include("## MCP", "http://www.example.com/mcp")
  end

  it "answers 405 to GET and DELETE" do
    get "/mcp"
    expect(response).to have_http_status(:method_not_allowed)

    delete "/mcp"
    expect(response).to have_http_status(:method_not_allowed)
  end
end
