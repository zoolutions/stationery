# frozen_string_literal: true

class Views::Docs::Pages::Cli < DocsUI::Page
  title "CLI"
  eyebrow "Integrations"

  def lead = "The stationery executable: render a document file to PDF and pictures, print what is on its pages, list or install font packs, and find the examples."

  def content
    DocsUI::Section("stationery render", description: "Render the Document a Ruby file defines.") do
      md <<~'MD'
        ```shell
        stationery render app/pdfs/invoice_pdf.rb                # writes app/pdfs/invoice_pdf.pdf
        stationery render invoice.rb --out - > invoice.pdf       # PDF to stdout
        stationery render pdfs.rb --class InvoicePdf --strict    # pick one; fail on layout warnings
        stationery render examples/report.rb --debug             # layout outlines
        stationery render invoice.rb --png                       # also invoice-1.png, … beside the PDF
        stationery render report.rb --png-only --pages 1,3-4 --dpi 144
        stationery render examples/shipping_label.rb --zpl       # writes shipping_label.zpl, 203 dpi
        ```

        | Option | Meaning |
        | --- | --- |
        | `-o, --out PATH` | Where to write the PDF (default: the file's name with `.pdf`); `-` writes to stdout. |
        | `-c, --class NAME` | The document class to render when the file defines several. |
        | `--zpl` | Write ZPL for a label printer instead of a PDF (default: the file's name with `.zpl`); see [Label printers](/docs/pages). |
        | `--dpi DPI` | The label printer's resolution for `--zpl`: 152, 203 (default), 300 or 600. For `--png`, pixels per inch of the pictures (default 96: an A4 page is 794 × 1123 px). |
        | `--strict` | Exit 1 without writing when layout reports warnings. |
        | `--debug` | Render with `debug: true` when the document supports it. |
        | `--png` | Also write a PNG of each page beside the PDF: `invoice-1.png`, `invoice-2.png`, … |
        | `--png-only` | Write the PNGs and no PDF. |
        | `--pages LIST` | The pages to picture, as `2` or `1,3-4` (default: all). |
        | `-h, --help` | Show help. |

        `render` loads the file and renders the `Stationery::Document` it defines, then reports pages (or labels) and
        bytes. Layout warnings print to stderr.

        The pictures are drawn by `to_png` (see [Pictures of a render](/docs/testing)), in Ruby with nothing
        to install, and each file is reported on a line of its own (`wrote invoice-1.png (page 1, 794 x 1123
        px)`), so an agent that rendered a document can open what it made.
      MD
    end

    DocsUI::Section("stationery inspect", description: "What is on each page, as text.") do
      md <<~'MD'
        ```shell
        stationery inspect invoice.pdf                           # what is on each page, as text
        stationery inspect invoice.rb                            # render it first, with its warnings
        stationery inspect invoice.pdf --json                    # Inspector#layout as JSON
        ```

        | Option | Meaning |
        | --- | --- |
        | `--json` | Print the layout as JSON. |
        | `-c, --class NAME` | The document class to render when a Ruby file defines several. |
        | `-h, --help` | Show help. |

        `inspect` prints what is on each page for an agent that cannot read a picture, and for a diff between
        two renders: the file's metadata, conformance claims, print hints, attachments and signatures, the
        outline, then each page with its size, its text lines (x, baseline y, font, size), images, links and
        form fields with their rectangles in points from the top-left corner, the structure tree of a tagged
        PDF and the warnings of the render. Sections with nothing in them are left out, and so are the dates,
        so two renders of one document print the same. It is `Inspector#layout` (see
        [Testing](/docs/testing)) and needs the `pdf-reader` gem.

        ```text
        examples/invoice.rb
          pages     1
          title     Invoice

        Page 1  595.3 x 841.9 pt
          Text (x, baseline y, font, size, text)
              44.0   65.5  OpenSans-Bold      22  Invoice INV-2026-042
              44.0  115.6  OpenSans-Bold       9  Invoice date
             134.0  115.6  OpenSans-Regular    9  26 September 2026
          Images (x, y, width x height, pixels)
             437.9   40.0  113.3 x 34  240 x 72 px
          Links (x, y, width x height, target)
             329.2  596.5  65.6 x 11.6  mailto:hello@acme.test
        ```
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

      MD
    end

    DocsUI::Section("stationery examples", description: "The examples that ship with the gem.") do
      md <<~'MD'
        ```shell
        stationery examples                                      # the examples in the gem, what each shows
        stationery examples invoice                              # the path of examples/invoice.rb there
        stationery examples invoice --source                     # its code
        stationery render "$(stationery examples invoice)" --out invoice.pdf
        ```

        `examples` lists the documents under `examples/` of the installed gem with the first sentence of
        their header comment. With a name it prints the path of that file, to read, copy or hand to
        `stationery render`; `-s, --source` prints the file itself. The [Examples](/docs/examples) page
        has their previews.

        `stationery help` lists the commands.
      MD
    end
  end
end
