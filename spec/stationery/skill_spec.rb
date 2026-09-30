# frozen_string_literal: true

require "stationery/skill"

RSpec.describe Stationery::Skill do
  subject(:skill) { described_class.new }

  let(:root) { File.expand_path("../..", __dir__) }
  let(:files) { skill.files }
  let(:skill_md) { files.fetch("SKILL.md") }

  def front_matter(text) = text[/\A---\n(.*?)\n---\n/m, 1]

  it "is a SKILL.md with the name and a description of what it is for" do
    matter = front_matter(skill_md)

    expect(matter).to match(/^name: stationery$/)
    description = matter[/^description: (.+)$/, 1]
    expect(description).to include("PDF", "invoice", "report", "label", "receipt", "Stationery")
    expect(description.size).to be <= 1024
  end

  it "carries the version of the gem it was written for, as a marker of its own" do
    expect(described_class.version_of(skill_md)).to eq(Stationery::VERSION)
    expect(front_matter(skill_md)).to include("generator: #{described_class::GENERATOR}")
    expect(skill_md).to include("stationery #{Stationery::VERSION}")
  end

  it "reads no version from a SKILL.md that is not its own" do
    expect(described_class.version_of("---\nname: stationery\n---\n# Mine")).to be_nil
  end

  it "keeps SKILL.md short and puts the reference beside it" do
    expect(skill_md.lines.size).to be < 300
    expect(files.keys).to include("reference/elements.md", "reference/conformance.md", "recipes/invoice.md",
                                  "recipes/label.md")
    files.keys.grep(%r{/}).each { |path| expect(skill_md).to include("](#{path})") }
  end

  it "embeds README sections as they are written" do
    elements = File.read(File.join(root, "README.md"))[/^## Elements\n\n(.*?)\n### /m, 1]

    expect(files.fetch("reference/elements.md")).to include(elements.lines.first(3).join)
    expect(files.fetch("reference/conformance.md")).to include("`missing_glyphs: :replace` keeps the claim instead")
  end

  it "fails when a README section it embeds is gone or renamed" do
    readme = File.read(File.join(root, "README.md")).sub("### Floats\n", "### Floating\n")

    expect { described_class.new(readme:).files }.to raise_error(KeyError, /README.md has no section "Floats"/)
  end

  it "leaves no link to an anchor of the README it was cut from" do
    expect(files.values.join).not_to match(/\]\(#[a-z]/)
  end

  it "names only examples that ship with the gem" do
    names = Dir.glob("**/*.rb", base: File.join(root, "examples")).map { it.delete_suffix(".rb") }
    mentioned = files.values.join.scan(%r{stationery examples ([a-z_/]+)}).flatten.uniq

    expect(mentioned).not_to be_empty
    expect(mentioned - names).to eq([])
  end

  it "links only pages the docs site has" do
    registry = File.read(File.join(root, "docs/app/models/doc.rb"))
    slugs = registry.scan(/^\s*page "([^"]+)"(.*)$/).map do |title, rest|
      rest[/slug: "([^"]+)"/, 1] || title.downcase.gsub(/[^a-z0-9]+/, "-")
    end
    linked = files.values.join.scan(%r{stationery\.zoolutions\.llc/docs/([a-z-]+)}).flatten.uniq

    expect(linked).not_to be_empty
    expect(linked - slugs).to eq([])
  end

  it "names only commands and options the CLI has" do
    require "stationery/cli"
    code = files.values.join.then { |text| text.scan(/^```.*?^```/m) + text.scan(/`([^`\n]+)`/).flatten }
    commands = code.join("\n").scan(/(?:^|[\s("'`])stationery ([a-z]+)\b(?!:)([^\n`#)]*)/)

    expect(commands.map(&:first)).to include("render", "inspect", "examples", "skill")
    commands.each do |name, rest|
      next if name == "help"

      expect(Stationery::CLI.commands).to include(name)
      help = StringIO.new
      Stationery::CLI.start([name, "--help"], out: help, err: StringIO.new)
      rest.scan(/--[a-z][a-z-]*/).each { |flag| expect(help.string).to include(flag), "stationery #{name} #{flag}" }
    end
  end

  it "names only methods the gem has" do
    unknown = SkillChecks::Names.new(files).unknown

    expect(unknown).to eq([])
    expect(SkillChecks::Names.new("SKILL.md" => "`doc.have_pdf_txt(1)`, `to_pdf`, `layout: :x`").unknown)
      .to eq(["have_pdf_txt"])
  end

  it "renders every document its recipes write, without a warning" do
    documents = SkillChecks::Recipes.new(files).documents

    expect(documents.size).to be >= 4
    documents.each do |name, document|
      expect(document.to_pdf).to start_with("%PDF"), name
      expect(document.warnings.map(&:message)).to eq([]), name
    end
  end

  it "escapes the data its report recipe writes into SVG" do
    report = SkillChecks::Recipes.new(files.slice("recipes/report.md")).classes.values.first
    document = report.new(quarters: [["R&D <est.>", 10.0]], regions: [])

    expect(document.to_pdf).to start_with("%PDF")
    expect(document.warnings.map(&:message)).to eq([])
    expect(document).to have_pdf_text("R&D <est.>")
  end
end
