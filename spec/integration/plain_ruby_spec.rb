# frozen_string_literal: true

require "bundler"
require "open3"
require "rbconfig"

# The suite loads pathname, stringio and the rest through its own helpers, so
# a library file that forgets to require what it uses still passes every
# other spec. This one renders in a fresh interpreter that has required
# nothing but the gem, the way a plain Ruby script does.
RSpec.describe "stationery in plain Ruby" do
  let(:lib) { File.expand_path("../../lib", __dir__) }
  let(:photo) { File.expand_path("../fixtures/images/rgb.jpg", __dir__) }
  let(:script) do
    <<~RUBY
      require "stationery"

      class Everything < Stationery::Document
        metadata title: "Plain", lang: "en"
        tagged

        def initialize(photo) = (super(); @photo = photo)

        def view_template
          text "Plain <b>Ruby</b> &amp; nothing else", markup: true, hyphenate: true
          File.open(@photo, "rb") { |io| image io, width: 40, alt: "from a File" }
          require "stringio" # the caller's own choice of IO
          image StringIO.new(File.binread(@photo)), width: 40, alt: "from a StringIO"
          image File.join(File.dirname(@photo), "webp/alpha.webp"), width: 40, alt: "a lossless WebP"
          html "<h2>Heading</h2><p>A <a href='https://example.test'>link</a></p><ul><li>one</li></ul>"
          markdown "> quoted\\n\\n1. first\\n2. second"
          table [%w[Item Price], %w[Tea 3.50]], header: true
          columns(count: 2, rule: true) { 4.times { |i| text "Column line \#{i}" } }
          svg %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="5" height="5"/></svg>),
              width: 20, alt: "a square"
          text_field "name", value: "Ada", width: 120
          checkbox "agree", checked: true, label: "Agree"
        end
      end

      right_to_left = lambda do |text, font, **|
        ttf = Stationery::Fonts::Registry.load(font.path)
        text.each_char.with_index.map do |char, index|
          gid = ttf.glyph_id(char.ord)
          Stationery::Shaper::Glyph.new(gid:, advance: ttf.advance(gid), cluster: index)
        end.reverse
      end
      options = { "encrypted" => { encrypt: { owner_password: "o", user_password: "u" } },
                  "archival" => { conformance: %i[pdf_a3b pdf_ua1] },
                  "shaped" => { shaper: right_to_left } }.fetch(ARGV[1].to_s, {})
      document = Everything.new(ARGV.fetch(0))
      pdf = document.to_pdf(attachments: [{ name: "note.txt", data: "hello", mime: "text/plain" }], **options)
      abort "warnings: \#{document.warnings.map(&:message).inspect}" if document.warnings.any?
      $stdout.binmode
      $stdout.write(pdf)
    RUBY
  end

  def run(*)
    Bundler.with_unbundled_env { Open3.capture3(RbConfig.ruby, "-I", lib, "-e", script, *, binmode: true) }
  end

  it "renders images from IOs, rich text, tables, SVG, forms and attachments with no require but the gem's" do
    output, errors, status = run(photo)

    expect(status).to be_success, "exit #{status.exitstatus}: #{errors}"
    expect(output).to start_with("%PDF")
    expect(output.bytesize).to be > 5_000
  end

  it "encrypts, writes PDF/A with PDF/UA and draws what a shaper placed the same way" do
    %w[encrypted archival shaped].each do |mode|
      output, errors, status = run(photo, mode)

      expect(status).to be_success, "#{mode}: exit #{status.exitstatus}: #{errors}"
      expect(output).to start_with("%PDF")
    end
  end
end
