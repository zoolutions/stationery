# frozen_string_literal: true

require_relative "../../examples/certificate"

RSpec.describe "the example certificate" do
  let(:document) { ExampleCertificate.preview }
  let(:pdf) { document.to_pdf }
  let(:page) { inspect_pdf(pdf).layout[:pages].first }

  def line(start) = page[:text].find { |run| run[:text].start_with?(start) }

  it "fits on one landscape A4 page without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
    expect(page.values_at(:width, :height)).to eq([841.9, 595.3])
  end

  it "centres its type: lines of other lengths start at other places, none at the margin" do
    starts = ["HARBOUR", "Certificate of", "This is", "Robin", "Awarded"].map { |start| line(start)[:x] }

    expect(starts.uniq.size).to eq(starts.size)
    expect(starts).to all(be > 110 + 20)
  end

  it "has a signature field for each signer, and nothing signed" do
    expect(page[:fields].map { |field| field.values_at(:name, :type) })
      .to eq([["director", :signature], ["examiner", :signature]])
    expect(document.fields).to eq("director" => nil, "examiner" => nil)
  end

  it "paints the frame first, under the text" do
    content = page_contents(pdf).first

    expect(content.index(" re")).to be < content.index("BT")
  end
end
