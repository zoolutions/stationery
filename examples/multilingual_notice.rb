# frozen_string_literal: true

# A notice to residents in English, German and Swedish side by side, each
# column justified and hyphenated by the patterns of its own language, with
# a Japanese paragraph when a CJK font is at hand. Run it to write
# examples/multilingual_notice.pdf:
#
#   ruby -Ilib examples/multilingual_notice.rb
#   ruby -Ilib exe/stationery render examples/multilingual_notice.rb
#
# Inter, the font the gem bundles, has Latin, Greek and Cyrillic but no CJK
# ideographs, and no font pack has them either. Name a font that has them to
# add the Japanese paragraph; it is registered as a fallback, so it draws only
# the characters Inter lacks, and the lines break between ideographs:
#
#   CJK_FONT=/path/to/NotoSansJP-Regular.ttf ruby -Ilib examples/multilingual_notice.rb
require "stationery"

class ExampleMultilingualNotice < Stationery::Document
  ACCENT = "#0E7490"
  INK = "#111827"
  MUTED = "#6B7280"
  PANEL = "#ECFEFF"
  CJK_FONT = ENV.fetch("CJK_FONT", nil)

  # Each language with the hyphenation patterns to break its words by:
  # `true` is American English, "de" German and "sv" Swedish.
  NOTICES = [
    ["English", true, "Water will be turned off",
     ["The water supply to every flat in the building will be turned off on Tuesday 14 October between " \
      "08:00 and 16:00 while the main distribution pipes in the basement are replaced.",
      "Please fill a few containers with drinking water beforehand and keep the taps closed during the " \
      "work. Discoloured water may run for a short while afterwards; let the cold tap run until it is clear."]],
    ["Deutsch", "de", "Das Wasser wird abgestellt",
     ["Am Dienstag, dem 14. Oktober, wird die Wasserversorgung aller Wohnungen im Gebäude zwischen 08:00 " \
      "und 16:00 Uhr unterbrochen, da die Hauptverteilungsleitungen im Keller erneuert werden.",
      "Bitte füllen Sie vorher einige Behälter mit Trinkwasser und lassen Sie die Wasserhähne während der " \
      "Arbeiten geschlossen. Danach kann das Wasser kurzzeitig verfärbt sein; lassen Sie das kalte Wasser " \
      "laufen, bis es klar ist."]],
    ["Svenska", "sv", "Vattnet stängs av",
     ["Tisdagen den 14 oktober stängs vattnet av i alla lägenheter i huset mellan klockan 08.00 och 16.00, " \
      "medan huvudledningarna i källaren byts ut.",
      "Fyll gärna några kärl med dricksvatten i förväg och håll kranarna stängda under arbetet. Efteråt kan " \
      "vattnet vara missfärgat en kort stund; spola kallvatten tills det är klart."]]
  ].freeze

  JAPANESE = "10月14日（火）8時から16時まで、地下の給水管の交換工事のため、建物内のすべての住戸で断水します。" \
             "事前に飲料水をご用意いただき、工事中は蛇口を閉めておいてください。工事後、しばらく濁った水が出ることが" \
             "ありますので、透明になるまで水を流してください。"

  page size: :a4, margin: [52, 48, 44, 48]
  default_text font: "Inter", size: 10.5, color: INK, leading: 3
  metadata title: "Notice to residents", author: "Example Housing Cooperative", creator: "stationery example"

  # A font for what Inter lacks: drawn only where Inter has no glyph.
  if CJK_FONT
    font_family "CJK", regular: CJK_FONT
    font_fallbacks "CJK"
  end

  def self.preview = new

  def view_template
    text "NOTICE · HINWEIS · MEDDELANDE", size: 9, weight: :bold, color: ACCENT, letter_spacing: 2
    spacer 6
    text "Harbour View Housing Cooperative, 1–5 Example Street", size: 10, color: MUTED
    spacer 8
    rule height: 2, color: ACCENT
    spacer 16
    row(gap: 18) do
      NOTICES.each do |language, hyphenate, title, paragraphs|
        column { notice(language, hyphenate, title, paragraphs) }
      end
    end
    spacer 18
    japanese
    spacer 18
    contact
  end

  private

  def notice(language, hyphenate, title, paragraphs)
    text language.upcase, size: 7.5, weight: :bold, color: MUTED, letter_spacing: 1
    spacer 4
    text title, size: 15, weight: :bold, color: ACCENT
    spacer 6
    paragraphs.each do |paragraph|
      text paragraph, align: :justify, hyphenate: hyphenate
      spacer 6
    end
  end

  def japanese
    box(background: PANEL, radius: 6, padding: 12) do
      text "JAPANESE", size: 7.5, weight: :bold, color: MUTED, letter_spacing: 1
      spacer 4
      if CJK_FONT
        text JAPANESE, leading: 4 # Inter for the digits, the CJK font for the rest
      else
        text "Japanese: set CJK_FONT to a font with Japanese glyphs to include this paragraph. Inter, the " \
             "font in the gem, has none; see the comment at the top of examples/multilingual_notice.rb.",
             size: 8.5, color: MUTED
      end
    end
  end

  def contact
    rule color: "#E5E7EB"
    spacer 6
    text "Questions · Fragen · Frågor: caretaker@harbour-view.example · +46 31 000 00 00",
         size: 8.5, color: MUTED, align: :center
  end
end

if $PROGRAM_NAME == __FILE__
  notice = ExampleMultilingualNotice.preview
  notice.to_pdf(File.expand_path("multilingual_notice.pdf", __dir__))
  warn notice.warnings.map(&:message) if notice.warnings.any?
  puts "wrote examples/multilingual_notice.pdf"
end
