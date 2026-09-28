# frozen_string_literal: true

# In-memory registry of the reference docs. One line per page — slug and view
# derive from the title (both overridable), and the sidebar nav derives from
# this registry with zero extra code (see config/initializers/docs_kit.rb's
# `nav_registries`). Add a page with `rails g docs_kit:page "Title" --group=…`,
# which appends the `page` line here and writes the class under
# app/views/docs/pages/.
#
# Uses DocsKit::Registry for the shared all/from_slug/grouped/nav_items API.
class Doc
  extend DocsKit::Registry
  path_prefix    "/docs"
  view_namespace "Views::Docs::Pages"

  page "Getting started", group: "Getting started"
  page "Documents and components", group: "Getting started"
  page "Examples", group: "Getting started"

  page "Elements", group: "Guide"
  page "Layout rules", group: "Guide"
  page "Pages, headers and footers", group: "Guide", slug: "pages", view: "Pages"
  page "Links, bookmarks and contents", group: "Guide", slug: "links", view: "Links"
  page "Fonts", group: "Guide"
  page "Images and SVG", group: "Guide"
  page "Forms", group: "Guide"
  page "PDF/A and PDF/UA", group: "Guide", slug: "conformance", view: "Conformance"

  # A page class named `Rails` would shadow ::Rails inside Views::Docs::Pages.
  page "Rails", group: "Integrations", view: "RailsIntegration"
  page "Testing", group: "Integrations"
  page "CLI", group: "Integrations", slug: "cli", view: "Cli"

  page "Warnings and strict mode", group: "Reference", slug: "warnings", view: "Warnings"
  page "Cookbook", group: "Reference"
  page "Performance", group: "Reference"
  page "Limitations", group: "Reference"
  page "Changelog", group: "Reference"
end
