# frozen_string_literal: true

RSpec.describe Stationery::Testing::StructureReader do
  let(:tagged) do
    Class.new(SpecDocument) do
      tagged
      metadata lang: "en"
      footer { text "Footer" }
    end
  end

  def build(&) = Class.new(tagged) { define_method(:view_template, &) }.new
  def structure(document) = Stationery::Testing::Inspector.new(document).structure

  it "reads the tree with each element's text from its marked content" do
    logo = image_path("rgb.jpg")
    doc = build do
      text "Intro", heading: 1
      text "Read <a href=\"https://example.com\">the docs</a> now", markup: true
      image logo, width: 10, alt: "Logo"
      ul { li "One" }
    end

    expect(structure(doc)).to eq(
      [[:Document, [[:H1, "Intro"], [:P, ["Read", [:Link, "the docs"], "now"]], [:Figure, "Logo"],
                    [:L, [[:LI, [[:LBody, [[:P, "One"]]]]]]]]]]
    )
  end

  it "joins a paragraph's lines and pages with spaces" do
    doc = build { text Array.new(20) { |i| "line #{i}" }.join("\n") }

    expect(structure(doc)).to eq([[:Document, [[:P, Array.new(20) { |i| "line #{i}" }.join(" ")]]]])
  end

  it "keeps text in one line together across style changes" do
    doc = build { text "<b>Bold</b>ly going", markup: true }

    expect(structure(doc)).to eq([[:Document, [[:P, "Boldly going"]]]])
  end

  it "lists an element without content by its type alone" do
    doc = build { table([["", "x"]]) }

    expect(structure(doc)).to eq([[:Document, [[:Table, [[:TR, [[:TD], [:TD, [[:P, "x"]]]]]]]]]])
  end

  it "is empty for an untagged PDF" do
    expect(structure(SpecDocument.build { text "plain" })).to eq([])
  end

  it "finds text outside marked content" do
    untagged = Stationery::Testing::Inspector.new(SpecDocument.build { text "plain" })
    tagged_doc = Stationery::Testing::Inspector.new(build { text "Body" })

    expect(untagged.untagged_text).to eq(["plain"])
    expect(untagged).not_to be_tagged
    expect(tagged_doc.untagged_text).to eq([])
    expect(tagged_doc).to be_tagged
  end
end
