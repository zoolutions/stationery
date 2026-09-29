# frozen_string_literal: true

# Every document under the gem's examples/: a preview of its first page
# (docs/public/examples/<name>.png, regenerated with `rake docs:examples`), a
# link to the live PDF this site renders on request (/examples/<name>.pdf) and
# its whole source, read from the file at render time and folded under the
# preview. Descriptions are hand-written; the summary line under each heading
# is read from the example's own header comment.
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
    [ "Shipping label", "shipping_label",
     "A 4 × 6 in label in black and white only, sized with `page size: \"4in x 6in\"` and `mm()`, declared " \
     "`monochrome dpi: 203`, with a Code 128 and a QR code from `barcode`, and written both as a PDF and, " \
     "with `to_zpl`, as ZPL for a thermal label printer, which draws the two barcodes itself (`native: " \
     "true`): `stationery render examples/shipping_label.rb --zpl`. See [Label printers](/docs/pages)." ],
    [ "Application form", "form",
     "An interactive AcroForm: labelled text fields, a comb postcode, a select box, a radio group, check " \
     "boxes with labels, a multiline note and a signature field. Fill it in any viewer; every field and " \
     "option is on [Forms](/docs/forms)." ],
    [ "Magazine article", "article",
     "Floats: a photo floated left with justified text wrapping beside it and continuing below, a pull " \
     "quote floated right between two paragraphs, and an image floated by CSS inside `html`. Tagged: the " \
     "photos are figures and the quote a block quote, read where they were written." ],
    [ "Postcard", "postcard",
     "An A5 landscape card: the photo collage on its own — a rounded, shadowed base photo with two tilted, " \
     "white-framed snapshots over its corners — beside a greeting." ],
    [ "Newsletter", "newsletter",
     "A masthead across the page, then an article poured through two balanced `columns` with a rule " \
     "between them: justified, hyphenated paragraphs with `orphans:` and `widows:`, headings kept with " \
     "what follows, a photo with its caption kept together, and a note across the page below the columns." ],
    [ "Price list", "price_list",
     "2,000 articles over forty-four pages: a table read from an `Enumerator` of records (a seeded `Random`, " \
     "so the file is the same every time), its header row repeated on every page, a header and a footer " \
     "with page numbers, and `incremental`, so each page's content is written as soon as it is painted." ],
    [ "Contract", "contract",
     "Numbered clauses and sub-clauses whose headings keep 50 points of their text with them " \
     "(`keep_with_next: 50`), a footer with a text field for each party's initials on every page, and a " \
     "signature field per party, which `to_pdf(sign: { certificate:, key:, field: \"signature.provider\" })` " \
     "signs. See [Digital signatures](/docs/conformance)." ],
    [ "Certificate", "certificate",
     "Landscape A4 with a frame and rosettes drawn on a `canvas` in a background `page_template`, centred " \
     "type, an SVG seal, and two signature fields for the people who sign it." ],
    [ "Résumé", "resume",
     "Two columns of unequal width (`column(width: 0.3)` and the rest): a tinted sidebar with `mailto:`, " \
     "`tel:` and web links and a `wrap` of skill chips, and the experience written as HTML with a " \
     "`<style>` rule, read by `html` with its links." ],
    [ "Menu", "menu",
     "A photo floated left and the dish of the day floated right with the introduction wrapped between " \
     "them, then the courses poured through two balanced `columns`, each course kept together, with " \
     "headings in the bold of Inter." ],
    [ "Accessible report", "accessible_report",
     "PDF/UA-1 (`conformance :pdf_ua1`): headings in order, a photo and an SVG bar chart as figures with " \
     "their `alt:` text, a table whose header row is tagged as header cells, a list, a title and a " \
     "language. Validated as PDF/UA-1 and PDF/A-3b with veraPDF in CI." ],
    [ "Multilingual notice", "multilingual_notice",
     "English, German and Swedish side by side, each column justified and hyphenated by the patterns of " \
     "its language (`hyphenate: true`, `\"de\"`, `\"sv\"`). With `CJK_FONT` naming a font that has Japanese, " \
     "a Japanese paragraph is drawn from it through `font_fallbacks` and breaks between ideographs; Inter " \
     "and the font packs have no CJK glyphs." ]
  ].freeze

  title "Examples"
  eyebrow "Getting started"

  def lead = "Eighteen complete documents from the gem's examples/ directory, rendered live by this site."

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

        They ship with the gem, with the images they read, so an application that has only the gem has
        them too. Inter is the one font the gem ships, so there the invoice examples are set in Inter
        rather than the Open Sans of the repository:

        ```shell
        stationery examples                          # their names and what each shows
        stationery examples invoice                  # the path of one; --source prints its code
        ls "$(bundle show stationery)/examples"      # or: gem contents stationery
        ```

        The source of each is under its preview, and in the Markdown of this page. The
        [Cookbook](/docs/cookbook) walks through the code of five of them, method by method.
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
      source("#{file}.rb")
    end
  end

  # Folded, so ten sources leave the page as long as it was. A <details> opens
  # without JavaScript, and the Markdown twin has the code either way.
  def source(file)
    details do
      summary(class: "cursor-pointer font-medium") { "The source: examples/#{file}" }
      DocsUI::Code(SourceMarkdown.example_source(file), filename: "examples/#{file}")
    end
  end
end
