# frozen_string_literal: true

RSpec.describe Stationery::Hyphenation do
  def joined(word, language) = described_class.hyphenate(word, language).join("-")

  describe "English (en-us)" do
    # TeX's own results for these words (ushyphmax patterns, the TUGboat
    # exception log for "associate").
    {
      "hyphenation" => "hy-phen-ation",
      "concatenation" => "con-cate-na-tion",
      "supercalifragilisticexpialidocious" => "su-per-cal-ifrag-ilis-tic-ex-pi-ali-do-cious",
      "associate" => "as-so-ciate",
      "computer" => "com-puter",
      "programming" => "pro-gram-ming",
      "beautiful" => "beau-ti-ful",
      "reference" => "ref-er-ence",
      "algorithm" => "al-go-rithm",
      "philanthropic" => "phil-an-thropic",
      "table" => "ta-ble",
      "project" => "project"
    }.each do |word, expected|
      it("hyphenates #{word} as #{expected}") { expect(joined(word, "en")).to eq(expected) }
    end

    it "keeps two letters before a break and three after" do
      expect(described_class.points("hyphenation", "en")).to eq([2, 6])
      expect(described_class.points("ab", "en")).to eq([])
    end

    it "keeps the word's own case" do
      expect(described_class.hyphenate("Hyphenation", "en")).to eq(%w[Hy phen ation])
    end
  end

  describe "German (de-1996)" do
    {
      "Silbentrennung" => "Sil-ben-tren-nung",
      "Donaudampfschifffahrt" => "Do-nau-dampf-schiff-fahrt",
      "Zeitungsleser" => "Zei-tungs-le-ser",
      "Bundesverfassungsgericht" => "Bun-des-ver-fas-sungs-ge-richt",
      "Kindergarten" => "Kin-der-gar-ten",
      "Geschwindigkeitsbegrenzung" => "Ge-schwin-dig-keits-be-gren-zung",
      "Gemeinschaft" => "Ge-mein-schaft",
      "Unterkunft" => "Un-ter-kunft",
      "Frühstück" => "Früh-stück",
      "Fußgängerzone" => "Fuß-gän-ger-zo-ne",
      "Rechtschreibung" => "Recht-schrei-bung",
      "Herbstmonat" => "Herbst-mo-nat"
    }.each do |word, expected|
      it("hyphenates #{word} as #{expected}") { expect(joined(word, "de")).to eq(expected) }
    end
  end

  describe "Swedish (sv)" do
    {
      "avstavning" => "av-stav-ning",
      "trädgårdsmästare" => "träd-gårds-mäs-ta-re",
      "gemenskap" => "ge-men-skap",
      "sommarlov" => "som-mar-lov",
      "flygplats" => "flyg-plats",
      "blåbärssoppa" => "blå-bärs-sop-pa",
      "mötesplats" => "mö-tes-plats",
      "hyresgäst" => "hy-res-gäst",
      "sjukhus" => "sjuk-hus",
      "kärlek" => "kär-lek",
      "programmering" => "pro-gram-me-ring"
    }.each do |word, expected|
      it("hyphenates #{word} as #{expected}") { expect(joined(word, "sv")).to eq(expected) }
    end
  end

  describe ".tag" do
    it "maps true and the accepted tags to a bundled pattern set" do
      expect(described_class.tag(true)).to eq("en-us")
      expect(described_class.tag("EN")).to eq("en-us")
      expect(described_class.tag(:de)).to eq("de-1996")
      expect(described_class.tag("sv-SE")).to eq("sv")
      expect(described_class.tag(false)).to be_nil
      expect(described_class.tag(nil)).to be_nil
    end

    it "refuses a language that is not bundled, naming the bundled ones" do
      expect { described_class.tag("fr") }
        .to raise_error(ArgumentError, /unknown hyphenation language "fr" \(bundled: en, en-us, .*sv-se\)/)
    end
  end

  it "leaves words with digits or punctuation alone" do
    expect(described_class.points("ab12cd", "en")).to eq([])
    expect(described_class.hyphenate("e-mail", "en")).to eq(["e-mail"])
  end

  it "loads each pattern set once" do
    expect(described_class.patterns("de")).to be(described_class.patterns("de-de"))
  end
end
