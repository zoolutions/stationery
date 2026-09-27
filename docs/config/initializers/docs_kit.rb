# docs-kit synced: v1.1.1
# frozen_string_literal: true

# docs-kit configuration — everything that makes this site look like
# "stationery" rather than any other docs site. The shared chrome
# (Shell/Sidebar/ThemeSwitcher/Code/Page) comes from the gem; only this config
# differs per site. The `themes` MUST match the @plugin "daisyui" { themes: ... }
# block in app/assets/stylesheets/application.tailwind.css.
Rails.application.config.to_prepare do
  DocsKit.configure do |c|
    c.brand        = "stationery"
    c.title_suffix = "stationery"

    # The one-line summary agents read first in /llms.txt.
    c.tagline = "Pure-Ruby PDF documents built from Phlex-style components — a box-layout engine " \
                "that measures, places and paginates rows, columns, boxes, tables, text and images, " \
                "with subsetted TrueType/OpenType fonts and no runtime dependencies."

    c.themes = %w[dark light synthwave retro cyberpunk dracula night nord sunset]

    # A lambda so it re-reads the constant on every reload (the path gem loads in full).
    c.version_badge = -> { "v#{Stationery::VERSION}" }

    # A light base with a dark override, scoped per shipped dark theme (CSS-only).
    c.code_theme      = "Rouge::Themes::Github"
    c.code_theme_dark = "Rouge::Themes::Monokai"

    c.topbar_links = [
      { href: "https://github.com/zoolutions/stationery", label: "GitHub", icon: :github },
      { href: "https://rubygems.org/gems/stationery", label: "RubyGems", icon: :rubygems }
    ]

    c.seo.description  = "Pure-Ruby PDF layout engine with a Phlex-style DSL: rows, columns, boxes, " \
                         "tables, lists, SVG, headers and footers, bookmarks and a table of contents — " \
                         "no Prawn, no headless Chrome, no native extensions."
    c.seo.site_url     = "https://stationery.zoolutions.llc"
    c.seo.twitter_card = "summary_large_image"
    c.seo.twitter_site = "@mhenrixon"
    c.seo.locale       = "en_US"
    c.seo.theme_color  = "#1d232a" # daisyUI dark base-100 (themes.first)
    c.seo.favicon      = "/icon.svg"

    c.landing.eyebrow = "Ruby gem"
    c.landing.title   = "PDFs from **components**, not cursor arithmetic"
    c.landing.lead    = "Describe the page with rows, columns, boxes, tables, text and images. " \
                        "A box-layout engine measures, places and paginates them; a small PDF writer " \
                        "embeds subsetted fonts and images. Standard library only."
    c.landing.install = { code: 'gem "stationery"', filename: "Gemfile", lexer: :ruby }
    c.landing.ctas = [
      { label: "Get started", href: "/docs/getting-started", style: :primary },
      { label: "Elements", href: "/docs/elements", style: :ghost },
      { label: "GitHub", href: "https://github.com/zoolutions/stationery", style: :ghost, icon: :github }
    ]
    c.landing.features = [
      { icon: "package", title: "No runtime dependencies",
        body: "Standard library only. No Prawn, no headless Chrome, no native extensions, no other processes." },
      { icon: "layout-template", title: "Declarative layout",
        body: "Padding, backgrounds, borders, radii, column widths and page breaks are the engine's job." },
      { icon: "type", title: "Real typography",
        body: "Subsetted TrueType and CFF fonts, GPOS kerning, justification and per-character fallback. " \
              "Inter ships inside the gem." },
      { icon: "table", title: "Tables that paginate",
        body: "Spans, zebra stripes, selections, repeating headers and rows that split across pages." },
      { icon: "bookmark", title: "Links and outlines",
        body: "Named anchors, internal links, PDF bookmarks and a table of contents with page numbers." },
      { icon: "flask-conical", title: "Testable",
        body: "RSpec matchers, Minitest assertions, strict mode and Rails previews like ActionMailer's." }
    ]

    # The sidebar, search, /llms.txt and the .md twins all derive from the registry.
    c.nav_registries = { "Docs" => Doc }
  end
end
