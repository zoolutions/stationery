# frozen_string_literal: true

require "stationery/cli"
require "stationery/preview"
require "stationery/verify"

# Every cache the gem keeps lives in Stationery::Store, one per Ractor, with
# its lock inside it: a non-main Ractor can read neither a constant nor a
# class instance variable that holds a lock, so a render inside one could
# not reach the cache at all.
RSpec.describe "the caches, per Ractor" do
  def inter = File.join(Stationery::Fonts::Bundled::DIR, "Inter-Regular.ttf")

  # Each cache's key, and a call that fills it.
  def caches
    { stationery_colors: -> { Stationery::Color.parse("#123456") },
      stationery_fonts: -> { Stationery::Fonts::Registry.load(inter) },
      stationery_images: -> { Stationery::Images.load(image_path("rgb.jpg")) },
      stationery_hyphenation: -> { Stationery::Hyphenation.points("hyphenation", "en") },
      stationery_previews: -> { Stationery::Preview.all },
      stationery_cell_paddings: -> { Stationery::Layout::Table::Cell.new("x", { padding: 4 }).padding },
      stationery_icc_profile: -> { Stationery::PDF::Conformance.icc_profile },
      # A Reed–Solomon coder's divisors sit under a key naming its field and first root.
      Stationery::Barcode::ReedSolomon::QR.instance_variable_get(:@divisors) =>
        -> { Stationery::Barcode::ReedSolomon::QR.divisor(7) } }
  end

  def lock?(value) = value.is_a?(Thread::Mutex) || value.is_a?(Monitor)

  # [owner, constant or ivar name, value] for everything under Stationery.
  def held_under(mod, seen = {}, &)
    return if seen[mod]

    seen[mod] = true
    mod.instance_variables.each { |name| yield mod, name, mod.instance_variable_get(name) }
    mod.constants(false).each do |name|
      value = mod.const_get(name, false)
      yield mod, name, value
      held_under(value, seen, &) if value.is_a?(Module) && stationery?(value)
    end
  end

  # Module#name, which a module may answer differently (PDF::Serializer.name).
  def stationery?(mod) = Module.instance_method(:name).bind_call(mod)&.start_with?("Stationery")

  def locks
    found = []
    held_under(Stationery) { |owner, name, value| found << "#{owner}.#{name}" if lock?(value) }
    found
  end

  it "keeps no Mutex or Monitor in a constant or a class instance variable" do
    caches.each_value(&:call)

    expect(locks).to eq([])
  end

  it "keeps each cache under its own key" do
    held = caches.to_h do |key, use|
      use.call
      [key, Stationery::Store.fetch(key) { raise "#{key} was never built" }]
    end

    expect(held.values.uniq(&:object_id).size).to eq(caches.size)
  end

  describe "inside a non-main Ractor" do
    let(:subject_call) do
      lambda do
        inter = File.join(Stationery::Fonts::Bundled::DIR, "Inter-Regular.ttf")
        [Stationery::Color.parse("#123456").fill, Stationery::Hyphenation.points("hyphenation", "en"),
         Stationery::Fonts::Registry.load(inter).postscript_name]
      end
    end

    it_behaves_like "runs inside a non-main Ractor"
  end
end
