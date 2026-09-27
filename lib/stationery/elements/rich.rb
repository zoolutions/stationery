# frozen_string_literal: true

module Stationery
  # HTML and Markdown rendered with the element DSL; the parsers load on first use.
  module Elements
    # HTML such as ActionText's `record.body.to_s`. `images:` resolves an
    # image src to a path or IO (nil skips it); otherwise it is read from
    # under `base_path:`. Remote images are never fetched. `links:` lists the
    # URL schemes written as links (default http, https, mailto and tel;
    # `#anchor` always is); `:all` keeps every href for trusted sources.
    def html(source, styles: {}, gap: 6, images: nil, base_path: nil, bookmarks: false, links: nil)
      require_relative "../html/document"
      rich(HTML.parse(source.to_s), styles:, gap:, images:, base_path:, bookmarks:, links:)
    end

    # CommonMark (plus GFM tables and strikethrough); options as for html.
    def markdown(source, styles: {}, gap: 6, images: nil, base_path: nil, bookmarks: false, links: nil)
      require_relative "../markdown/document"
      rich(Markdown.parse(source.to_s), styles:, gap:, images:, base_path:, bookmarks:, links:)
    end

    private

    def rich(blocks, **)
      require_relative "../rich/renderer"
      Rich::Renderer.new(self, @_builder, **).render(blocks)
    end
  end
end
