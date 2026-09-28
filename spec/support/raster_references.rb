# frozen_string_literal: true

# Small documents whose pictures (Document#to_png) are held to what poppler
# draws from their PDFs, stored in spec/fixtures/raster as PNGs. Recorded
# with pdftoppm installed:
#
#   bundle exec ruby -Ilib -Ispec spec/support/raster_references.rb
#
# A picture passes when few of its pixels differ from poppler's by more than
# THRESHOLD in any channel: text is hinted and placed a little differently,
# so a tolerance, not equal bytes.
module RasterReferences
  DIRECTORY = File.expand_path("../fixtures/raster", __dir__)
  THRESHOLD = 64

  GRADIENT = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 260 160">
      <defs>
        <linearGradient id="a"><stop offset="0" stop-color="#0EA5E9"/><stop offset="1" stop-color="#DC2626"/></linearGradient>
        <radialGradient id="b" fx="0.3" fy="0.3"><stop offset="0" stop-color="#FFFFFF"/>
          <stop offset="1" stop-color="#0F172A"/></radialGradient>
      </defs>
      <rect x="0" y="0" width="160" height="50" rx="10" fill="url(#a)"/>
      <circle cx="210" cy="50" r="45" fill="url(#b)"/>
      <path d="M 20 70 l 30 80 l -70 -50 h 80 l -70 50 z" transform="translate(40 0)" fill="#2563EB"
            fill-rule="evenodd"/>
      <path d="M 120 90 L 250 90" stroke="#16A34A" stroke-width="6" stroke-linecap="round" stroke-dasharray="12 8"/>
      <path d="M 120 110 L 250 130 L 120 150" fill="none" stroke="#111827" stroke-width="5"/>
    </svg>
  SVG

  DOCUMENTS = {
    "text_and_boxes" => [lambda {
      SpecDocument.build do
        text "Pictures of a render", size: 18, weight: :bold, color: "#0F766E"
        text "The quick brown fox jumps over the lazy dog, twice: the quick brown fox jumps over the lazy dog."
        spacer 6
        row(gap: 8) do
          box(background: "#FDE68A", radius: 8, padding: 6) { text "rounded" }
          box(border: { width: 1, color: "#1D4ED8" }, padding: 6) { text "bordered" }
          box(background: "#111827", padding: 6, rotate: 4) { text "rotated", color: "#FFFFFF" }
        end
      end
    }, { dpi: 72 }],
    "gradients" => [-> { SpecDocument.build { svg GRADIENT, width: 260 } }, { dpi: 72 }],
    "monochrome" => [lambda {
      SpecDocument.build do
        text "SKU 4711-A", size: 20, weight: :bold
        rule height: 0.5, color: "#000000"
        text "Hex bolt M8 x 40, zinc plated", size: 10
        box(border: { width: 1, color: "#000000" }, radius: 4, padding: 4) { text "Bin C-07", size: 9 }
      end
    }, { monochrome: { dpi: 203, snap: true } }]
  }.freeze

  module_function

  def path(name) = File.join(DIRECTORY, "#{name}.png")

  def render(name)
    build, options = DOCUMENTS.fetch(name)
    build.call.to_png(**options).first
  end

  # The share of pixels of `ours` differing from `reference` (PNG Strings
  # of the same size) by more than THRESHOLD.
  def difference(ours, reference)
    a = Stationery::Images::PNG.new(ours).pixels
    b = Stationery::Images::PNG.new(reference).pixels
    raise ArgumentError, "sizes differ" unless [a.width, a.height] == [b.width, b.height]

    ours, theirs = [a, b].map { |pixels| rgb_rows(pixels) }
    differing = ours.each_with_index.sum do |row, y|
      row.each_slice(3).with_index.count { |rgb, x| far?(rgb, theirs[y][x * 3, 3]) }
    end
    differing.fdiv(a.width * a.height)
  end

  def rgb_rows(pixels)
    return pixels.color unless pixels.channels == 1

    pixels.color.map { |row| row.flat_map { |value| [value] * 3 } }
  end

  def far?(rgb, other) = rgb.zip(other).any? { |left, right| (left - right).abs > THRESHOLD }

  # Poppler's picture of each document, from its PDF.
  def record
    require "tmpdir"
    require "fileutils"
    FileUtils.mkdir_p(DIRECTORY)
    DOCUMENTS.each do |name, (build, options)|
      Dir.mktmpdir do |dir|
        pdf = File.join(dir, "#{name}.pdf")
        File.binwrite(pdf, build.call.to_pdf(monochrome: options.fetch(:monochrome, false)))
        mono = options[:monochrome]
        dpi = mono ? mono[:dpi] : options[:dpi]
        system("pdftoppm", "-r", dpi.to_s, "-png", *(mono ? ["-mono"] : []), "-singlefile", pdf,
               File.join(dir, "out"), exception: true)
        File.binwrite(path(name), File.binread(File.join(dir, "out.png")))
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  require "stationery"
  require_relative "documents"
  RasterReferences.record
end
