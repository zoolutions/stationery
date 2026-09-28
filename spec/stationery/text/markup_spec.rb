# frozen_string_literal: true

RSpec.describe Stationery::Text::Markup do
  def runs(source) = described_class.parse(source, base_style)
  def texts(source) = runs(source).map(&:text)

  it "turns tags into styled runs" do
    result = runs("a <b>bold</b> <i>it</i> <u>un</u> <strikethrough>st</strikethrough> x<sub>2</sub> y<sup>3</sup>")

    expect(result.map(&:text)).to eq(["a ", "bold", " ", "it", " ", "un", " ", "st", " x", "2", " y", "3"])
    expect(result[1].style.weight).to eq(:bold)
    expect(result[3].style.style).to eq(:italic)
    expect(result[5].style.underline).to be(true)
    expect(result[7].style.strikethrough).to be(true)
    expect(result[9].style.script).to eq(:sub)
    expect(result[11].style.script).to eq(:sup)
  end

  it "accepts HTML aliases" do
    result = runs("<strong>a</strong><em>b</em><s>c</s>-<del>d</del>")

    expect(result.map(&:text)).to eq(%w[a b c - d])
    expect(result.map { |r| r.style.weight }).to eq(%i[bold regular regular regular regular])
    expect(result.map { |r| r.style.style }).to eq(%i[normal italic normal normal normal])
    expect(result.map { |r| r.style.strikethrough }).to eq([false, false, true, false, true])
  end

  it "nests styles" do
    result = runs("<b>a<i>b</i>c</b>")

    expect(result.map { |r| [r.text, r.style.weight, r.style.style] })
      .to eq([["a", :bold, :normal], ["b", :bold, :italic], ["c", :bold, :normal]])
  end

  it "reads colour, font and link attributes with either quote style" do
    result = runs(
      %(<color rgb='#FF0000'>r</color><font size="7" name='Mono'>f</font>) +
      %(<link href="https://x.test/?a=1&amp;b=2">l</link><a href='mailto:a@b.c'>m</a>)
    )

    expect(result[0].style.color).to eq("#FF0000")
    expect(result[1].style).to have_attributes(size: 7, family: "Mono")
    expect(result[2].style.link).to eq("https://x.test/?a=1&b=2")
    expect(result[3].style.link).to eq("mailto:a@b.c")
  end

  it "reads CMYK colour attributes" do
    expect(runs("<color c='0' m='100' y='100' k='0'>x</color>").first.style.color).to eq([0, 100, 100, 0])
  end

  it "decodes entities" do
    decoded = texts("Fish &amp; Chips &lt;3 &gt; &quot;q&quot; &#39;s &#8364; &#x41;")

    expect(decoded).to eq(["Fish & Chips <3 > \"q\" 's € A"])
  end

  it "keeps an escaped tag as literal text instead of styling it" do
    result = runs("a &lt;b&gt;not bold&lt;/b&gt; &amp; <b>bold</b>")

    expect(result.map(&:text)).to eq(["a <b>not bold</b> & ", "bold"])
    expect(result.map { |r| r.style.weight }).to eq(%i[regular bold])
  end

  it "decodes HTML 4 named entities" do
    expect(texts("Fish &amp; Chips &mdash; &euro;5").join).to eq("Fish & Chips — €5")
  end

  it "turns <br> into a newline" do
    expect(texts("a<br>b<br/>c").join).to eq("a\nb\nc")
  end

  it "keeps the content of unknown tags and drops the tag" do
    expect(texts("<span class='x'>kept</span> <blink>too</blink>").join).to eq("kept too")
  end

  it "renders a stray < literally instead of swallowing it" do
    expect(texts("a < b and 1<2").join).to eq("a < b and 1<2")
  end

  it "ignores unbalanced closing tags" do
    expect(texts("a</b>b").join).to eq("ab")
  end
end
