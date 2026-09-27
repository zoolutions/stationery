# frozen_string_literal: true

RSpec.describe "stationery.gemspec" do # rubocop:disable RSpec/DescribeClass
  let(:root) { File.expand_path("../..", __dir__) }
  let(:bundled) do
    %w[Inter-Regular.ttf Inter-Bold.ttf Inter-Italic.ttf Inter-BoldItalic.ttf OFL.txt]
      .map { |f| "lib/stationery/fonts/data/#{f}" }
  end

  def files = Gem::Specification.load(File.join(root, "stationery.gemspec")).files

  it "ships the bundled fonts and their license" do
    expect(files).to include(*bundled)
    expect(files).not_to include(a_string_starting_with("spec/"))
  end

  it "ships them without git as well" do
    allow(IO).to receive(:popen).and_return(nil)

    expect(files).to include(*bundled)
  end
end
