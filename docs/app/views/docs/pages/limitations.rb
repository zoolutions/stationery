# frozen_string_literal: true

class Views::Docs::Pages::Limitations < DocsUI::Page
  title "Limitations"
  eyebrow "Reference"

  def lead = "What stationery deliberately does not do (yet)."

  def content
    DocsUI::Section("Known limitations", description: "From the README.") do
      md SourceMarkdown.readme_section("Limitations")
    end

    DocsUI::Section("In detail") do
      md <<~'MD'
        | Area | Not supported |
        | --- | --- |
        | Fonts | Ligatures and other GSUB shaping, TrueType collections (`.ttc`), variable fonts (including CFF2), WOFF/WOFF2 |
        | SVG | `text`, `use`, patterns, masks, CSS stylesheets (inline `style` attributes work); gradient `reflect`/`repeat` spreads, per-stop opacity and gradient strokes are approximated |
        | PDF features | Encryption, forms, tagged (accessible) PDF |
        | Layout | Fixed-height boxes, and rows holding one, never split across pages |
        | Images | Formats other than JPEG and PNG; remote URLs are never fetched |

        Anything the engine skips at render time is reported in `document.warnings` rather than dropped
        silently — see [Warnings and strict mode](/docs/warnings).
      MD
    end
  end
end
