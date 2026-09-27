# frozen_string_literal: true

require "open3"

RSpec.describe Stationery::Text::Entities do
  it "decodes numeric and built-in named references" do
    expect(described_class.decode("&#x41;&#66; &amp; &lt;&gt; &quot;&apos;")).to eq("AB & <> \"'")
  end

  it "decodes the HTML 4 named references" do
    decoded = described_class.decode("a&mdash;b&hellip; &euro;5 it&rsquo;s &Alpha; &trade;&nbsp;x")

    expect(decoded).to eq("a—b… €5 it’s Α ™ x")
  end

  it "leaves unknown names verbatim" do
    expect(described_class.decode("&foo; & &amp")).to eq("&foo; & &amp")
  end

  it "does not load the HTML 4 table until an unknown name is seen" do
    script = 'require "stationery"; print defined?(Stationery::Text::Entities::HTML4).inspect'
    output, status = Open3.capture2(RbConfig.ruby, "-Ilib", "-e", script)

    expect(status).to be_success
    expect(output).to eq("nil")
  end

  describe "HTML4" do
    before { described_class.decode("&mdash;") }

    let(:table) { described_class::HTML4 }

    it "holds every HTML 4 named character reference" do
      expect(table.size).to eq(252)
      expect(table).to be_frozen
    end

    it "maps names to the right characters" do
      expect(table.values_at(*%w[nbsp mdash hellip euro rsquo trade lang rang AElig yuml Omega sigmaf fnof
                                 hArr there4 zwj OElig quot]))
        .to eq([" ", "—", "…", "€", "’", "™", "〈", "〉", "Æ",
                "ÿ", "Ω", "ς", "ƒ", "⇔", "∴", "‍", "Œ", "\""])
    end
  end
end
