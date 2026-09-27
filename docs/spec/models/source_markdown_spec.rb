# frozen_string_literal: true

require "rails_helper"

RSpec.describe SourceMarkdown do
  it "extracts a README section without its heading, up to the next sibling heading" do
    body = described_class.readme_section("Performance")

    expect(body).to start_with("`bundle exec rake bench`")
    expect(body).to include("| Document | Engine |")
    expect(body).not_to include("## Limitations")
  end

  it "keeps nested headings inside a section" do
    expect(described_class.readme_section("Pages")).to include("### Debugging")
  end

  it "raises for a missing section" do
    expect { described_class.readme_section("Nope") }.to raise_error(KeyError)
  end

  it "reads the changelog without its title" do
    expect(described_class.changelog).to start_with("## ").and include("### Fixes")
  end

  it "reads an example's summary comment" do
    expect(described_class.example_summary("report.rb")).to start_with("A multi-page annual report")
  end

  it "reads an example's class-level configuration" do
    config = described_class.example_config("packing_slip.rb")

    expect(config).to start_with("page size: :a4, layout: :landscape")
    expect(config).to include("footer {")
    expect(config).not_to include("def ")
  end

  it "reads one method of an example, dedented" do
    method = described_class.example_method("packing_slip.rb", "barcode")

    expect(method).to start_with("def barcode\n")
    expect(method).to end_with("\nend\n")
    expect(method).to include("canvas(height: 40)")
  end
end
