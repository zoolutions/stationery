# frozen_string_literal: true

module Stationery
  # HTML and Markdown rendered with the element DSL; the parsers load on first use.
  module Elements
    # HTML such as ActionText's `record.body.to_s`. `images:` resolves an
    # image src to a path or IO (nil skips it); otherwise it is read from
    # under `base_path:`. Remote images are never fetched. `links:` lists the
    # URL schemes written as links (default http, https, mailto and tel;
    # `#anchor` always is); `:all` keeps every href for trusted sources.
    # Elements nested deeper than `max_depth:` are flattened into the deepest
    # one kept (text stays, structure goes) and reported as a NestingLimit
    # warning, so content from users cannot exhaust the stack.
    def html(source, max_depth: 64, **)
      require_relative "../html/document"
      rich(HTML.parse(source.to_s, max_depth:) { |depth| nesting_limit(depth, max_depth) }, **)
    end

    # CommonMark (plus GFM tables and strikethrough); options as for html.
    def markdown(source, max_depth: 64, **)
      require_relative "../markdown/document"
      rich(Markdown.parse(source.to_s, max_depth:) { |depth| nesting_limit(depth, max_depth) }, **)
    end

    private

    def nesting_limit(depth, limit)
      @_builder.warnings << Warnings::NestingLimit.new(depth:, limit:)
    end

    def rich(blocks, styles: {}, gap: 6, images: nil, base_path: nil, bookmarks: false, links: nil)
      require_relative "../rich/renderer"
      Rich::Renderer.new(self, @_builder, styles:, gap:, images:, base_path:, bookmarks:, links:).render(blocks)
    end
  end
end
