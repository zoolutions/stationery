# frozen_string_literal: true

# A batch of invoices (examples/invoice.rb) rendered one after another, from
# a pool of threads, and across Ractors with Stationery.render_all, on the
# same machine. Every number is a whole batch of BATCH renders, the best of
# RUNS. The threads share the main Ractor's warm caches; each render_all
# starts fresh Ractors, which parse the fonts and decode the logo again, so
# their numbers include that. Ruby 4.0 and later (Ractor#value); not in CI.
#
#   bundle exec ruby -Ilib benchmark/ractors.rb
#   BATCH=96 WORKERS=4,8 RUNS=3 bundle exec ruby -Ilib benchmark/ractors.rb
require "etc"
require "stationery"
require_relative "../examples/invoice"

abort "Ruby 4.0 or later (Ractor#value): this is #{RUBY_VERSION}" unless Stationery::Parallel.available?

Warning[:experimental] = false
Stationery.finalize!

module RactorBench
  # One clock for every render in every Ractor, so each lane's PDFs can be
  # compared with the sequential ones byte for byte.
  module PinnedClock
    NOW = Time.utc(2026, 1, 1, 12).freeze
    def now(*) = NOW
  end
  Time.singleton_class.prepend(PinnedClock)

  BATCH = Integer(ENV.fetch("BATCH", "48"))
  RUNS = Integer(ENV.fetch("RUNS", "3"))
  WORKERS = ENV.fetch("WORKERS", "2,4,#{Etc.nprocessors}").split(",").map { Integer(it) }.uniq

  module_function

  def documents = Array.new(BATCH) { ExampleInvoice.preview }

  def sequential(documents) = documents.map(&:to_pdf)

  def threads(documents, count)
    queue = Queue.new
    documents.each_with_index { |document, index| queue << [document, index] }
    queue.close
    pdfs = Array.new(documents.size)
    Array.new(count) do
      Thread.new do # rubocop:disable ThreadSafety/NewThread -- the threads lane
        while (job = queue.pop)
          pdfs[job[1]] = job[0].to_pdf
        end
      end
    end.each(&:join)
    pdfs
  end

  def ractors(documents, count) = Stationery.render_all(documents, ractors: count)

  # The fastest of RUNS, in seconds, and the PDFs of the last run.
  def best
    pdfs = nil
    times = Array.new(RUNS) do
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      pdfs = yield
      Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    end
    [times.min, pdfs]
  end

  def row(label, seconds, base)
    puts format("  %-14<label>s %9.3<seconds>f s %9.1<rate>f renders/s %6.2<speedup>fx",
                label:, seconds:, rate: BATCH / seconds, speedup: base / seconds)
  end

  def run
    puts "Ruby #{RUBY_DESCRIPTION}"
    puts "#{Etc.nprocessors} processors; load averages #{`uptime`.strip[/load averages?: (.*)/, 1]}"
    puts "#{BATCH} invoices per batch, the best of #{RUNS} batches; each number is the whole batch"
    expected = sequential(documents) # warms the main Ractor's caches
    base, = best { sequential(documents) }
    row("sequential", base, base)
    WORKERS.each do |count|
      seconds, pdfs = best { threads(documents, count) }
      row("threads × #{count}", seconds, base)
      check(pdfs, expected)
      seconds, pdfs = best { ractors(documents, count) }
      row("ractors × #{count}", seconds, base)
      check(pdfs, expected)
    end
  end

  def check(pdfs, expected)
    abort "the PDFs differ from the sequential ones" unless pdfs == expected
  end
end

RactorBench.run
