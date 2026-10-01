# frozen_string_literal: true

require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
namespace :spec do
  desc "Run the Rails integration specs (BUNDLE_GEMFILE=gemfiles/rails.gemfile)"
  RSpec::Core::RakeTask.new(:rails) do |task|
    ENV["COVERAGE"] = "false" # the lane covers the Railtie only; keep coverage/ for the main suite
    task.pattern = "spec/rails/**/*_spec.rb"
    task.exclude_pattern = ""
  end
end
RuboCop::RakeTask.new

desc "Render every example under examples/ to a PDF next to it"
task :examples do
  Dir["examples/*.rb"].each { |file| ruby "-Ilib", file }
end

namespace :docs do
  desc "Render the first page of every example to docs/public/examples/<name>.png (needs pdftoppm)"
  task :examples do
    require "tmpdir"
    out = "docs/public/examples"
    mkdir_p out
    Dir.mktmpdir do |dir|
      Dir["examples/*.rb"].each do |file|
        name = File.basename(file, ".rb")
        pdf = File.join(dir, "#{name}.pdf")
        ruby "-Ilib", "exe/stationery", "render", file, "--out", pdf
        sh "pdftoppm", "-png", "-r", "72", "-f", "1", "-l", "1", "-singlefile", pdf, File.join(out, name)
      end
    end
  end
end

