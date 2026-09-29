# frozen_string_literal: true

# A certificate of completion on a landscape A4 page: a frame and rosettes
# drawn on a canvas under the content, centred type, and two signature fields
# for the people who sign it. Run it to write examples/certificate.pdf:
#
#   ruby -Ilib examples/certificate.rb
#   ruby -Ilib exe/stationery render examples/certificate.rb
require "stationery"

class ExampleCertificate < Stationery::Document
  GOLD = "#B08D57"
  INK = "#1F2937"
  MUTED = "#6B7280"
  PAPER = "#FFFBF2"
  SEAL = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <circle cx="50" cy="50" r="48" fill="#B08D57"/>
      <circle cx="50" cy="50" r="40" fill="none" stroke="#FFFBF2" stroke-width="1.5" stroke-dasharray="3 2"/>
      <path d="M50 24l7.6 15.4 17 2.5-12.3 12 2.9 16.9L50 62.8l-15.2 8 2.9-16.9-12.3-12 17-2.5z" fill="#FFFBF2"/>
    </svg>
  SVG

  page size: :a4, layout: :landscape, margin: [112, 110, 72, 110]
  default_text color: INK, align: :center
  metadata title: "Certificate of completion", author: "Harbour Institute of Sailing", creator: "stationery example"

  # The background is painted under the content of every page: a page
  # template on the background layer, with a canvas the size of the page.
  page_template(layer: :background) do |page|
    canvas(height: page.height, width: page.width, at: [0, 0]) { |c, _rect| frame(c, page.width, page.height) }
  end

  def self.preview
    new(name: "Robin Example", course: "Coastal Skipper, practical course",
        hours: 64, date: "12 September 2026", number: "HIS-2026-0419")
  end

  def initialize(name:, course:, hours:, date:, number:)
    super()
    @name = name
    @course = course
    @hours = hours
    @date = date
    @number = number
  end

  def view_template
    text "HARBOUR INSTITUTE OF SAILING", size: 10, weight: :bold, color: GOLD, letter_spacing: 3
    spacer 18
    text "Certificate of completion", size: 34, weight: :bold
    spacer 18
    text "This is to certify that", size: 12, color: MUTED, style: :italic
    spacer 10
    text @name, size: 30, weight: :bold, color: GOLD
    spacer 12
    text "has completed the #{@course}, #{@hours} hours afloat and ashore,\n" \
         "and has shown the seamanship the course asks for.", size: 12, leading: 4
    spacer 60
    signatures
  end

  private

  # Two signature fields with the seal between them; the signers sign in
  # their PDF viewer, or with `to_pdf(sign: { …, field: "director" })`.
  def signatures
    row(gap: 40, align: :bottom) do
      column { signature_field "director", label: "Anna Example, Director of Training", height: 44 }
      column(width: 70) { svg SEAL, width: 70, align: :center }
      column { signature_field "examiner", label: "Jonas Sample, Examiner", height: 44 }
    end
    spacer 16
    text "Awarded #{@date} · Certificate #{@number}", size: 8.5, color: MUTED
  end

  # A double frame with rosettes in the corners, in page coordinates from
  # the top left.
  def frame(canvas, width, height)
    canvas.fill_rect(0, 0, width, height, color: PAPER)
    canvas.rounded_rect(24, 24, width - 48, height - 48, radius: 4, stroke: GOLD, line_width: 2.5)
    canvas.rounded_rect(34, 34, width - 68, height - 68, radius: 2, stroke: GOLD, line_width: 0.75)
    [[34, 34], [width - 34, 34], [34, height - 34], [width - 34, height - 34]].each do |x, y|
      rosette(canvas, x, y)
    end
    canvas.line((width / 2) - 60, 88, (width / 2) + 60, 88, color: GOLD, width: 0.75)
  end

  def rosette(canvas, x, y)
    canvas.circle(x, y, 14, fill: PAPER, stroke: GOLD, line_width: 1)
    8.times do |i|
      angle = i * Math::PI / 4
      canvas.line(x, y, x + (12 * Math.cos(angle)), y + (12 * Math.sin(angle)), color: GOLD, width: 0.6)
    end
    canvas.circle(x, y, 4, fill: GOLD)
  end
end

if $PROGRAM_NAME == __FILE__
  certificate = ExampleCertificate.preview
  certificate.to_pdf(File.expand_path("certificate.pdf", __dir__))
  warn certificate.warnings.map(&:message) if certificate.warnings.any?
  puts "wrote examples/certificate.pdf"
end
