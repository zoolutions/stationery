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

  it "decodes hexadecimal references with either case of x and digits" do
    expect(described_class.decode("Gray&#X27;s &#x00e9; &#XE9;")).to eq("Gray's é é")
  end

  it "leaves unknown names, malformed references and bare ampersands verbatim" do
    expect(described_class.decode("&foo; & &amp &#; &#x; a &amp;&amp; b")).to eq("&foo; & &amp &#; &#x; a && b")
  end

  it "leaves references outside Unicode or in the surrogate range verbatim" do
    expect(described_class.decode("&#99999999; &#xD800; &#0; ok &#x1F600;")).to eq("&#99999999; &#xD800; &#0; ok 😀")
  end

  it "decodes each reference once, so an escaped ampersand stays literal text" do
    expect(described_class.decode("&amp;#39; &amp;lt;b&amp;gt;")).to eq("&#39; &lt;b&gt;")
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
