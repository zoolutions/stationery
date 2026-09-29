# frozen_string_literal: true

require "digest"
require "json"
require "zlib"

# Digests of what representative documents render to, recorded from `main`
# before pages were sealed as they are painted, for the specs that hold every
# form of `to_pdf` to the same bytes:
#
#   ruby -I<a checkout of main>/lib spec/support/render_digests.rb > spec/fixtures/renders/main.json
#
# Each document is recorded as the String (`string`) and as the pieces a block
# is handed, joined (`block`). `bytes` is the file itself, compared where zlib
# is the build that recorded it; `objects` is every object with its streams
# inflated and their lengths left out, which holds on every platform.
module RenderDigests
  FIXTURE = File.expand_path("../fixtures/renders/main.json", __dir__)
  ROOT = File.expand_path("../..", __dir__)
  FROZEN = Time.utc(2026, 1, 1, 12)
  EXAMPLES = %w[article e_invoice flyer form invoice letter newsletter packing_slip postcard report
                shipping_label accessible_report certificate contract menu multilingual_notice price_list
                resume receipt].freeze
  BENCHMARKS = { "table" => :StationeryTable, "text" => :StationeryText, "text_hyphenated" => :StationeryHyphenated,
                 "photos" => :StationeryPhotos }.freeze
  OBJECT = /^\d+ 0 obj\n.*?\nendobj\n/m
  STREAM = /\nstream\n(.*)\nendstream\nendobj\n\z/m

  module FrozenTime
    def now(*) = FROZEN
  end

  module_function

  def names = EXAMPLES + BENCHMARKS.keys

  def document(name)
    return example(name) if EXAMPLES.include?(name)

    require File.join(ROOT, "benchmark/documents")
    Bench.const_get(BENCHMARKS.fetch(name)).new
  end

  def example(name)
    constant = "Example#{name.split("_").map(&:capitalize).join}"
    require File.join(ROOT, "examples", name) unless Object.const_defined?(constant)
    Object.const_get(constant).preview
  end

  def environment = "zlib #{Zlib.zlib_version} on #{RUBY_PLATFORM}"
  def fixture = JSON.parse(File.read(FIXTURE))

  # What `main` wrote for `name` in `form`, as far as this platform can be
  # held to it: the bytes too where zlib is the build that recorded them.
  def recorded(name, form) = comparable(fixture.dig("documents", name, form))
  def comparable(digests) = fixture["recorded_with"] == environment ? digests : digests.slice("objects")

  def digest(pdf) = { "bytes" => Digest::SHA256.hexdigest(pdf), "objects" => Digest::SHA256.hexdigest(objects(pdf)) }

  # Every object in file order, streams inflated where they are deflated.
  def objects(pdf)
    pdf.b.scan(OBJECT).map do |object|
      object.sub(STREAM) { "\nstream\n#{inflate(Regexp.last_match(1))}\nendstream\n" }.sub(%r{/Length \d+}, "")
    end.join
  end

  def inflate(data)
    Zlib::Inflate.inflate(data)
  rescue Zlib::Error
    data
  end

  def streamed(document, **)
    file = String.new(encoding: Encoding::BINARY)
    document.to_pdf(**) { |chunk| file << chunk }
    file
  end

  def record
    Time.singleton_class.prepend(FrozenTime)
    documents = names.to_h do |name|
      [name, { "string" => digest(document(name).to_pdf), "block" => digest(streamed(document(name))) }]
    end
    { "recorded_with" => environment, "version" => Stationery::VERSION, "documents" => documents }
  end
end

if $PROGRAM_NAME == __FILE__
  require "stationery"
  puts JSON.pretty_generate(RenderDigests.record) # rubocop:disable RSpec/Output
end
