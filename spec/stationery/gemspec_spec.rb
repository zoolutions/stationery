# frozen_string_literal: true

require "open3"
require "tmpdir"

RSpec.describe "stationery.gemspec" do # rubocop:disable RSpec/DescribeClass
  let(:root) { File.expand_path("../..", __dir__) }
  let(:bundled) do
    %w[Inter-Regular.ttf Inter-Bold.ttf Inter-Italic.ttf Inter-BoldItalic.ttf OFL.txt]
      .map { |f| "lib/stationery/fonts/data/#{f}" }
  end
  let(:examples) { Dir.glob("examples/**/*", base: root).select { File.file?(File.join(root, it)) } }

  def files = Gem::Specification.load(File.join(root, "stationery.gemspec")).files

  it "ships the bundled fonts and their license" do
    expect(files).to include(*bundled)
  end

  it "ships the examples with what they read, and no render of them" do
    sources = examples.reject { it.end_with?(".pdf") }

    expect(sources).to include("examples/invoice.rb", "examples/assets/logo.png", "examples/shaping/harfbuzz_shaper.rb")
    expect(files).to include(*sources)
    expect(files).not_to include(a_string_ending_with(".pdf"))
  end

  it "ships nothing of the test suite: Inter is the one font in the gem" do
    expect(files.grep(%r{\Aspec/})).to be_empty
  end

  it "ships them without git as well" do
    File.write(File.join(root, "examples/rendered.pdf"), "%PDF")
    allow(IO).to receive(:popen).and_return(nil)

    expect(files).to include(*bundled, "examples/report.rb", "examples/assets/bay.png",
                             "examples/shaping/extraction_matrix/pdfium.py")
    expect(files.grep(%r{\Aspec/})).to be_empty
    expect(files).not_to include(a_string_ending_with(".pdf"))
  ensure
    File.delete(File.join(root, "examples/rendered.pdf"))
  end

  # What an application has: examples/ and lib/, and no spec/ beside them.
  it "renders the invoices from the examples alone, in the bundled Inter" do
    Dir.mktmpdir do |dir|
      FileUtils.cp_r(File.join(root, "examples"), dir)
      script = "require 'stationery'; load '#{dir}/examples/e_invoice.rb'; " \
               "print ExampleInvoice.preview.to_pdf.bytesize, ' ', ExampleEInvoice.preview.to_pdf.bytesize, ' ', " \
               "ExampleInvoice.config[:text][:font]"
      out, err, status = Open3.capture3(RbConfig.ruby, "-I", File.join(root, "lib"), "-e", script)

      expect(status).to be_success, err
      expect(out.split).to match([/\A\d+\z/, /\A\d+\z/, "Inter"])
    end
  end
end
