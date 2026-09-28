# frozen_string_literal: true

# A one-page newsletter: a masthead across the page, an article poured
# through two balanced columns with headings and a photo, and a footer note
# across the page below the columns.
# Run it to write examples/newsletter.pdf:
#
#   ruby -Ilib examples/newsletter.rb
#   ruby -Ilib exe/stationery render examples/newsletter.rb
require "stationery"

class ExampleNewsletter < Stationery::Document
  ASSETS = File.expand_path("assets", __dir__)
  INK = "#1F2937"
  MUTED = "#6B7280"
  ACCENT = "#0F766E"
  LINE = "#D1D5DB"

  ARTICLE = [
    [nil, ["The harbour wall that has kept the winter swell out of the village since 1911 was reopened on " \
           "Saturday, eighteen months after a storm took forty metres of it into the bay. Two hundred people " \
           "walked its length behind the brass band, and the first boat through the gap was the oldest in the " \
           "fleet.",
           "The rebuilt section stands a metre higher than the old one. Its core is concrete, but the face is " \
           "the original sandstone: divers recovered nine blocks in ten from the seabed, and the quarry above " \
           "the village was opened for a month to cut the rest."]],
    ["What it cost", ["The work came to 2.4 million, a third of it raised by the village itself. The harbour " \
                      "dues will rise by four per cent a year until 2031 to repay the loan, a rise the " \
                      "fishing cooperative voted for without a single vote against.",
                      "Nothing was spent on the lighthouse, which needs a new lantern. The council has asked " \
                      "for tenders and expects to decide in the spring."]],
    ["What comes next", ["The inner quay is next. Its timber piles date from the fifties and the survey gives " \
                         "them ten years at most. Plans go on show in the old customs house in March, and " \
                         "the council wants comments before the summer.",
                         "Until then the wall is open to walkers from dawn to dusk. The gate at the landward " \
                         "end is locked in any wind above force seven."]]
  ].freeze

  page size: :a4, margin: 48
  default_text size: 10, color: INK, leading: 2.5
  metadata title: "The Harbour Letter", author: "stationery example", lang: "en"
  tagged

  def self.preview = new

  def view_template
    masthead
    columns(count: 2, gap: 22, rule: { color: LINE }) { article }
    note
  end

  private

  def masthead
    text "THE HARBOUR LETTER", size: 9, weight: :bold, color: ACCENT, letter_spacing: 1.5
    spacer 6
    text "The sea wall is whole again", size: 30, weight: :bold, leading: 0, heading: 1
    spacer 6
    text "Issue 42 · October 2026", size: 9, color: MUTED
    spacer 10
    rule height: 2, color: ACCENT
    spacer 16
  end

  def article
    ARTICLE.each_with_index do |(title, paragraphs), index|
      section_heading(title) if title
      paragraphs.each { |paragraph| body(paragraph) }
      photo if index.zero?
    end
  end

  def section_heading(title)
    text title, size: 13, weight: :bold, color: ACCENT, leading: 0, heading: 2, keep_with_next: true
    spacer 5
  end

  def body(paragraph)
    text paragraph, align: :justify, hyphenate: true, orphans: 2, widows: 2
    spacer 8
  end

  def photo
    group(keep_together: true) do
      image File.join(ASSETS, "bay.png"), width: 1.0, height: 120, fit: :cover, radius: 6,
                                          alt: "The bay seen from the rebuilt wall"
      spacer 4
      text "The bay from the new section of the wall.", size: 8, color: MUTED, style: :italic
    end
    spacer 8
  end

  def note
    spacer 16
    rule color: LINE
    spacer 8
    text "The Harbour Letter is written by volunteers and printed by the cooperative. Letters to the " \
         "editor are welcome at the customs house, where back issues are kept.",
         size: 8.5, color: MUTED, align: :center
  end
end

if $PROGRAM_NAME == __FILE__
  newsletter = ExampleNewsletter.preview
  newsletter.to_pdf(File.expand_path("newsletter.pdf", __dir__))
  warn newsletter.warnings.map(&:message) if newsletter.warnings.any?
  puts "wrote examples/newsletter.pdf"
end
