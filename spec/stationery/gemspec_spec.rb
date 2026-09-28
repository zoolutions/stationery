# frozen_string_literal: true

RSpec.describe "stationery.gemspec" do # rubocop:disable RSpec/DescribeClass
  let(:root) { File.expand_path("../..", __dir__) }
  let(:bundled) do
    %w[Inter-Regular.ttf Inter-Bold.ttf Inter-Italic.ttf Inter-BoldItalic.ttf OFL.txt]
      .map { |f| "lib/stationery/fonts/data/#{f}" }
  end
  let(:examples) { Dir.glob("examples/**/*", base: root).select { File.file?(File.join(root, it)) } }
  let(:example_fonts) do
    %w[OpenSans-Regular.ttf OpenSans-Bold.ttf OpenSans-Italic.ttf OpenSans-BoldItalic.ttf OpenSans-LICENSE.txt]
      .map { |f| "spec/fixtures/fonts/#{f}" }
  end

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

  it "ships the files an example reads from outside examples/" do
    read = examples.grep(/\.rb\z/).flat_map do |example|
      File.read(File.join(root, example)).scan(%r{"\.\./(spec/[\w/.-]+)"}).flatten
    end

    expect(read.uniq).to eq(["spec/fixtures/fonts"])
    expect(files.grep(%r{\Aspec/})).to match_array(example_fonts)
  end

  it "ships them without git as well" do
    File.write(File.join(root, "examples/rendered.pdf"), "%PDF")
    allow(IO).to receive(:popen).and_return(nil)

    expect(files).to include(*bundled, *example_fonts, "examples/report.rb", "examples/assets/bay.png",
                             "examples/shaping/extraction_matrix/pdfium.py")
    expect(files).not_to include(a_string_ending_with(".pdf"))
  ensure
    File.delete(File.join(root, "examples/rendered.pdf"))
  end
end
