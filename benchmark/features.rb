# frozen_string_literal: true

# The documents the metrics gate renders for what a render does on a path of
# its own: a lossless WebP, `html` with a stylesheet, PDF/UA-1, pages written
# as they are painted and a shaper. Floats and columns are held by
# examples/article.rb and examples/newsletter.rb. They read nothing from
# outside the repository.
require_relative "documents"

module Bench
  # examples/assets/dunes.png as a lossless WebP (VP8L), 320 x 240 px:
  #   cwebp -lossless -z 9 examples/assets/dunes.png -o benchmark/assets/dunes.webp
  WEBP = File.expand_path("assets/dunes.webp", __dir__)

  # A stand-in for a native shaper, in Ruby: one glyph per character, as the
  # font's cmap names and advances them. It shapes nothing, and holds the path
  # a text takes through a shaper.
  module Shaper
    Glyph = Stationery::Shaper::Glyph

    module_function

    def call(text, face, **)
      ttf = Stationery::Fonts::Registry.load(face.index.zero? ? face.path : "#{face.path}##{face.index}")
      text.each_char.with_index.map do |char, index|
        gid = ttf.glyph_id(char.ord)
        Glyph.new(gid:, advance: ttf.advance(gid), cluster: index)
      end
    end
  end

  # A photo and two paragraphs. The gate empties the image cache before every
  # render of it, so the decoder runs in the render that is measured.
  class StationeryWebp < Stationery::Document
    page size: :a4, margin: 48
    font_family "Open Sans", regular: FONT, bold: FONT_BOLD
    default_text font: "Open Sans", size: 9.5

    def view_template
      text "Healthy Living", size: 16, weight: :bold
      image WEBP, width: 320, height: 240
      2.times { text PARAGRAPH }
    end
  end

  # What a CMS hands over: a stylesheet with element, class, id and compound
  # selectors, inline styles, a floated image, a table, lists and two columns,
  # six times over.
  class StationeryHtml < Stationery::Document
    STYLE = <<~CSS
      h1 { color: #0F766E; font-size: 20pt; margin-bottom: 4pt }
      h2 { color: #0F766E; font-size: 13pt; margin-top: 10pt; break-after: auto }
      p { text-align: justify; margin: 0 0 4pt 0 }
      p.lead { font-size: 11pt; color: #374151; font-style: italic }
      #dues { width: 100%; border: 1px solid #D1D5DB }
      th { background-color: #0F766E; color: #FFFFFF; font-weight: bold; padding: 4pt 6pt; text-align: left }
      td { padding: 4pt 6pt }
      td.n, th.n { text-align: right; width: 20% }
      td.n.total { font-weight: bold; color: #B45309 }
      .note { background-color: #FEF3C7; padding: 8pt; margin: 6pt 12pt; break-inside: avoid }
      .two { column-count: 2; column-gap: 14pt }
      a { color: #1D4ED8; text-decoration: underline }
      @media print { blockquote { color: #6B7280; padding: 2pt 0 } }
    CSS
    ROWS = [["Boats under 8 m", 120, 125], ["Boats of 8 to 12 m", 210, 218], ["Boats over 12 m", 340, 354],
            ["Visitors, a night", 18, 19], ["Winter storage", 460, 478]].freeze
    TABLE = ROWS.map do |name, before, now|
      "<tr><td>#{name}</td><td class=\"n\">#{before}</td><td class=\"n total\">#{now}</td></tr>"
    end.join
    SECTION = <<~HTML.freeze
      <h2>Harbour dues, part %<part>d</h2>
      <p class="lead">What the cooperative voted for in <b>March</b>, and what it <i>costs</i>.</p>
      <p><img src="stone.png" alt="The sandstone face of the wall" style="float: right; width: 96pt;
      margin: 0 0 6pt 12pt">#{PARAGRAPH} #{PARAGRAPH}</p>
      <table id="dues"><tr><th>Berth</th><th class="n">2026</th><th class="n">2027</th></tr>#{TABLE}</table>
      <div class="note"><p><b>Note.</b> Dues are paid at the <a href="https://example.com/harbour">customs
      house</a> before <u>the first of May</u>; <s>cheques</s> are no longer taken.</p></div>
      <div class="two"><p>#{PARAGRAPH}</p><ul><li>Bring the boat's papers</li><li>Bring last year's
      receipt<ol><li>the white copy</li><li>the stamp</li></ol></li></ul><p>#{PARAGRAPH}</p></div>
      <blockquote><p style="font-size: 9pt; text-align: right">Nobody voted against.</p></blockquote>
      <hr>
    HTML
    BODY = "<style>#{STYLE}</style><h1>The Harbour Letter</h1>" \
           "#{Array.new(6) { |part| format(SECTION, part: part + 1) }.join}".freeze

    page size: :a4, margin: 48
    font_family "Open Sans", regular: FONT, bold: FONT_BOLD, italic: FONT, bold_italic: FONT_BOLD
    default_text font: "Open Sans", size: 9.5

    def view_template
      html BODY, base_path: ASSETS
    end
  end

  # A tagged report under PDF/UA-1: headings in order, paragraphs, a list, a
  # figure with a description, a link and a table of 120 rows whose header
  # repeats, with a footer on every page.
  class StationeryAccessible < Stationery::Document
    ROWS = [TABLE_HEADER, *TABLE_ROWS.first(120)].freeze

    page size: :a4, margin: 48
    font_family "Open Sans", regular: FONT, bold: FONT_BOLD
    default_text font: "Open Sans", size: 9.5
    metadata title: "Orders by customer", author: "stationery benchmark", lang: "en"
    conformance :pdf_ua1
    footer { |page| text "Page #{page.number} of #{page.count}", size: 7, align: :right }

    def view_template
      text "Orders by customer", size: 20, weight: :bold, heading: 1
      image COVER, width: 499, height: 160, fit: :cover, alt: "Dunes under a clear sky"
      4.times { |section| section(section + 1) }
      text "Every order", size: 14, weight: :bold, heading: 2
      table(ROWS, header: true, width: :full) { |t| t.row(0).weight = :bold }
    end

    private

    def section(number)
      text "Quarter #{number}", size: 14, weight: :bold, heading: 2
      2.times { text PARAGRAPH, align: :justify, hyphenate: true }
      ul { 3.times { |item| li "Region #{item + 1}: #{PARAGRAPH[0, 58]}" } }
      text "The figures are published at example.com.", link: "https://example.com/orders/#{number}"
    end
  end

  # The text document with a footer, which is painted once every page is
  # known: written incrementally, the body of a page leaves before its footer
  # is painted.
  class StationeryIncremental < StationeryText
    incremental
    footer { |page| text "Page #{page.number} of #{page.count}", size: 7, align: :right }
  end

  # The text document, every stretch of it through a shaper.
  class StationeryShaped < StationeryText
    shaper Shaper
  end
end
