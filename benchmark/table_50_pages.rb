# frozen_string_literal: true

# A 1,500-row table with a repeating header row, 40-50 A4 pages.
#
#   bundle exec ruby -Ilib benchmark/table_50_pages.rb
require_relative "support"

module Bench
  def self.prawn_table
    pdf = Prawn::Document.new(page_size: "A4", margin: 36)
    prawn_fonts(pdf)
    pdf.table(TABLE, header: true, width: pdf.bounds.width) { |t| t.row(0).font_style = :bold }
    pdf.render
  end
end

if $PROGRAM_NAME == __FILE__
  Bench.compare({ "stationery" => -> { Bench::StationeryTable.new.to_pdf }, "prawn" => -> { Bench.prawn_table } },
                html: Bench::HTML.table)
end
