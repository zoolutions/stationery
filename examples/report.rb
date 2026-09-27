# frozen_string_literal: true

# A multi-page annual report: cover, contents, bookmarks, lists, a table and
# internal links. Run it to write examples/report.pdf:
#
#   ruby -Ilib examples/report.rb
#   ruby -Ilib exe/stationery render examples/report.rb
require "stationery"

class ExampleReport < Stationery::Document
  ACCENT = "#0F766E"
  INK = "#1F2937"
  MUTED = "#6B7280"
  HAIRLINE = "#E5E7EB"
  ZEBRA = "#F9FAFB"
  TINT = "#ECFDF5"
  CHECK = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="currentColor"/>
    <path d="M7 12.5l3.2 3.2L17 9" fill="none" stroke="#FFFFFF" stroke-width="2.2" stroke-linecap="round"
    stroke-linejoin="round"/></svg>
  SVG

  page size: :a4, margin: [48, 56, 40, 56]
  default_text size: 10.5, color: INK
  metadata title: "Annual report 2026", author: "Northwind Freight AB", creator: "stationery example"

  header(on: :rest, gap: 18) do |page|
    row(align: :bottom) do
      text "Annual report 2026", size: 8, weight: :bold, color: ACCENT
      text "Page #{page.number} of #{page.count}", size: 8, color: MUTED, align: :right
    end
  end

  footer(gap: 14) do
    rule height: 0.5, color: HAIRLINE
    spacer 5
    text "Confidential. Prepared for the shareholders of Northwind Freight AB; do not distribute.",
         size: 7, color: MUTED, align: :center
  end

  def self.preview
    new(figures: [["Revenue", "SEK 1.84 bn", "+12% on 2025"], ["Operating margin", "9.6%", "+1.4 points"],
                  ["Deliveries", "4.2 million", "98.7% on time"]],
        regions: [["Nordics", "Road", 612.4, 671.0], ["Nordics", "Rail", 188.2, 214.9],
                  ["DACH", "Road", 402.7, 455.3], ["Benelux", "Sea", 211.9, 236.4],
                  ["UK & Ireland", "Sea", 158.0, 162.7], ["Baltics", "Road", 92.5, 101.8]])
  end

  def initialize(figures:, regions:)
    super()
    @figures = figures
    @regions = regions
  end

  def view_template
    cover
    page_break
    text "Contents", size: 20, weight: :bold, bookmark: "Contents"
    spacer 14
    table_of_contents(levels: 1..2, size: 10, color: INK, gap: 6, indent: 16)
    page_break
    text_style(align: :justify, leading: 3) do
      introduction
      highlights
      financial_review
      operations
      risks
      page_break
      appendix
    end
  end

  private

  def cover
    spacer 150
    text "NORTHWIND FREIGHT AB", size: 9, weight: :bold, color: ACCENT, letter_spacing: 1.5
    spacer 10
    text "Annual report 2026", size: 36, weight: :bold
    spacer 6
    text "Moving more with less: a year of growth, electrification and on-time delivery", size: 13, color: MUTED
    spacer 28
    rule height: 3, color: ACCENT
    spacer 28
    box(background: TINT, radius: 8, padding: [18, 20]) do
      row(gap: 20) do
        @figures.each do |label, value, note|
          column do
            text label.upcase, size: 7.5, weight: :bold, color: MUTED, letter_spacing: 0.6
            spacer 4
            text value, size: 20, weight: :bold, color: ACCENT
            text note, size: 8.5, color: MUTED
          end
        end
      end
    end
  end

  def heading(title, bookmark:, anchor: nil)
    spacer 18
    text title, size: 16, weight: :bold, color: ACCENT, bookmark:, anchor:, keep_with_next: 60
    spacer 8
  end

  def subheading(title)
    spacer 10
    text title, size: 11.5, weight: :bold, bookmark: { title: title.sub(/\A[\d.]+ /, ""), level: 2 },
                keep_with_next: 40
    spacer 4
  end

  def paragraphs(*texts)
    texts.each_with_index do |body, index|
      spacer 7 if index.positive?
      text body, markup: true
    end
  end

  def introduction
    heading "1. Introduction", bookmark: "Introduction", anchor: "intro"
    paragraphs "Northwind Freight closed 2026 with the strongest result in its twenty-year history. Revenue grew " \
               "by twelve per cent to SEK 1.84 billion, driven by new contract logistics customers in Germany " \
               "and a full year of the Gothenburg rail shuttle. At the same time we cut emissions per delivered " \
               "tonne by eighteen per cent, ahead of the target we set ourselves three years ago.",
               "This report covers the financial year from 1 January to 31 December 2026 and the parent company " \
               "together with its five subsidiaries. Figures are in millions of Swedish kronor unless stated " \
               "otherwise, and comparisons are with the previous year. Definitions of the key figures are " \
               "collected at the end of the report."
    spacer 7
    text "See the appendix for definitions and methodology.", link: "#appendix", color: ACCENT, underline: true
    subheading "1.1 About this report"
    paragraphs "The report was prepared by the finance team and reviewed by the board's audit committee. " \
               "Sustainability data follows the Greenhouse Gas Protocol and was verified by an independent " \
               "auditor. Where estimates were necessary, for example for subcontracted haulage, the method is " \
               "described next to the figure so that readers can judge its reliability."
    subheading "1.2 A word from the chief executive"
    paragraphs "Twelve months ago we promised to grow without growing our footprint. I am proud that we kept that " \
               "promise: every tonne we moved this year produced less carbon than the year before, and our " \
               "customers noticed. Three of our five largest contracts were renewed early, two of them with " \
               "electric delivery written into the terms.",
               "None of this happens without the 2,300 people who load, drive, plan and repair every day. Sick " \
               "leave fell for the second year running and our safety record is the best in the industry. " \
               "Thank you for another year of hard, careful work.",
               "<i>Karin Lindqvist, Chief Executive Officer</i>"
  end

  def highlights
    heading "2. Highlights of the year", bookmark: "Highlights"
    [["Rail shuttle", "Five weekly departures between Gothenburg and Duisburg replaced 9,400 truck journeys."],
     ["Electric fleet", "112 battery-electric tractors in daily service, up from 38 a year earlier."],
     ["Customer satisfaction", "Net promoter score rose from 41 to 52 in every business area."]].each do |title, body|
      spacer 6
      row(gap: 10) do
        column(width: 16) { svg CHECK, width: 14, color: ACCENT }
        column { text "<b>#{title}.</b> #{body}", markup: true, align: :left }
      end
    end
    subheading "2.1 Growth drivers"
    ul(gap: 5, marker_color: ACCENT) do
      li "Contract logistics for three new automotive suppliers in southern Germany."
      li(gap: 4) do
        text "Intermodal capacity on the corridors that matter most to our customers:"
        ul(gap: 3) do
          li "Gothenburg to Duisburg, five departures a week"
          li "Malmö to Rotterdam, trial service from October"
        end
      end
      li "Higher utilisation of the Jönköping hub after the new sorting line went live in March."
    end
  end

  def financial_review
    heading "3. Financial review", bookmark: "Financial review"
    paragraphs "Net revenue increased to SEK 1,842 million (1,666). Organic growth was ten per cent; the rest came " \
               "from the acquisition of Baltic Parcel in February. Operating profit rose to SEK 177 million, " \
               "giving an operating margin of 9.6 per cent (8.2). Cash flow from operations was SEK 231 million."
    subheading "3.1 Revenue by region"
    revenue_table
    subheading "3.2 Outlook"
    paragraphs "We expect the freight market to remain soft in the first half of 2027 and to recover later in the " \
               "year. Our priorities are unchanged: grow contract logistics, fill the rail shuttle and continue " \
               "the move to electric trucks, which already lowers our cost per kilometre on regional routes."
  end

  def revenue_table
    rows = [%w[Region Mode 2025 2026 Change]]
    @regions.each do |region, mode, before, after|
      rows << [region, mode, amount(before), amount(after), change(before, after)]
    end
    before = @regions.sum { |row| row[2] }
    after = @regions.sum { |row| row[3] }
    rows << [{ content: "Group total", colspan: 2 }, amount(before), amount(after), change(before, after)]

    table(rows, width: :full, widths: [nil, 70, 70, 70, 60], header: true,
                cell: { padding: [6, 8], borders: [], size: 9, align: :left }) do |t|
      t.row(0).set(background: ACCENT, color: "#FFFFFF", weight: :bold)
      t.columns(2..).align = :right
      t.zebra(from: 1, to: @regions.size, color: ZEBRA)
      t.row(-1).set(weight: :bold, borders: [:top], border_color: INK, border_width: 1)
    end
    spacer 4
    text "Amounts in SEK million.", size: 8, color: MUTED
  end

  def operations
    heading "4. Operations", bookmark: "Operations"
    paragraphs "Our network handled 4.2 million deliveries, of which 98.7 per cent arrived within the agreed " \
               "window. The main operational changes during the year were, in order of impact:"
    spacer 6
    ol(gap: 4, marker_color: ACCENT) do
      li "Commissioning the automated sorting line in Jönköping."
      li "Moving night-time linehaul between Stockholm and Malmö to electric tractors."
      li "Consolidating three Danish terminals into the new Kolding cross-dock."
    end
    subheading "4.1 Sustainability"
    paragraphs "Emissions from our own fleet fell to 38,200 tonnes of CO<sub>2</sub>e. Subcontracted haulage remains " \
               "the larger share, and from 2027 new carrier contracts include reporting requirements."
    spacer 12
    callout
  end

  def callout
    box(background: TINT, radius: 8, padding: 16, border: { color: ACCENT, width: 0.75 }, break_inside: :auto) do
      text "What we learned from electrifying linehaul", size: 11, weight: :bold, color: ACCENT
      spacer 6
      paragraphs "Charging, not range, set the pace. Trucks that could have run 300 kilometres waited for chargers " \
                 "that were shared with the local bus operator, so we now book depot power in advance.",
                 "Drivers adapted quickly. After two weeks of training, energy use per kilometre was within five " \
                 "per cent of the manufacturer's figure, and sick leave in the pilot group fell.",
                 "Maintenance costs were lower than planned. Fewer moving parts meant 40 per cent fewer workshop " \
                 "hours per vehicle, although tyres wear faster because of the heavier battery packs.",
                 "Residual values are the open question. The second-hand market for electric tractors is still " \
                 "thin, so we depreciate them over six years instead of eight until prices settle.",
                 "Next year we will extend the programme to the Oslo and Helsinki terminals and publish the " \
                 "full cost comparison with diesel operation in the sustainability report."
    end
  end

  def risks
    heading "5. Risks and uncertainties", bookmark: "Risks"
    paragraphs "The board reviews the group's risks twice a year. The most significant are listed below together " \
               "with how we manage them; none of them changed materially during 2026."
    spacer 6
    ul(gap: 5, marker_color: ACCENT) do
      li "<b>Demand.</b> Freight volumes follow industrial production. Long contracts with index clauses " \
         "cover about 60 per cent of revenue.", markup: true
      li "<b>Energy prices.</b> Diesel and electricity are hedged twelve months ahead for three quarters of " \
         "expected use.", markup: true
      li "<b>Drivers.</b> The industry is short of qualified drivers. Our academy trained 140 new drivers this " \
         "year, and staff turnover fell to 11 per cent.", markup: true
    end
  end

  def appendix
    heading "6. Appendix", bookmark: "Appendix", anchor: "appendix"
    subheading "6.1 Definitions"
    [["Operating margin", "Operating profit as a percentage of net revenue."],
     ["On-time delivery", "Deliveries made within the time window agreed with the customer."],
     ["Emission intensity", "Grams of CO<sub>2</sub>e per tonne-kilometre, well to wheel."]].each do |term, meaning|
      text "<b>#{term}.</b> #{meaning}", markup: true
      spacer 4
    end
    subheading "6.2 Five-year summary"
    five_year_summary
    spacer 12
    text %(Return to the <link href="#intro"><color rgb="#{ACCENT}">introduction</color></link>.), markup: true
  end

  def five_year_summary
    rows = [["SEK million", "2022", "2023", "2024", "2025", "2026"],
            ["Net revenue", "1,288", "1,402", "1,531", "1,666", "1,842"],
            ["Operating profit", "97", "104", "118", "137", "177"],
            ["Operating margin", "7.5%", "7.4%", "7.7%", "8.2%", "9.6%"],
            ["Employees", "1,940", "2,010", "2,120", "2,210", "2,300"],
            ["On-time delivery", "96.1%", "96.8%", "97.4%", "98.1%", "98.7%"]]
    table(rows, width: :full, widths: [nil, 62, 62, 62, 62, 62], header: true,
                cell: { padding: [5, 8], borders: [:bottom], border_color: HAIRLINE, size: 9, align: :left }) do |t|
      t.row(0).set(weight: :bold, border_color: INK)
      t.columns(1..).align = :right
      t.column(-1).weight = :bold
    end
  end

  def amount(value) = format("%.1f", value)
  def change(before, after) = format("%+.1f%%", (after - before) / before * 100)
end

if $PROGRAM_NAME == __FILE__
  report = ExampleReport.preview
  report.to_pdf(File.expand_path("report.pdf", __dir__))
  warn report.warnings.map(&:message) if report.warnings.any?
  puts "wrote examples/report.pdf"
end
