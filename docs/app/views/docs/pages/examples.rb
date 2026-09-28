# frozen_string_literal: true

# Every document under the gem's examples/: a preview of its first page
# (docs/public/examples/<name>.png, regenerated with `rake docs:examples`), a
# link to the live PDF this site renders on request (/examples/<name>.pdf) and
# the source on GitHub. Descriptions are hand-written; the summary line under
# each heading is read from the example's own header comment.
class Views::Docs::Pages::Examples < DocsUI::Page
  REPO = "https://github.com/zoolutions/stationery/blob/main/examples"

  EXAMPLES = [
    [ "Event flyer", "flyer",
     "The closest thing to a real marketing document: a cover photo bled to the page edges, a date pill, " \
     "a stats band, prose from `html` with list styles, a tilted photo collage built from `stack` and " \
     "`layer`, a price table, accommodation cards, a gallery grid of `fit: :cover` photos, blockquote " \
     "testimonials and a call to action whose whole pill is a link. Tagged, bookmarked, four pages." ],
    [ "Invoice", "invoice",
     "A row with a logo, an amount-due callout with a status pill, a summary table without borders and a " \
     "line-item table with a coloured header, right-aligned money columns, zebra rows and a bold totals row." ],
    [ "Factur-X e-invoice", "e_invoice",
     "The invoice above as an e-invoice: one `factur_x` line makes it PDF/A-3b, embeds the EN 16931 invoice " \
     "XML built from the same line items and identifies it in XMP, so accounting software books what people " \
     "read. Validated with veraPDF and Mustang in CI; see [PDF/A and PDF/UA](/docs/conformance)." ],
    [ "Annual report", "report",
     "A header that skips the cover, a footer on every page, a contents page from `table_of_contents`, " \
     "headings with bookmarks and `keep_with_next`, nested lists, a table with a `colspan` total row and a " \
     "callout that splits across pages." ],
    [ "Letter", "letter",
     "A one-page letter with a vector letterhead drawn from inline SVG, a `text_style` block for the contact " \
     "column and a legal footer." ],
    [ "Packing slip", "packing_slip",
     "Landscape A4, page numbers in the header, a 120-row table with `split_rows: true` and a repeating " \
     "header, and a barcode drawn on a `canvas`." ],
    [ "Application form", "form",
     "An interactive AcroForm: labelled text fields, a comb postcode, a select box, a radio group, check " \
     "boxes with labels, a multiline note and a signature field. Fill it in any viewer; every field and " \
     "option is on [Forms](/docs/forms)." ],
    [ "Postcard", "postcard",
     "An A5 landscape card: the photo collage on its own — a rounded, shadowed base photo with two tilted, " \
     "white-framed snapshots over its corners — beside a greeting." ],
    [ "Newsletter", "newsletter",
     "A masthead across the page, then an article poured through two balanced `columns` with a rule " \
     "between them: justified, hyphenated paragraphs with `orphans:` and `widows:`, headings kept with " \
     "what follows, a photo with its caption kept together, and a note across the page below the columns." ]
  ].freeze

  title "Examples"
  eyebrow "Getting started"

  def lead = "Nine complete documents from the gem's examples/ directory, rendered live by this site."

  def content
    DocsUI::Section("Running them yourself") do
      md <<~'MD'
        Every example is a single Ruby file with a `preview` class method, rendered in CI and covered by an
        integration spec. The PDFs linked below are rendered on request by the same gem checkout this site
        runs on.

        ```shell
        bundle exec rake examples                 # renders every example next to its source
        stationery render examples/flyer.rb       # or one of them
        ruby -Ilib examples/flyer.rb              # each file also runs on its own
        ```

        The [Cookbook](/docs/cookbook) walks through the code of five of them, method by method.
      MD
    end

    EXAMPLES.each { |name, file, notes| example_section(name, file, notes) }
  end

  private

  def example_section(name, file, notes)
    DocsUI::Section(name, description: SourceMarkdown.example_summary("#{file}.rb")) do
      md "#{notes}\n\n[Open the PDF](/examples/#{file}.pdf) · [Source on GitHub](#{REPO}/#{file}.rb)"
      prose do
        a(href: "/examples/#{file}.pdf", title: "Open #{name} as a PDF") do
          img(src: "/examples/#{file}.png", alt: "The first page of the #{name.downcase} example",
              loading: "lazy", class: "rounded-box border border-base-300 shadow-sm max-w-md w-full")
        end
      end
    end
  end
end
