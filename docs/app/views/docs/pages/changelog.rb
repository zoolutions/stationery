# frozen_string_literal: true

# Rendered from the repo's CHANGELOG.md at request time, so the page never
# needs editing alongside a release.
class Views::Docs::Pages::Changelog < DocsUI::Page
  title "Changelog"
  eyebrow "Reference"

  def lead = "Every user-facing change, newest first — rendered from CHANGELOG.md."

  def content
    DocsUI::Section("Releases") do
      md SourceMarkdown.changelog
    end
  end
end