namespace :verify do
  example = lambda do |name|
    constant = "Example#{name.split("_").map(&:capitalize).join}"
    load File.expand_path("examples/#{name}.rb", __dir__) unless Object.const_defined?(constant)
    Object.const_get(constant).preview
  end

  # An example with a link in its footer: the one thing of a footer that is
  # in the structure tree.
  linked = lambda do |name|
    Class.new(example.call(name).class) do
      footer(gap: 14) { text "northwind.example", link: "https://northwind.example", size: 7, align: :center }
    end.preview
  end

  # A key and a self-signed certificate for it, good for an hour: what the
  # signed renders below are signed with.
  identity = lambda do
    require "openssl"
    key = OpenSSL::PKey::RSA.new(2048)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = 1
    certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse("/C=SE/O=Stationery/CN=Stationery verify")
    certificate.public_key = key
    certificate.not_before = Time.now - 60
    certificate.not_after = Time.now + 3600
    certificate.sign(key, "SHA256")
    { certificate:, key:, reason: "rake verify" }
  end

  # Runs veraPDF on `file` in `dir` for `flavour` and answers whether it
  # passed: a `verapdf` on the PATH when there is one (Homebrew's, say), else
  # the Docker image, which is what CI runs. VERAPDF_IMAGE forces the image.
  verapdf = lambda do |dir, file, flavour|
    arguments = ["--format", "text", "-v", "--flavour", flavour]
    if !ENV["VERAPDF_IMAGE"] && system("which verapdf > #{File::NULL} 2>&1")
      sh("verapdf", *arguments, File.join(dir, file)) { |ok, _| ok }
    else
      sh("docker", "run", "--rm", "--platform", "linux/amd64", "-v", "#{dir}:/data:ro",
         ENV.fetch("VERAPDF_IMAGE", "verapdf/cli:latest"), *arguments, "/data/#{file}") { |ok, _| ok }
    end
  end

  # The renders veraPDF validates, by name: the levels each claims, and the
  # veraPDF flavour of each.
  conformance = { "invoice" => { pdf_a3b: "3b" }, "report" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                  "e_invoice" => { pdf_a3b: "3b" }, "form" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                  "article" => { pdf_ua1: "ua1", pdf_a3b: "3b" }, "newsletter" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                  "signed_invoice" => { pdf_a3b: "3b" }, "signed_form" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                  "linked_report" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                  "accessible_report" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                  "price_card" => { pdf_ua1: "ua1", pdf_a3b: "3b" } }

  # Writes the render `name` of `conformance` to `path`: an example, signed
  # when the name says so, with a linked footer when it says so.
  conforming = lambda do |name, path|
    options = { conformance: conformance.fetch(name).keys }
    options[:sign] = identity.call if name.start_with?("signed_")
    options[:sign][:field] = "signature" if name == "signed_form"
    source = name.delete_prefix("signed_")
    document = source.start_with?("linked_") ? linked.call(source.delete_prefix("linked_")) : example.call(source)
    document.to_pdf(path, **options)
  end

  desc "Validate PDF/A-3b and PDF/UA-1 renders of the examples, plain and signed, with veraPDF " \
       "(a local verapdf, else Docker)"
  task :conformance do
    $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
    require "stationery"
    out = File.expand_path("tmp/conformance", __dir__)
    mkdir_p out
    failures = conformance.flat_map do |name, levels|
      conforming.call(name, File.join(out, "#{name}.pdf"))
      failed = levels.values.reject { |flavour| verapdf.call(out, "#{name}.pdf", flavour) }
      failed.map { |flavour| "#{name}.pdf is not #{flavour}" }
    end
    abort failures.join("\n") if failures.any?
  end

  readers = File.expand_path("tmp/readers", __dir__)
  # The user password of the encrypted file of the readers' corpus.
  password = "reader"

  namespace :readers do
    desc "Render the corpus verify:readers checks to tmp/readers/: every example, the conformance renders, " \
         "an encrypted invoice, a packed invoice and an unpacked tagged report"
    task :render do
      $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
      require "stationery"
      rm_rf readers
      mkdir_p readers
      Dir[File.expand_path("examples/*.rb", __dir__)].map { |file| File.basename(file, ".rb") }.sort.each do |name|
        example.call(name).to_pdf(File.join(readers, "#{name}.pdf"))
      end
      conformance.each_key { |name| conforming.call(name, File.join(readers, "conforming_#{name}.pdf")) }
      example.call("invoice").to_pdf(File.join(readers, "encrypted_invoice.pdf"),
                                     encrypt: { user_password: password, owner_password: "verify-owner" })
      example.call("invoice").to_pdf(File.join(readers, "packed_invoice.pdf"), object_streams: true)
      example.call("accessible_report").to_pdf(File.join(readers, "unpacked_accessible_report.pdf"),
                                               object_streams: false)
    end
  end

  desc "Check the readers' corpus (verify:readers:render) in the engines viewers are built on: qpdf, Poppler, " \
       "MuPDF, PDFium, pdf.js, PDFKit (ENGINES=qpdf,poppler,… to choose; default every one installed)"
  task readers: "readers:render" do
    require "stationery/verify"
    engines = ENV["ENGINES"] ? Stationery::Verify.adapters(ENV["ENGINES"].split(",")) : Stationery::Verify.adapters
    missing = engines.reject(&:available?)
    if ENV["ENGINES"] && missing.any?
      abort "not installed: #{missing.map do |one|
        "#{one.name} (#{one.install})"
      end.join(", ")}"
    end

    files = Dir[File.join(readers, "*.pdf")]
    encrypted = files.grep(/encrypted_/)
    plain = Stationery::Verify.run(files - encrypted, engines:)
    locked = Stationery::Verify.run(encrypted, engines:, password:)
    report = plain.with(results: plain.results + locked.results)
    puts report.lines
    abort "verify:readers failed" unless report.passed?
  end

  desc "Verify a signed render of the invoice example with openssl, and with pdfsig when it is installed " \
       "(TSA_URL=http://… also timestamps it; with Docker, veraPDF checks the timestamped PDF/A-3b)"
  task :signature do
    $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
    require "stationery"
    require "stationery/testing/inspector"
    out = File.expand_path("tmp/signature", __dir__)
    mkdir_p out
    pdf = example.call("invoice").to_pdf(File.join(out, "invoice.pdf"), sign: identity.call)
    signature = Stationery::Testing::Inspector.new(pdf).signatures.first
    range = signature.fetch(:byte_range)
    cms = Stationery::PDF::Signature.der([pdf.byteslice(range[1] + 1, range[2] - range[1] - 2)].pack("H*"))
    File.binwrite(File.join(out, "invoice.der"), cms)
    File.binwrite(File.join(out, "invoice.bin"), pdf.byteslice(range[0], range[1]) + pdf.byteslice(range[2], range[3]))
    abort "invoice.pdf does not verify: #{signature}" unless signature[:valid]

    sh "openssl", "cms", "-verify", "-inform", "DER", "-in", File.join(out, "invoice.der"),
       "-content", File.join(out, "invoice.bin"), "-binary", "-noverify", "-out", File::NULL
    next puts("pdfsig is not installed (poppler): skipped") unless system("which pdfsig > #{File::NULL} 2>&1")

    report = `pdfsig -nocert #{File.join(out, "invoice.pdf")} 2>&1`
    puts report
    abort "pdfsig does not call the signature valid" unless report.include?("Signature is Valid") &&
                                                            report.include?("Total document signed")
    Rake::Task["verify:timestamp"].invoke if ENV["TSA_URL"]
  end

  # Not part of CI: it needs the network and a time-stamping authority.
  desc "Timestamp a signed PDF/A-3b render of the invoice example at TSA_URL and verify it"
  task :timestamp do
    $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
    require "stationery"
    require "stationery/testing/inspector"
    url = ENV.fetch("TSA_URL") { abort "set TSA_URL to an RFC 3161 time-stamping authority" }
    out = File.expand_path("tmp/signature", __dir__)
    mkdir_p out
    path = File.join(out, "timestamped_invoice.pdf")
    pdf = example.call("invoice").to_pdf(path, sign: identity.call.merge(timestamp: url), conformance: :pdf_a3b)
    signature = Stationery::Testing::Inspector.new(pdf).signatures.first
    puts "timestamp: #{signature[:timestamp]}"
    abort "the timestamp from #{url} does not verify" unless signature[:valid] && signature.dig(:timestamp, :valid)

    if system("which pdfsig > #{File::NULL} 2>&1")
      report = `pdfsig -nocert #{path} 2>&1`
      puts report
      abort "pdfsig does not call the timestamped signature valid" unless report.include?("Signature is Valid")
    end
    unless system("which verapdf > #{File::NULL} 2>&1") || system("which docker > #{File::NULL} 2>&1")
      next puts("neither verapdf nor docker is installed: veraPDF skipped")
    end

    abort "timestamped_invoice.pdf is not 3b" unless verapdf.call(out, "timestamped_invoice.pdf", "3b")
  end

  desc "Validate the Factur-X example (PDF/A-3 and its EN 16931 XML) with Mustang (needs Docker)"
  task :factur_x do
    require "digest"
    require "open-uri"
    require "open3"
    $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
    require "stationery"
    out = File.expand_path("tmp/factur_x", __dir__)
    mkdir_p out
    version = ENV.fetch("MUSTANG_VERSION", "2.26.0")
    jar = File.join(out, "Mustang-CLI-#{version}.jar")
    unless File.exist?(jar)
      url = "https://github.com/ZUGFeRD/mustangproject/releases/download/core-#{version}/Mustang-CLI-#{version}.jar"
      File.binwrite(jar, URI.parse(url).open("rb", &:read))
    end
    sha = "42d7868cb68264874a7b8cab4c3587b03b23ccc7cd72373da917f66758bb9736"
    if version == "2.26.0" && Digest::SHA256.file(jar).hexdigest != sha
      rm jar
      abort "Mustang-CLI-#{version}.jar does not match its pinned SHA-256; removed it, run the task again"
    end

    example.call("e_invoice").to_pdf(File.join(out, "e_invoice.pdf"))
    image = ENV.fetch("MUSTANG_IMAGE", "eclipse-temurin:21-jre")
    report, status = Open3.capture2e(
      "docker", "run", "--rm", "-v", "#{out}:/data", "-w", "/data", image,
      "java", "-Xmx1G", "-Dfile.encoding=UTF-8", "-jar", "/data/#{File.basename(jar)}",
      "--action", "validate", "--source", "/data/e_invoice.pdf", "--no-notices"
    )
    puts report[/<validation.*/m] || report
    valid = report.scan(/<summary status="(\w+)"/).flatten
    abort "e_invoice.pdf is not a valid Factur-X invoice" unless status.success? && valid.any? && valid.all?("valid")
  end
