# frozen_string_literal: true

class Views::Docs::Pages::GettingStarted < DocsUI::Page
  title "Getting started"
  eyebrow "Getting started"

  def lead = "Install the gem, write a document class, call to_pdf. No fonts, binaries or services to set up."

  def content
    DocsUI::Section("Install", description: "One gem, standard library only.") do
      DocsUI::Code(<<~RUBY, filename: "Gemfile")
        gem "stationery"
      RUBY

      md <<~'MD'
        Stationery needs **Ruby 3.4 or newer** and has no runtime dependencies: no Prawn, no headless
        Chrome, no native extensions and no other processes. In a Rails app require the Railtie instead —
        see [Rails](/docs/rails):

        ```ruby
        gem "stationery", require: "stationery/rails"
        ```
      MD
    end

    DocsUI::Section("Your first document", description: "A class, a view_template, to_pdf.") do
      md <<~'MD'
        A document is a `Stationery::Document` subclass. `view_template` describes the page with
        [elements](/docs/elements); `to_pdf` lays them out, paginates and returns the PDF bytes.

        ```ruby
        require "stationery"

        class Hello < Stationery::Document
          def view_template = text("Hello, world", size: 24, weight: :bold)
        end

        File.binwrite("hello.pdf", Hello.new.to_pdf)
        ```

        No fonts to configure: **Inter** (regular, bold, italic, bold italic) ships inside the gem and is
        used until you declare a `font_family`. See [Fonts](/docs/fonts) for your own families.
      MD
    end

    DocsUI::Section("to_pdf", description: "Bytes, a file, or any IO.") do
      md <<~'MD'
        ```ruby
        pdf = Hello.new.to_pdf              # => "%PDF-1.7…" (binary String)
        Hello.new.to_pdf("hello.pdf")       # also writes a path…
        Hello.new.to_pdf($stdout)           # …or anything that responds to #write
        Hello.new.to_pdf(strict: true)      # raise instead of writing when layout warned
        Hello.new.to_pdf(debug: true)       # outline every layout rectangle
        ```

        After a render, `document.warnings` lists everything the engine noticed but did not raise on — see
        [Warnings and strict mode](/docs/warnings).
      MD
    end

    DocsUI::Section("A real document", description: "Page setup, fonts, a page template, a table.") do
      md <<~'MD'
        ```ruby
        class InvoicePdf < Stationery::Document
          page size: :a4, margin: [40, 44, 56, 44]
          font_family "Inter", regular: "fonts/Inter-Regular.ttf", bold: "fonts/Inter-Bold.ttf"
          default_text font: "Inter", size: 9, color: "#1F2937"
          metadata title: "Invoice"

          page_template do |page|
            box(at: [44, page.height - 34], width: page.content_box.width) do
              text "Page #{page.number} of #{page.count}", size: 7, align: :right
            end
          end

          def initialize(invoice)
            super()
            @invoice = invoice
          end

          def view_template
            row(align: :middle) do
              column(width: 0.5) { text "Invoice #{@invoice.number}", size: 22, weight: :bold }
              column(width: 0.5, align: :right) { image "logo.png", height: 34, align: :right }
            end
            rule height: 3, color: "#4F46E5"
            spacer 18
            box(background: "#F3F4F6", radius: 6, padding: 12, width: 190) do
              text "AMOUNT DUE", size: 8, weight: :bold, letter_spacing: 0.5
              text @invoice.total, size: 19, weight: :bold, color: "#4F46E5"
            end
            table(@invoice.rows, width: :full, widths: [nil, 45, 80, 85], header: true, cell: { borders: [] }) do |t|
              t.row(0).set(background: "#4F46E5", color: "#FFFFFF", weight: :bold)
              t.columns(1..).align = :right
              t.zebra(from: 2, color: "#F9FAFB")
            end
          end
        end
        ```

        No cursor arithmetic anywhere: padding, backgrounds, borders, radii, column widths and page breaks
        are the engine's job. The [Cookbook](/docs/cookbook) walks through four complete documents.
      MD
    end

    DocsUI::Section("Render from the command line", description: "stationery render FILE.") do
      md <<~'MD'
        The gem ships a `stationery` executable. `render` loads a Ruby file, finds the
        `Stationery::Document` it defines and writes the PDF next to it:

        ```shell
        stationery render hello.rb                  # writes hello.pdf
        stationery render invoice.rb --out - > a.pdf
        ```

        A document whose `initialize` needs arguments renders from a `def self.preview` class method that
        returns an instance built with sample data. Every option is on the [CLI](/docs/cli) page.
      MD
    end

    DocsUI::Section("Where next") do
      md <<~'MD'
        - [Documents and components](/docs/documents-and-components) — class-level configuration and reusable pieces.
        - [Elements](/docs/elements) — every element and its options.
        - [Layout rules](/docs/layout-rules) — how measuring, splitting and pagination decide where things land.
      MD
    end
  end
end
