# frozen_string_literal: true

require "stationery/html/tokenizer"

RSpec.describe Stationery::HTML::Tokenizer do
  def tokens(source) = described_class.tokenize(source)

  [
    ["plain text", [[:text, "plain text"]]],
    ["<P>a</P>", [[:start, "p", {}, false], [:text, "a"], [:end, "p"]]],
    [%(<a HREF="x" title='y' data-n=3 hidden>z</a>),
     [[:start, "a", { "href" => "x", "title" => "y", "data-n" => "3", "hidden" => "" }, false],
      [:text, "z"], [:end, "a"]]],
    ["<br><br/><hr />", [[:start, "br", {}, true], [:start, "br", {}, true], [:start, "hr", {}, true]]],
    ["<img src=a.png></img>", [[:start, "img", { "src" => "a.png" }, true]]],
    ["<div/>", [[:start, "div", {}, true]]],
    ["a<!-- <b>hidden</b> -->b", [[:text, "ab"]]],
    ["<!DOCTYPE html><?xml version='1.0'?>x", [[:text, "x"]]],
    ["<script>if (a < b) { x('</p>') }</script>y", [[:text, "y"]]],
    ["<STYLE>p { color: red }</style ><title>T</title>z", [[:text, "z"]]],
    ["<![CDATA[<b>raw</b>]]>", [[:text, "<b>raw</b>"]]],
    ["Fish &amp; Chips&nbsp;&#8364; &lt;b&gt;", [[:text, "Fish & Chips € <b>"]]],
    [%(<a href="?a=1&amp;b=2">), [[:start, "a", { "href" => "?a=1&b=2" }, false]]],
    ["1 < 2 <3", [[:text, "1 < 2 <3"]]],
    ["</br></ div>", [[:text, "</ div>"]]],
    [%(<p class="x), [[:start, "p", { "class" => "\"x" }, false]]],
    [%(<p "junk">a), [[:start, "p", {}, false], [:text, "a"]]],
    ["<script>never closed", []],
    ["<!-- never closed", []],
    ["</p", [[:end, "p"]]]
  ].each do |source, expected|
    it "tokenizes #{source.inspect}" do
      expect(tokens(source)).to eq(expected)
    end
  end
end
