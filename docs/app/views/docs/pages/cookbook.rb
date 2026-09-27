# frozen_string_literal: true

# Excerpts are read from examples/*.rb at render time, so they follow the
# runnable, CI-rendered examples instead of drifting from them.
class Views::Docs::Pages::Cookbook < DocsUI::Page
  REPO = "https://github.com/zoolutions/stationery/blob/main/examples"

  title "Cookbook"
  eyebrow "Reference"

  def lead = "Four complete, runnable documents from the gem's examples/ directory — each rendered in CI and covered by an integration spec."

  def content
    DocsUI::Section("Running the examples") do
      md <<~'MD'
        ```shell
        bundle exec rake examples                 # renders every example next to its source
        stationery render examples/report.rb      # or one of them
        ruby -Ilib examples/invoice.rb            # each file also runs on its own
        ```
      MD
    end

    recipe "Invoice", "invoice.rb",
           notes: "A row with a logo, an amount-due callout with a status pill, a summary table without borders, " \
                  "and a line-item table with a coloured header, right-aligned money columns, zebra rows and " \
                  "a bold totals row.",
           methods: %w[summary line_items]

    recipe "Annual report", "report.rb",
           notes: "A header that skips the cover (`on: :rest`), a footer on every page, a contents page built by " \
                  "`table_of_contents`, headings with bookmarks and `keep_with_next`, a table with a `colspan` " \
                  "total row and a callout box that splits across pages with `break_inside: :auto`.",
           methods: %w[revenue_table callout]

    recipe "Letter", "letter.rb",
           notes: "A one-page letter: a vector letterhead drawn from inline SVG, a `text_style` block for the contact " \
                  "column and a legal footer.",
           methods: %w[letterhead]

    recipe "Packing slip", "packing_slip.rb",
           notes: "Landscape A4, a header with page numbers, a 120-row table with `split_rows: true` and a repeating " \
                  "header, and a barcode drawn on a `canvas`.",
           methods: %w[barcode items_table]
  end

  private

  def recipe(title, file, notes:, methods:)
    DocsUI::Section(title, description: SourceMarkdown.example_summary(file)) do
      md "#{notes} Full source: [examples/#{file}](#{REPO}/#{file})."
      DocsUI::Code(SourceMarkdown.example_config(file), filename: "examples/#{file} — class configuration")
      methods.each do |method|
        DocsUI::Code(SourceMarkdown.example_method(file, method), filename: "examples/#{file} — ##{method}")
      end
    end
  end
end
