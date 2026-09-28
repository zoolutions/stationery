# frozen_string_literal: true

require_relative "../../examples/contract"

RSpec.describe "the example contract" do
  let(:document) { ExampleContract.preview }
  let(:pdf) { document.to_pdf }
  let(:pages) { inspect_pdf(pdf).layout[:pages] }

  it "runs over two pages without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(2)
  end

  it "numbers every clause and its sub-clauses, and keeps each heading with its text" do
    lines = pages.flat_map { |page| page[:text].map { |run| [page[:number], run[:text]] } }
    headings = lines.select { |_, text| text.match?(/\A\d+\. /) }

    expect(headings.map(&:last)).to eq(ExampleContract::CLAUSES.each_with_index.map { |(title, _), i| "#{i + 1}. #{title}" })
    headings.each do |number, text|
      clause = text[/\A\d+/]
      expect(lines).to include([number, "#{clause}.1"])
    end
  end

  it "has a box for both parties' initials on every page, one field each" do
    fields = pages.map { |page| page[:fields].map { |field| field[:name] }.grep(/\Ainitials/) }

    expect(fields).to eq([%w[initials.provider.1 initials.client.1], %w[initials.provider.2 initials.client.2]])
  end

  it "signs the provider's signature field when it is rendered with a certificate" do
    signed = document.to_pdf(sign: { certificate: signer.certificate, key: signer.key, field: "signature.provider" })

    expect(signed).to have_signature(name: "Test Signer rsa")
    expect(inspect_pdf(signed).signatures.map { |signature| signature[:field] }).to eq(["signature.provider"])
  end
end
