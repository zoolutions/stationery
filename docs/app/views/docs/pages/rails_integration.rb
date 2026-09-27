# frozen_string_literal: true

class Views::Docs::Pages::RailsIntegration < DocsUI::Page
  title "Rails"
  eyebrow "Integrations"

  def lead = "render pdf:, send_pdf, previews like ActionMailer's, a font generator — and no Rails dependency in the gem."

  def content
    controller, previews = SourceMarkdown.readme_section("Rails").split("### Previews\n", 2)

    DocsUI::Section("Controllers and configuration", description: "From the README.") do
      md controller
    end

    DocsUI::Section("send_pdf", description: "Without the renderer.") do
      md <<~'MD'
        `Stationery::Rails#send_pdf(document, filename:, disposition: "inline", type: "application/pdf")` is
        what `render pdf:` calls. Outside the Railtie (or with `config.stationery.renderer = false`, keeping
        wicked_pdf's `render pdf:`), include it yourself:

        ```ruby
        class InvoicesController < ApplicationController
          include Stationery::Rails

          def show = send_pdf(InvoicePdf.new(@invoice), filename: "invoice-#{@invoice.number}.pdf")
        end
        ```
      MD
    end

    DocsUI::Section("Previews", description: "One public method per sample document.") do
      md previews
    end

    DocsUI::Section("Font generator", description: "stationery:fonts.") do
      md <<~'MD'
        ```shell
        bin/rails generate stationery:fonts noto_sans liberation_serif
        ```

        Installs the packs into `vendor/fonts/<pack>/` — the directory the Railtie adds to
        `Stationery.font_paths` — so `font_family "Noto Sans"` needs no paths. Commit the files; nothing is
        downloaded at runtime. See [Fonts](/docs/fonts#font-packs).
      MD
    end

    DocsUI::Section("Mailers, jobs and ActiveStorage", description: "to_pdf returns bytes — use them anywhere.") do
      md <<~'MD'
        `to_pdf` returns the PDF as a binary String, so the same document class serves mailers, background
        jobs and storage:

        ```ruby
        class InvoiceMailer < ApplicationMailer
          def issued(invoice)
            attachments["invoice-#{invoice.number}.pdf"] = InvoicePdf.new(invoice).to_pdf
            mail to: invoice.customer.email, subject: "Invoice #{invoice.number}"
          end
        end

        class ArchiveInvoiceJob < ApplicationJob
          def perform(invoice)
            invoice.pdf.attach(io: StringIO.new(InvoicePdf.new(invoice).to_pdf),
                               filename: "invoice-#{invoice.number}.pdf", content_type: "application/pdf")
          end
        end
        ```

        Pass `strict: true` in jobs that must never store a PDF with layout problems.
      MD
    end
  end
end
