# frozen_string_literal: true

# A services agreement over several pages: numbered clauses whose headings
# stay with their text, a box for both parties' initials in the footer of
# every page, and signature fields for a digital signature. Run it to write
# examples/contract.pdf:
#
#   ruby -Ilib examples/contract.rb
#   ruby -Ilib exe/stationery render examples/contract.rb
#
# Signing happens when the file is written, with a certificate and its key;
# `field:` names the signature field that carries the signature:
#
#   ExampleContract.preview.to_pdf("contract.pdf",
#     sign: { certificate: File.read("provider.crt"), key: File.read("provider.key"),
#             field: "signature.provider", reason: "Agreed", location: "Gothenburg" })
require "stationery"

class ExampleContract < Stationery::Document
  INK = "#111827"
  MUTED = "#6B7280"
  HAIRLINE = "#D1D5DB"

  CLAUSES = [
    ["Definitions", ["“Services” means the development, hosting and support of the Client's delivery-tracking " \
                     "application described in Schedule 1.",
                     "“Business Day” means a day other than a Saturday, a Sunday or a public holiday in Sweden.",
                     "Headings are for convenience only and do not affect how this Agreement is read."]],
    ["Term", ["This Agreement starts on the Effective Date and runs for twenty-four months.",
              "It renews for further periods of twelve months unless either party gives written notice at " \
              "least ninety days before the end of the current period."]],
    ["Services", ["The Provider shall perform the Services with reasonable skill and care, in line with good " \
                  "industry practice, and through personnel who are suitably qualified.",
                  "The Provider shall keep the application available 99.5 per cent of each calendar month, " \
                  "measured as set out in Schedule 2, excluding maintenance announced five Business Days ahead.",
                  "Changes to the Services are agreed in writing through the change procedure in Schedule 3."]],
    ["Fees and payment", ["The Client shall pay the fees set out in Schedule 4, monthly in arrears, within " \
                          "thirty days of the date of each invoice.",
                          "Fees are exclusive of value added tax, which the Client pays at the rate in force.",
                          "Late payments carry interest at the reference rate of the Riksbank plus eight " \
                          "percentage points."]],
    ["Intellectual property", ["Each party keeps the rights it owned before the Effective Date.",
                               "Rights in work made for the Client under this Agreement pass to the Client when " \
                               "it has been paid for. The Provider keeps its general tools and know-how."]],
    ["Confidentiality", ["Each party shall keep the other's confidential information secret and use it only " \
                         "to perform this Agreement.",
                         "This clause survives the end of the Agreement for five years."]],
    ["Data protection", ["Where the Provider processes personal data for the Client, it does so as processor " \
                         "under the data processing agreement in Schedule 5, which forms part of this Agreement."]],
    ["Liability", ["Neither party is liable for indirect loss, loss of profit or loss of data, except in the " \
                   "case of gross negligence or wilful misconduct.",
                   "Each party's total liability in a contract year is limited to the fees paid in that year."]],
    ["Termination", ["Either party may terminate this Agreement with immediate effect if the other commits a " \
                     "material breach and does not remedy it within thirty days of written notice.",
                     "On termination the Provider shall hand over the Client's data in a common machine-readable " \
                     "format and then delete it."]],
    ["Governing law and disputes", ["This Agreement is governed by Swedish law.",
                                    "Disputes are finally settled by arbitration under the Rules for Expedited " \
                                    "Arbitrations of the SCC Arbitration Institute, seated in Gothenburg."]]
  ].freeze

  page size: :a4, margin: [56, 64, 48, 64]
  default_text size: 10, color: INK, leading: 2.5
  metadata title: "Services agreement", author: "Example Software AB", creator: "stationery example"

  # Every page carries a box for each party's initials: a text field per
  # party and page, named after the page (`initials.provider.3`) so that each
  # is a field of its own. The frame is a box around the field, so it prints
  # in viewers that redraw empty fields without their border.
  footer(gap: 16) do |page|
    row(align: :middle, gap: 12) do
      column { text "Services agreement · page #{page.number} of #{page.count}", size: 8, color: MUTED }
      column(width: :auto) { text "Initials", size: 8, color: MUTED }
      %w[provider client].each do |party|
        column(width: 44) do
          box(border: { color: MUTED, width: 0.75 }, radius: 3) do
            text_field "initials.#{party}.#{page.number}", height: 20, tooltip: "Initials of the #{party}",
                                                           border: nil, background: nil
          end
        end
      end
    end
  end

  def self.preview
    new(provider: ["Example Software AB", "Org. no. 556000-0000", "Storgatan 1, 411 00 Gothenburg"],
        client: ["Sample Freight Ltd", "Company no. 00000000", "1 Test Street, Testville"],
        date: "1 October 2026")
  end

  def initialize(provider:, client:, date:)
    super()
    @provider = provider
    @client = client
    @date = date
  end

  def view_template
    text "Services agreement", size: 22, weight: :bold
    spacer 4
    text "Effective Date: #{@date}", color: MUTED
    spacer 16
    parties
    spacer 10
    CLAUSES.each_with_index { |(title, paragraphs), index| clause(index + 1, title, paragraphs) }
    signatures
  end

  private

  def parties
    text "This Agreement is made between:"
    spacer 6
    row(gap: 24) do
      column { party("THE PROVIDER", @provider) }
      column { party("THE CLIENT", @client) }
    end
  end

  def party(label, lines)
    text label, size: 7.5, weight: :bold, color: MUTED, letter_spacing: 0.6
    text "<b>#{lines.first}</b>\n#{lines.drop(1).join("\n")}", markup: true, size: 9.5
  end

  # "3. Services" and its sub-clauses 3.1, 3.2, …: the heading keeps at least
  # 50 points of what follows on its page, so it never ends one alone.
  def clause(number, title, paragraphs)
    spacer 12
    text "#{number}. #{title}", size: 11.5, weight: :bold, keep_with_next: 50, bookmark: title
    spacer 4
    paragraphs.each_with_index do |paragraph, index|
      row(gap: 8) do
        column(width: 30) { text "#{number}.#{index + 1}", color: MUTED }
        column { text paragraph, align: :justify, hyphenate: true }
      end
      spacer 4
    end
  end

  # Kept together, so both parties sign on one page.
  def signatures
    spacer 24
    group(keep_together: true) do
      text "Signed by the parties on the dates written below their signatures.", keep_with_next: true
      spacer 30
      row(gap: 40) do
        column { signature_field "signature.provider", label: "For #{@provider.first}", height: 48 }
        column { signature_field "signature.client", label: "For #{@client.first}", height: 48 }
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  contract = ExampleContract.preview
  contract.to_pdf(File.expand_path("contract.pdf", __dir__))
  warn contract.warnings.map(&:message) if contract.warnings.any?
  puts "wrote examples/contract.pdf"
end
