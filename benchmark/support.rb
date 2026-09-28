# frozen_string_literal: true

# Shared sample data and reporting for the benchmarks under benchmark/.
# Both engines embed the same TrueType files, so font subsetting is measured
# on each side.
require "benchmark/ips"
require "prawn"
require "prawn/table"
require_relative "documents"

module Bench
  INVOICE_ITEMS = [
    ["Brand workshop", 1, 2400.0], ["Logo design, three concepts", 1, 3200.0],
    ["Illustration set (12)", 12, 180.0], ["Print-ready files", 1, 450.0],
    ["Rush delivery", 1, 300.0], ["Stationery set", 2, 275.0]
  ].freeze

  module_function

  def prawn_fonts(pdf)
    pdf.font_families.update("Open Sans" => { normal: FONT, bold: FONT_BOLD })
    pdf.font "Open Sans", size: 9
  end

  def money(amount) = format("%.2f", amount)

  # Runs Benchmark.ips over { label => -> { pdf_string } }, then reports the
  # objects allocated and the bytes written by one render of each.
  def compare(reports)
    reports.each_value(&:call) # warm the font caches on both sides
    Benchmark.ips do |x|
      x.config(time: 5, warmup: 2)
      reports.each { |label, block| x.report(label, &block) }
      x.compare!
    end
    footprint(reports)
  end

  def footprint(reports)
    puts "One render each:"
    reports.each do |label, block|
      GC.start
      before = GC.stat(:total_allocated_objects)
      bytes = block.call.bytesize
      allocated = GC.stat(:total_allocated_objects) - before
      puts format("  %-12<label>s %12<allocated>s objects allocated %10<bytes>s bytes",
                  label:, allocated: delimit(allocated), bytes: delimit(bytes))
    end
  end

  def delimit(number) = number.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
end
