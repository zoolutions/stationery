# frozen_string_literal: true

RSpec.describe Stationery::Fonts::Shaping do
  subject(:shaping) { described_class.new(font, shaper, path:) }

  let(:path) { font_path("OpenSans-Regular.ttf") }
  let(:font) { Stationery::Fonts::Font.new(Stationery::Fonts::Registry.load(path)) }
  let(:shaper) { FakeShapers::Recording.new }

  def run(text, size = 10) = shaping.run(text, size, kerning: true, ligatures: true, features: [])
  def memoised = shaping.instance_variable_get(:@runs).each_value.sum { |sizes| sizes.each_value.sum(&:size) }

  describe "the memo of shaped runs" do
    it "starts over once it holds MEMO_BYTES of text, answering as before" do
      stub_const("Stationery::Fonts::Font::MEMO_BYTES", 64)
      words = Array.new(40) { |index| "word#{index}" }
      fresh = described_class.new(font, FakeShapers::NOMINAL, path:)
      expected = words.map { |word| fresh.run(word, 10, kerning: true, ligatures: true, features: []) }

      runs = words.map { |word| run(word) }
      run("word39", 12)

      expect(memoised).to be < 12
      expect(runs.map(&:gids)).to eq(expected.map(&:gids))
      expect(runs.map(&:width)).to eq(expected.map(&:width))
    end

    it "keeps what a document repeats, asking the shaper once" do
      first = run("Invoice")

      expect(run("Invoice")).to equal(first)
      expect(shaper.texts).to eq(["Invoice"])
      expect(memoised).to eq(1)
    end
  end
end
