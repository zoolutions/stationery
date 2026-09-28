# frozen_string_literal: true

# The metrics gate: renders fixed documents and compares what a render
# allocates, how many pages it makes and how many bytes it writes with
# benchmark/baseline.json. Those three do not depend on how busy the machine
# is, so CI can hold them; time is measured by `rake bench`, locally.
#
#   bundle exec rake metrics          # compare with the baseline, fail on growth
#   bundle exec rake metrics:update   # record the baseline after a change on purpose
#
# Allocations may grow 3% and bytes 1% (zlib builds differ a little between
# platforms); pages must not change. Baselines are kept per Ruby minor version,
# because a new Ruby allocates differently.
require "json"
require_relative "documents"

module Bench
  module Metrics
    BASELINE = File.expand_path("baseline.json", __dir__)
    LIMITS = { "allocations" => 0.03, "bytes" => 0.01, "pages" => 0.0 }.freeze
    FROZEN = Time.utc(2026, 1, 1).freeze
    PAGE = %r{/Type\s*/Page(?![s\w])}
    Row = Data.define(:document, :metric, :baseline, :current, :limit) do
      def change = baseline.zero? ? 0.0 : (current - baseline).fdiv(baseline)
      def moved? = current != baseline
      def failed? = limit.zero? ? moved? : change > limit
    end

    # Time stands still while the gate renders, so dates and the file
    # identifier are the same bytes on every run.
    module FrozenTime
      def now(*) = FROZEN
    end

    DOCUMENTS = {
      "invoice" => -> { example("invoice") },
      "table" => -> { StationeryTable.new },
      "text" => -> { StationeryText.new },
      "text_hyphenated" => -> { StationeryHyphenated.new },
      "flyer" => -> { example("flyer") },
      "form" => -> { example("form") },
      "text_streamed" => -> { StationeryText.new }
    }.freeze
    # Rendered through `to_pdf { |chunk| }` instead of to a String.
    STREAMED = %w[text_streamed].freeze

    module_function

    def example(name)
      constant = "Example#{name.split("_").map(&:capitalize).join}"
      load File.expand_path("../examples/#{name}.rb", __dir__) unless Object.const_defined?(constant)
      Object.const_get(constant).preview
    end

    def ruby = RUBY_VERSION[/\A\d+\.\d+/]

    # { document => { "allocations" =>, "pages" =>, "bytes" => } }, each from one
    # render after two that warm the font, image and pattern caches.
    def measure
      Time.singleton_class.prepend(FrozenTime) unless Time.singleton_class.include?(FrozenTime)
      DOCUMENTS.to_h do |name, document|
        render = STREAMED.include?(name) ? method(:stream) : :to_pdf.to_proc
        2.times { render.call(document.call) }
        pdf, allocations = allocations_of { render.call(document.call) }
        [name, { "allocations" => allocations, "pages" => pdf.b.scan(PAGE).size, "bytes" => pdf.bytesize }]
      end
    end

    def stream(document)
      file = String.new(encoding: Encoding::BINARY)
      document.to_pdf { |chunk| file << chunk }
      file
    end

    def allocations_of
      GC.start
      GC.disable
      before = GC.stat(:total_allocated_objects)
      result = yield
      [result, GC.stat(:total_allocated_objects) - before]
    ensure
      GC.enable
    end

    # One Row per document and metric, with the limit it is held to.
    def compare(baseline, current)
      current.flat_map do |document, metrics|
        metrics.map do |metric, value|
          Row.new(document:, metric:, baseline: baseline.dig(document, metric) || 0, current: value,
                  limit: LIMITS.fetch(metric))
        end
      end
    end

    HEADING = "#{"document".ljust(16)} #{"metric".ljust(12)} #{"baseline".rjust(12)} #{"now".rjust(12)} " \
              "#{"change".rjust(8)}".freeze

    def table(rows)
      lines = rows.map do |row|
        format("%-16<document>s %-12<metric>s %12<baseline>s %12<current>s %8<change>s  %<verdict>s",
               document: row.document, metric: row.metric, baseline: delimit(row.baseline),
               current: delimit(row.current), change: format("%+.1f%%", row.change * 100), verdict: verdict(row))
      end
      [HEADING, *lines].join("\n")
    end

    def verdict(row)
      return "FAIL (limit #{limit_of(row)})" if row.failed?

      row.moved? ? "moved" : ""
    end

    def limit_of(row) = row.limit.zero? ? "no change" : format("+%d%%", row.limit * 100)
    def delimit(number) = number.to_s.reverse.scan(/\d{1,3}/).join(",").reverse

    def baselines = File.exist?(BASELINE) ? JSON.parse(File.read(BASELINE)) : {}

    # Measured before the record is built, as `check` measures before it
    # compares: measured inside the record's literal, the first document
    # counted one allocation other than `check` then found.
    def update
      documents = measure
      recorded = baselines.merge(ruby => { "recorded_with" => RUBY_DESCRIPTION, "documents" => documents })
      File.write(BASELINE, "#{JSON.pretty_generate(recorded.sort.to_h)}\n")
      puts "Recorded the baseline for Ruby #{ruby} in #{BASELINE}"
    end

    def check
      baseline = baselines.dig(ruby, "documents")
      abort "No baseline for Ruby #{ruby} in #{BASELINE}: run `bundle exec rake metrics:update` on it" unless baseline

      rows = compare(baseline, measure)
      puts table(rows)
      failed = rows.select(&:failed?)
      if failed.empty?
        puts "\nWithin the limits of the Ruby #{ruby} baseline."
        puts "Some metrics moved: record them with `bundle exec rake metrics:update`." if rows.any?(&:moved?)
      else
        abort "\n#{failed.size} metric(s) over the limit. If the change is on purpose, record it with " \
              "`bundle exec rake metrics:update` and say why in the commit."
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  ARGV.include?("--update") ? Bench::Metrics.update : Bench::Metrics.check
end
