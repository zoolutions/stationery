# frozen_string_literal: true

RSpec.describe "Rendering ActionText HTML" do
  let(:source) { File.read(File.expand_path("../fixtures/html/trix.html", __dir__)) }
  let(:doc) do
    body = source
    Class.new(SpecDocument) do
      page size: [400, 600], margin: 20
      define_method(:view_template) { html body }
    end.new
  end
  let(:pdf) { doc.to_pdf }

  it "renders every block in order" do
    expect(text_of(pdf).split(/[[:space:]]+/))
      .to eq("Release notes Hello team, the build is green. Details: Faster renders Fewer bugs Ship it. " \
             "bin/deploy --prod Thanks all".split)
  end

  it "links, draws a disc per list item and warns about nothing" do
    expect(pdf).to have_pdf_link("https://example.test/perf?a=1&b=2")
    expect(link_rects(pdf).size).to eq(1)
    expect(page_contents(pdf).first.scan(/0 0 0 rg\n[\d.]+ [\d.]+ m\n/).size).to eq(2)
    expect(doc).to have_no_warnings
  end
end
