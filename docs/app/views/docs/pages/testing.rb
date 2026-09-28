# frozen_string_literal: true

class Views::Docs::Pages::Testing < DocsUI::Page
  title "Testing"
  eyebrow "Integrations"

  def lead = "RSpec matchers and Minitest assertions that read a rendered PDF back, built on Stationery::Testing::Inspector."

  def content
    DocsUI::Section("Matchers and assertions", description: "From the README.") do
      md SourceMarkdown.readme_section("Testing")
    end

    DocsUI::Section("Reference") do
      DocsUI::Table(
        %w[RSpec Minitest Passes when],
        [
          [ [ :code, "have_pdf_text(str_or_regexp)" ], [ :code, "assert_pdf_text / refute_pdf_text" ], "the text of all pages contains it" ],
          [ [ :code, "have_pdf_text_on_page(n, str_or_regexp)" ], "—", "page n (1-based) contains it" ],
          [ [ :code, "have_page_count(n)" ], [ :code, "assert_page_count" ], "the PDF has n pages" ],
          [ [ :code, "have_pdf_link(url_or_regexp)" ], [ :code, "assert_pdf_link" ], "a URI link annotation matches" ],
          [ [ :code, "have_image_count(n)" ], [ :code, "assert_image_count" ], "n image XObjects are embedded" ],
          [ [ :code, "have_bookmark(title)" ], [ :code, "assert_bookmark" ], "an outline entry has that title" ],
          [ [ :code, "have_pdf_language(lang)" ], [ :code, "assert_pdf_language" ], "the catalog /Lang (from metadata lang:) equals it" ],
          [ [ :code, "have_page_labels(labels)" ], [ :code, "assert_page_labels" ], "the /PageLabels tree names the pages exactly so (nil for a page before the first range)" ],
          [ [ :code, "have_attachment(name, mime:, relationship:)" ], [ :code, "assert_pdf_attachment" ], "an embedded file has that name (and type / relationship when given)" ],
          [ [ :code, "have_no_warnings" ], [ :code, "assert_no_pdf_warnings" ], "the render produced no warnings (documents only)" ]
        ]
      )

      md <<~'MD'
        Failure messages show what was found — an excerpt of the text, the links, the bookmarks or every
        warning message — so a failing spec explains itself.
      MD
    end

    DocsUI::Section("Inspector", description: "For anything the matchers do not cover.") do
      md <<~'MD'
        ```ruby
        pdf = Stationery::Testing::Inspector.new(InvoicePdf.new(invoice))

        pdf.page_count       # => 2
        pdf.page_texts       # => ["Invoice INV-7 …", "…"]
        pdf.text             # all pages, joined with newlines
        pdf.links            # => ["mailto:hello@acme.test"]
        pdf.internal_links   # named destinations the document links to
        pdf.image_count      # => 1
        pdf.bookmarks        # => ["Introduction", "Highlights", …]
        pdf.metadata         # => { Title: "Invoice", … }
        pdf.xmp              # the XMP packet, or nil with metadata xmp: false
        pdf.xmp_values       # => { "dc:title" => "Invoice", "dc:creator" => ["Acme"], "xmp:CreateDate" => "…", … }
        pdf.lang             # => "en", the catalog /Lang, or nil
        pdf.page_labels      # => ["i", "ii", "1", "2"] from page_labels, [] without
        pdf.attachments      # => [{ name: "factur-x.xml", mime: "text/xml", bytes: "<…>", … }]
        pdf.warnings         # the document's warnings after rendering it
        ```

        The subject is a document (rendered once), PDF bytes, a file path or an IO.
      MD
    end
  end
end
