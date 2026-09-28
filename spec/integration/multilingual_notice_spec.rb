# frozen_string_literal: true

require "open3"
require_relative "../../examples/multilingual_notice"

RSpec.describe "the example multilingual notice" do
  let(:document) { ExampleMultilingualNotice.preview }
  let(:pdf) { document.to_pdf }
  let(:lines) { inspect_pdf(pdf).layout[:pages].first[:text] }

  it "fits on one page in the bundled Inter, without warnings and without a CJK font" do
    expect(ExampleMultilingualNotice::CJK_FONT).to be_nil
    expect(document).to have_no_warnings
    expect(pdf).to have_page_count(1)
    expect(lines.map { |run| run[:font] }.uniq).to contain_exactly("Inter-Regular", "Inter-Bold")
  end

  it "sets the three languages side by side" do
    titles = ["Water will be turned", "Das Wasser wird", "Vattnet stängs av"].map do |start|
      lines.find { |run| run[:text].start_with?(start) }
    end

    expect(titles.map { |run| run[:x] }).to eq(titles.map { |run| run[:x] }.sort)
    expect(titles.map { |run| run[:y] }.uniq.size).to eq(1)
  end

  it "hyphenates each column by its own language" do
    columns = lines.select { |run| run[:size].between?(10, 11) }.group_by { |run| (run[:x] / 170).floor }.values
    broken = columns.map { |runs| runs.map { |run| run[:text] }.grep(/\p{L}-\z/) }

    expect(broken.map(&:size)).to all(be_positive)
    expect(broken.flatten).to include("Wohnungen im Gebäude zwi-").or include(a_string_ending_with("-"))
  end

  # CJK_FONT is read when the class is defined, so this one is rendered in a
  # process of its own, with the Noto Sans JP subset of the test suite (it
  # has 日, 本 and 語, and draws the others as missing).
  it "draws the Japanese paragraph from the CJK font as a fallback, Inter keeping the digits" do
    script = "require 'stationery/testing/inspector'; load 'examples/multilingual_notice.rb'; " \
             "pdf = ExampleMultilingualNotice.preview.to_pdf; " \
             "puts Stationery::Testing::Inspector.new(pdf).layout[:pages][0][:text]" \
             ".select { it[:text].match?(/[0-9日]/) && it[:y] > 450 }.map { it[:font] }.uniq"
    out, status = Open3.capture2e({ "CJK_FONT" => font_path("NotoSansJP-Subset.otf") }, RbConfig.ruby,
                                  "-I", File.join(RenderDigests::ROOT, "lib"), "-rstationery", "-e", script,
                                  chdir: RenderDigests::ROOT)

    expect(status).to be_success, out
    expect(out.lines.map(&:chomp)).to include("Inter-Regular", a_string_including("NotoSansJP"))
  end
end
