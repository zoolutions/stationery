# frozen_string_literal: true

# A survey report written for screen readers as a PDF/UA-1 file:
# headings in order, a chart and a photo as figures with their `alt:` text,
# a table whose header cells a reader announces with every value, and a
# language and title of its own. `rake verify:conformance` validates it with
# veraPDF. Run it to write examples/accessible_report.pdf:
#
#   ruby -Ilib examples/accessible_report.rb
#   ruby -Ilib exe/stationery render examples/accessible_report.rb
require "stationery"

class ExampleAccessibleReport < Stationery::Document
  PHOTO = File.expand_path("assets/hills.png", __dir__)
  ACCENT = "#1D4ED8"
  INK = "#111827"
  MUTED = "#4B5563"
  HAIRLINE = "#D1D5DB"
  ZEBRA = "#F3F4F6"

  page size: :a4, margin: [56, 60, 48, 60]
  default_text size: 10.5, color: INK, leading: 3
  # PDF/UA-1 asks for a title and a language, and turns tagging on. What it
  # cannot keep (a figure without `alt:`, a heading level skipped) raises
  # instead of writing a file that claims more than it is.
  metadata title: "Cycling to school: survey 2026", author: "Example County Council", lang: "en",
           creator: "stationery example"
  conformance :pdf_ua1

  footer { |page| text "Page #{page.number} of #{page.count}", size: 8, color: MUTED, align: :center }

  def self.preview
    new(schools: [["Northfield", 412, 38, 44], ["Riverside", 288, 51, 57], ["Hillcrest", 530, 22, 31],
                  ["Harbour", 196, 44, 49], ["Meadow Lane", 351, 29, 41]])
  end

  def initialize(schools:)
    super()
    @schools = schools
  end

  def view_template
    text "Cycling to school", size: 26, weight: :bold, heading: 1
    text "Results of the 2026 travel survey in five primary schools", size: 13, color: MUTED
    spacer 18
    summary
    findings
    method_section
  end

  private

  def heading(title, level: 2)
    spacer 14
    text title, size: level == 2 ? 16 : 12.5, weight: :bold, color: ACCENT, heading: level, keep_with_next: 60
    spacer 6
  end

  def summary
    heading "Summary"
    text "More children cycle to school than a year ago in every school surveyed. Across the five schools the " \
         "share rose from 35 to 45 per cent after the new cycle paths opened in March. The largest change was " \
         "at Hillcrest, where a safe crossing on the main road was the most requested improvement."
    spacer 10
    image PHOTO, width: 1.0, height: 120, fit: :cover, radius: 4,
                 alt: "Green hills under a yellow morning sky: the valley the new cycle paths run through"
  end

  def findings
    heading "Findings"
    heading "Share of pupils who cycle", level: 3
    svg chart, width: 475, color: ACCENT,
               alt: "Bar chart of the share of pupils who cycle, 2025 and 2026. Northfield 38 to 44 per cent, " \
                    "Riverside 51 to 57, Hillcrest 22 to 31, Harbour 44 to 49, Meadow Lane 29 to 41."
    spacer 4
    text "Light bars 2025, dark bars 2026.", size: 8.5, color: MUTED
    heading "By school", level: 3
    school_table
  end

  # A header row is tagged as TH cells with a column scope, so a screen
  # reader names the column with every value it reads.
  def school_table
    rows = [["School", "Pupils", "Cycling 2025", "Cycling 2026", "Change"]]
    @schools.each do |name, pupils, before, after|
      rows << [name, pupils.to_s, "#{before}%", "#{after}%", format("%+d points", after - before)]
    end
    table(rows, header: true, width: :full, widths: [nil, 60, 80, 80, 70],
                cell: { padding: [5, 8], borders: [:bottom], border_color: HAIRLINE, size: 9.5 }) do |t|
      t.row(0).set(weight: :bold, border_color: INK)
      t.columns(1..).align = :right
      t.zebra(from: 1, color: ZEBRA)
    end
  end

  def method_section
    heading "Method"
    text "Every pupil in years three to six answered five questions in class in the first week of May, as in " \
         "2025. Answers were collected on paper and entered twice by different people. The response rate " \
         "was 94 per cent; absent pupils were not followed up."
    spacer 8
    ul(gap: 4, marker_color: ACCENT) do
      li "Cycling means cycling for at least part of the way on three days or more of the week."
      li "Pupils who walk and cycle on different days were counted as cycling."
      li "Figures are rounded to whole percentage points."
    end
  end

  # The bars as SVG, 2025 light and 2026 in the accent colour (currentColor).
  def chart
    bars = @schools.each_with_index.map do |(name, _, before, after), index|
      x = 40 + (index * 90)
      <<~BAR
        <rect x="#{x}" y="#{150 - (before * 2)}" width="30" height="#{before * 2}" fill="#BFDBFE"/>
        <rect x="#{x + 32}" y="#{150 - (after * 2)}" width="30" height="#{after * 2}" fill="currentColor"/>
        <text x="#{x + 31}" y="168" font-size="11" text-anchor="middle" fill="#4B5563">#{name}</text>
      BAR
    end
    <<~SVG
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 490 175">
        <line x1="30" y1="150" x2="490" y2="150" stroke="#9CA3AF"/>
        #{bars.join}
      </svg>
    SVG
  end
end

if $PROGRAM_NAME == __FILE__
  report = ExampleAccessibleReport.preview
  report.to_pdf(File.expand_path("accessible_report.pdf", __dir__))
  warn report.warnings.map(&:message) if report.warnings.any?
  puts "wrote examples/accessible_report.pdf"
end
