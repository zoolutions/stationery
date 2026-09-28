# frozen_string_literal: true

# Shared sample data and reporting for the benchmarks under benchmark/.
# Every engine embeds the same TrueType files, so font subsetting is measured
# on each side. Stationery and Prawn always run; sghtmltopdf (`Bench::Sg`)
# runs when its gem is installed.
require "benchmark/ips"
require "prawn"
require "prawn/table"
require_relative "documents"
require_relative "html"

module Bench
  INVOICE_ITEMS = [
    ["Brand workshop", 1, 2400.0], ["Logo design, three concepts", 1, 3200.0],
    ["Illustration set (12)", 12, 180.0], ["Print-ready files", 1, 450.0],
    ["Rush delivery", 1, 300.0], ["Stationery set", 2, 275.0]
  ].freeze

  PAGE = %r{/Type\s*/Page(?![s\w])}

  module_function

  def prawn_fonts(pdf)
    pdf.font_families.update("Open Sans" => { normal: FONT, bold: FONT_BOLD })
    pdf.font "Open Sans", size: 9
  end

  def money(amount) = format("%.2f", amount)

  # Runs Benchmark.ips over { label => -> { pdf_string } } (adding the
  # sghtmltopdf lane when `html:` is given and the gem is installed), then
  # prints one summary row per engine: renders/s, the fastest single render
  # (the figure a busy machine disturbs least), the Ruby objects one render
  # allocates, its bytes and its pages.
  def compare(reports, html: nil)
    reports = reports.merge(sghtmltopdf_lane(html))
    reports.each_value(&:call) # warm the font and image caches on every side
    ips = Benchmark.ips do |x|
      x.config(time: 5, warmup: 2)
      reports.each { |label, block| x.report(label, &block) }
      x.compare!
    end
    summary(reports, ips)
  end

  def sghtmltopdf_lane(html)
    return {} unless html

    unless Sg.available?
      puts "  (no sghtmltopdf lane: the gem is not loadable, or SGHTMLTOPDF=0 is set)"
      return {}
    end

    { "sghtmltopdf" => -> { Sg.render(html) } }
  end

  def summary(reports, ips)
    puts "One render each (sghtmltopdf allocates outside the Ruby heap, so its object count is the binding's):"
    puts "  engine        renders/s    best ms  objects allocated       bytes  pages"
    reports.each do |label, block|
      pdf, allocated = footprint(block)
      rate = ips.entries.find { |entry| entry.label == label }&.ips
      puts format("  %-12<label>s %10.2<rate>f %10.1<best>f %18<allocated>s %11<bytes>s %6<pages>d",
                  label:, rate: rate || 0, best: best_ms(block), allocated: delimit(allocated),
                  bytes: delimit(pdf.bytesize), pages: pdf.b.scan(PAGE).size)
    end
  end

  # The fastest of at least five renders, and of as many as fit in two seconds.
  def best_ms(block)
    times = []
    started = clock
    while times.size < 5 || clock - started < 2
      before = clock
      block.call
      times << (clock - before)
    end
    times.min * 1000
  end

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  def footprint(block)
    GC.start
    before = GC.stat(:total_allocated_objects)
    pdf = block.call
    [pdf, GC.stat(:total_allocated_objects) - before]
  end

  def delimit(number) = number.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
end
