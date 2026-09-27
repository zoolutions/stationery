# frozen_string_literal: true

class Views::Docs::Pages::Cli < DocsUI::Page
  title "CLI"
  eyebrow "Integrations"

  def lead = "The stationery executable: render a document file to PDF, and list or install font packs."

  def content
    DocsUI::Section("stationery render", description: "Render the Document a Ruby file defines.") do
      md <<~'MD'
        ```shell
        stationery render app/pdfs/invoice_pdf.rb                # writes app/pdfs/invoice_pdf.pdf
        stationery render invoice.rb --out - > invoice.pdf       # PDF to stdout
        stationery render pdfs.rb --class InvoicePdf --strict    # pick one; fail on layout warnings
        stationery render examples/report.rb --debug             # layout outlines
        ```

        | Option | Meaning |
        | --- | --- |
        | `-o, --out PATH` | Where to write the PDF (default: the file's name with `.pdf`); `-` writes to stdout. |
        | `-c, --class NAME` | The document class to render when the file defines several. |
        | `--strict` | Exit 1 without writing when layout reports warnings. |
        | `--debug` | Render with `debug: true` when the document supports it. |
        | `-h, --help` | Show help. |

        `render` loads the file and renders the `Stationery::Document` it defines, then reports pages and
        bytes. Layout warnings print to stderr.
      MD
    end

    DocsUI::Section("self.preview", description: "Documents that need arguments.") do
      md <<~'MD'
        A document whose `initialize` needs arguments renders from `def self.preview`, which returns an
        instance built with sample data — the same method is handy in tests and Rails previews:

        ```ruby
        class ExampleInvoice < Stationery::Document
          def self.preview
            new(number: "INV-2026-042", items: [["Brand workshop", 1, 2400.0]],
                customer: "Müller & Söhne GmbH", due: "26 October 2026")
          end

          def initialize(number:, items:, customer:, due:)
            super()
            # …
          end
        end
        ```
      MD
    end

    DocsUI::Section("stationery fonts", description: "List and install font packs.") do
      md <<~'MD'
        ```shell
        stationery fonts list                                    # packs, licenses, what is in vendor/fonts
        stationery fonts install noto_sans liberation_serif      # into vendor/fonts/<pack>/
        stationery fonts install noto_sans --into app/fonts --force
        stationery fonts install liberation_sans --from ~/Downloads/liberation-fonts-ttf-2.1.5.tar.gz  # offline
        ```

        `fonts install` downloads pinned files over HTTPS, checks every SHA-256 before writing anything, and
        writes the license next to the fonts. Files already present are kept unless `--force`. `--from` takes
        a directory or a `.tar.gz` holding the same files (still SHA-checked). See [Fonts](/docs/fonts).

        `stationery help` lists the commands.
      MD
    end
  end
end
