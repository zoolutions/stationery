# frozen_string_literal: true

require_relative "../../examples/accessible_report"

RSpec.describe "the example accessible report" do
  let(:document) { ExampleAccessibleReport.preview }
  let(:pdf) { document.to_pdf }
  let(:structure) { inspect_pdf(pdf).structure.to_s }

  it "claims PDF/UA-1 and renders without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_conformance(:pdf_ua1)
    expect(pdf).to have_pdf_language("en")
    expect(pdf).to have_tagged_content
  end

  it "tags its headings in order, one level at a time" do
    expect(structure.scan(/:(H\d)\b/).flatten).to eq(%w[H1 H2 H2 H3 H3 H2])
  end

  it "describes the photo and the chart as figures" do
    expect(structure.scan(":Figure").size).to eq(2)
    expect(structure).to include("Green hills under a yellow morning sky", "Bar chart of the share of pupils")
  end

  it "tags the table's first row as header cells" do
    expect(structure.scan(":TH,").size).to eq(5)
    expect(structure.scan(":TR,").size).to eq(6)
  end

  it "raises instead of claiming PDF/UA-1 for a figure without a description" do
    broken = Class.new(ExampleAccessibleReport) do
      define_method(:view_template) do
        text "Report", heading: 1
        image ExampleAccessibleReport::PHOTO, width: 100
      end
    end

    expect { broken.preview.to_pdf }.to raise_error(Stationery::ConformanceError)
  end
end
