# frozen_string_literal: true

require "stationery/cli"
require "tmpdir"
require_relative "../../examples/form"

RSpec.describe "the example application form" do
  let(:document) { ExampleForm.preview }
  let(:pdf) { document.to_pdf }

  it "fits on one page without warnings" do
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
  end

  it "uses every kind of field" do
    types = form_fields(pdf).values.map { |field| field[:FT] }.uniq

    expect(types).to contain_exactly(:Tx, :Btn, :Ch, :Sig)
    expect(form_fields(pdf).keys).to include("applicant.name", "applicant.email", "plan", "terms", "signature")
  end

  it "prints the headings and the choice labels" do
    expect(text_of(pdf)).to include("Membership application", "Applicant", "Basic", "I accept the terms")
  end

  it "renders through the CLI" do
    Dir.mktmpdir do |dir|
      out = File.join(dir, "form.pdf")
      status = Stationery::CLI.start(["render", File.expand_path("../../examples/form.rb", __dir__), "-o", out],
                                     out: StringIO.new, err: StringIO.new)

      expect(status).to eq(0)
      expect(form_fields(File.binread(out))).to have_key("applicant.name")
    end
  end
end
