# frozen_string_literal: true

# A magazine page: justified text wrapping around a floated photo, a pull
# quote floated to the right and a snapshot floated by CSS inside `html`.
# Run it to write examples/article.pdf:
#
#   ruby -Ilib examples/article.rb
#   ruby -Ilib exe/stationery render examples/article.rb
require "stationery"

class ExampleArticle < Stationery::Document
  ASSETS = File.expand_path("assets", __dir__)
  INK = "#1F2937"
  MUTED = "#6B7280"
  ACCENT = "#B45309"
  WASH = "#FEF3C7"

  PARAGRAPHS = [
    "The road to the bay ends where the asphalt does. From there a track of red earth runs between dry-stone " \
    "walls, past a shuttered farm and a row of prickly pears, and then the land simply stops: a shelf of pale " \
    "rock, the water beyond it green over sand and blue over weed. Nobody built anything here. The nearest " \
    "village is an hour away on foot, and it has never been in a hurry to come closer.",
    "We walked out in the cool of the morning with bread, tomatoes and two litres of water each. The shepherd " \
    "we met at the last gate counted us, counted the bottles, and let us through with a nod. By ten the sun " \
    "was over the ridge and the cicadas had started; by eleven the only shade on the whole shore was the one " \
    "we carried with us, a square of canvas on four driftwood poles.",
    "What strikes a visitor from the north is how little the place asks of you. There is no path to follow " \
    "and no view to find, because the view is everywhere. You swim, you dry, you read a page and lose your " \
    "place. The afternoon wind arrives at three, as it has every day since May, and turns the bay from glass " \
    "to hammered pewter in the time it takes to look up.",
    "On the way back the shepherd was waiting with a bag of figs. He would not take money for them. He asked " \
    "instead whether the water had been cold, and when we said no, not at all, he laughed and said that it " \
    "would be by November, and that November was the month to come."
  ].freeze

  NOTES = <<~HTML
    <h3>Getting there</h3>
    <p><img src="stone.png" alt="A sandstone wall beside the track" style="float: right; width: 96pt;
    margin: 0 0 6pt 12pt">Leave the car at the last farm and carry what you need: there is no water on the
    shore and no shade before the evening. The track is easy underfoot, but it is an hour each way and the
    walls beside it keep the wind out. Start before eight, turn back by five, and close every gate behind
    you.</p>
  HTML

  page size: :a4, margin: [64, 72]
  default_text size: 10.5, color: INK, leading: 3, hyphenate: :en
  metadata title: "An hour from the road", author: "stationery example", lang: "en"
  tagged

  def self.preview = new

  def view_template
    text "TRAVEL", size: 8, weight: :bold, color: ACCENT, letter_spacing: 1.5
    text "An hour from the road", size: 28, weight: :bold, heading: 1, leading: 0
    text "A bay in the south of Sardinia that the asphalt never reached", size: 12, color: MUTED
    spacer 8
    rule height: 2, color: ACCENT, width: 48
    spacer 14
    story
    spacer 6
    html NOTES, base_path: ASSETS, styles: { h3: { color: ACCENT } }
  end

  private

  # The photo floats left at the top of the first paragraph; the pull quote
  # floats right where it is written, between the second and the third.
  def story
    group(gap: 9) do
      image photo("sea"), float: :left, width: 0.42, margin: { right: 14, bottom: 8 }, radius: 6,
                          alt: "The bay from the last gate, early in the morning"
      PARAGRAPHS.first(2).each { |paragraph| text paragraph, align: :justify }
      pull_quote "There is no path to follow and no view to find, because the view is everywhere."
      PARAGRAPHS.drop(2).each { |paragraph| text paragraph, align: :justify }
    end
  end

  def pull_quote(words)
    box(float: :right, width: 170, margin: { left: 16, bottom: 6 }, padding: [10, 12], background: WASH,
        border: { sides: [:left], width: 3, color: ACCENT }, role: :blockquote) do
      text words, size: 13, style: :italic, color: ACCENT, leading: 2, hyphenate: nil
    end
  end

  def photo(name) = File.join(ASSETS, "#{name}.png")
end

if $PROGRAM_NAME == __FILE__
  article = ExampleArticle.preview
  article.to_pdf(File.expand_path("article.pdf", __dir__))
  warn article.warnings.map(&:message) if article.warnings.any?
  puts "wrote examples/article.pdf"
end
