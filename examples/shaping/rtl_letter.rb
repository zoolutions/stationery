# frozen_string_literal: true

# A letter in Arabic, right to left, shaped by HarfBuzz through the shaper
# hook: joined letters, marks placed over them, and runs of Latin text and
# digits kept in reading order inside a right-to-left line. Stationery does not
# shape text itself, so this one needs what the gem does not ship: the
# harfbuzz-ruby gem with the HarfBuzz library (see harfbuzz_shaper.rb beside
# it) and a font with the Arabic script, named by ARABIC_FONT:
#
#   gem install harfbuzz-ruby    # with `brew install harfbuzz` or `apt-get install libharfbuzz-dev`
#   ARABIC_FONT=NotoNaskhArabic-Regular.ttf ruby -Ilib examples/shaping/rtl_letter.rb
#   ARABIC_FONT=NotoNaskhArabic-Regular.ttf ruby -Ilib exe/stationery render examples/shaping/rtl_letter.rb
#
# It is left out of `rake examples`, the docs site and CI, which have neither.
begin
  require_relative "harfbuzz_shaper"
rescue LoadError => e
  abort "examples/shaping/rtl_letter.rb needs the harfbuzz-ruby gem and the HarfBuzz library " \
        "(gem install harfbuzz-ruby): #{e.message}"
end
require "stationery"

class ExampleRtlLetter < Stationery::Document
  FONT = ENV.fetch("ARABIC_FONT") do
    abort "set ARABIC_FONT to a font with the Arabic script, e.g. ARABIC_FONT=NotoNaskhArabic-Regular.ttf"
  end
  ACCENT = "#065F46"
  INK = "#111827"
  MUTED = "#6B7280"

  page size: :a4, margin: [64, 64, 56, 64]
  metadata title: "رسالة تأكيد الحجز", author: "Example Travel", lang: "ar", creator: "stationery example"

  # Every stretch of text goes through the shaper, which answers glyphs in
  # visual order; the Arabic font draws what it has, Inter the rest.
  shaper HarfBuzzShaper.new
  font_family "Arabic", regular: FONT
  font_fallbacks "Inter"
  default_text font: "Arabic", size: 13, color: INK, align: :right, leading: 6

  footer do
    rule height: 0.5, color: "#D1D5DB"
    spacer 6
    text "Example Travel · booking@travel.example · +971 4 000 0000", size: 9, color: MUTED, align: :center
  end

  def self.preview
    new(name: "سارة", booking: "EX-2026-7781", hotel: "فندق الواحة", nights: "٣", total: "٢٤٠٠ درهم")
  end

  def initialize(name:, booking:, hotel:, nights:, total:)
    super()
    @name = name
    @booking = booking
    @hotel = hotel
    @nights = nights
    @total = total
  end

  def view_template
    row(align: :bottom) do
      column { text "٢٩ سبتمبر ٢٠٢٦", size: 11, color: MUTED, align: :left }
      column { text "Example Travel", size: 20, color: ACCENT }
    end
    spacer 10
    rule height: 2, color: ACCENT
    spacer 24
    text "تأكيد الحجز", size: 22, color: ACCENT
    spacer 14
    text "عزيزتي #{@name}،"
    spacer 8
    # Arabic with Arabic-Indic digits is one stretch of one font, which the
    # shaper orders right to left, across as many lines as it takes.
    text "يسعدنا أن نؤكد حجزك في #{@hotel} لمدة #{@nights} ليالٍ، من ١٢ إلى ١٥ أكتوبر ٢٠٢٦. " \
         "المبلغ الإجمالي #{@total} شاملاً الضرائب والإفطار. يمكنك إلغاء الحجز مجاناً حتى ٤٨ ساعة قبل الوصول."
    spacer 14
    booking
    spacer 14
    text "يرجى ذكر رقم الحجز في كل مراسلاتك معنا. نتمنى لك إقامة سعيدة."
    spacer 30
    text "مع أطيب التحيات،"
    text "فريق السفر", color: ACCENT
  end

  private

  # Latin text drawn from Inter is a stretch of its own, and stretches are
  # placed left to right in the order written (the hook has no bidi across
  # fonts): a line that mixes the two directions is built from columns, the
  # first on the right.
  def booking
    box(background: "#ECFDF5", radius: 6, padding: [10, 14]) do
      row(align: :middle) do
        column { text @booking, font: "Inter", size: 14, align: :left, color: ACCENT }
        column { text "رقم الحجز", size: 12, color: MUTED }
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  letter = ExampleRtlLetter.preview
  letter.to_pdf(File.expand_path("rtl_letter.pdf", __dir__))
  warn letter.warnings.map(&:message) if letter.warnings.any?
  puts "wrote examples/shaping/rtl_letter.pdf"
end