end

task default: %i[spec rubocop]

desc "Benchmark against Prawn and, when its gem is installed, sghtmltopdf (bundle exec rake bench)"
task :bench do
  ruby "-Ilib benchmark/invoice.rb"
  ruby "-Ilib benchmark/table_50_pages.rb"
  ruby "-Ilib benchmark/photos.rb"
end

desc "Compare allocations, pages and bytes of fixed documents with benchmark/baseline.json"
task :metrics do
  ruby "-Ilib benchmark/metrics.rb"
end

namespace :metrics do
  desc "Record benchmark/baseline.json for this Ruby, after a change made on purpose"
  task :update do
    ruby "-Ilib benchmark/metrics.rb --update"
  end
end

desc "Report what long documents hold in memory while they render (PAGES=1000; not part of CI)"
task :memory do
  ruby "-Ilib benchmark/memory.rb"
end

namespace :fonts do
  desc "Download every font pack in the catalog and check its SHA-256s (needs network; not run in CI)"
  task :verify do
    require "tmpdir"
    require_relative "lib/stationery"
    Dir.mktmpdir do |dir|
      installer = Stationery::Fonts::Installer.new(into: dir, out: $stdout)
      Stationery::Fonts.catalog.each { |pack| installer.install(pack.key) }
    end
    puts "all font packs verified"
  end
end

# `rake release[X.Y.Z]` lives in rakelib/release.rake (the zoolutions release
# kit, shared verbatim across the gems); `bin/release` is its front door.
