# frozen_string_literal: true

# A one-page business letter with a vector letterhead. Run it to write
# examples/letter.pdf:
#
#   ruby -Ilib examples/letter.rb
#   ruby -Ilib exe/stationery render examples/letter.rb
require "stationery"

class ExampleLetter < Stationery::Document
  ACCENT = "#B45309"
  INK = "#1C1917"
  MUTED = "#78716C"
  HAIRLINE = "#E7E5E4"
  LOGO = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40">
      <rect width="40" height="40" rx="9" fill="#B45309"/>
      <path d="M11 28V12l9 10 9-10v16" fill="none" stroke="#FFFFFF" stroke-width="3.2"
            stroke-linecap="round" stroke-linejoin="round"/>
      <circle cx="20" cy="31" r="2.2" fill="#FDE68A"/>
    </svg>
  SVG

  page size: :a4, margin: [48, 64, 40, 64]
  default_text size: 10.5, color: INK
  metadata title: "Letter to Hallberg Bygg AB", author: "Mälaren Studio AB", creator: "stationery example"

  footer do
    rule height: 0.5, color: HAIRLINE
    spacer 6
    text "Mälaren Studio AB · Org. nr 559123-4567 · VAT SE559123456701 · Registered office Västerås, Sweden",
         size: 7.5, color: MUTED, align: :center
  end

  def self.preview
    new(recipient: ["Ms Anna Hallberg", "Hallberg Bygg AB", "Kungsgatan 12", "753 21 Uppsala"],
        date: "27 September 2026", reference: "Proposal MS-2026-118")
  end

  def initialize(recipient:, date:, reference:)
    super()
    @recipient = recipient
    @date = date
    @reference = reference
  end

  def view_template
    letterhead
    spacer 56
    row do
      column(width: 0.6) { text @recipient.join("\n"), leading: 2 }
      column(width: 0.4) { text "Västerås, #{@date}\nOur ref. #{@reference}", color: MUTED, align: :right, leading: 2 }
    end
    spacer 40
    text "Proposal for the redesign of your customer portal", size: 12, weight: :bold
    spacer 16
    body
    spacer 28
    signature
  end

  private

  def letterhead
    row(align: :middle, gap: 12) do
      column(width: 40) { svg LOGO, width: 40 }
      column do
        text "Mälaren Studio", size: 15, weight: :bold
        text "Stora Gatan 21, 722 12 Västerås", size: 8.5, color: MUTED
      end
      column(width: 160) do
        text_style(size: 8.5, color: MUTED, align: :right, leading: 1.5) do
          text "+46 21 123 45 67"
          text "hello@malaren.studio"
          text "malaren.studio"
        end
      end
    end
    spacer 12
    rule height: 2, color: ACCENT
  end

  def body
    text_style(align: :justify, leading: 4) do
      [
        "Dear Ms Hallberg,",
        "Thank you for meeting us in Uppsala last week and for walking us through the way your site managers " \
        "use the customer portal today. It was clear that the portal holds the right information but makes it " \
        "hard to find: most of the questions your office answers by phone are already answered somewhere in it.",
        "We propose a redesign in <b>three phases over twelve weeks</b>. The first phase maps the ten most " \
        "common tasks with your customers and staff; the second turns them into a clickable prototype that we " \
        "test on site; the third delivers the finished design and supports your developers while they build it.",
        "The fixed price for all three phases is <b>SEK 480,000</b> excluding VAT, invoiced at the end of each " \
        "phase. The full proposal, with the schedule and the people involved, is available at " \
        "<link href='https://malaren.studio/p/MS-2026-118'><color rgb='#{ACCENT}'><u>malaren.studio/p/MS-2026-118</u>" \
        "</color></link>.",
        "We would be glad to start in the week of 2 November. If you have any questions, or would like to " \
        "adjust the scope, please call me directly on the number above."
      ].each_with_index do |paragraph, index|
        spacer 10 if index.positive?
        text paragraph, markup: true
      end
    end
  end

  def signature
    group(keep_together: true) do
      text "Kind regards,"
      spacer 30
      text "Erik Sandberg", weight: :bold
      text "Creative Director, Mälaren Studio AB", color: MUTED, size: 9.5
    end
  end
end

if $PROGRAM_NAME == __FILE__
  letter = ExampleLetter.preview
  letter.to_pdf(File.expand_path("letter.pdf", __dir__))
  warn letter.warnings.map(&:message) if letter.warnings.any?
  puts "wrote examples/letter.pdf"
end
