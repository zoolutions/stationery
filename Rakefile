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

  desc "Validate PDF/A-3b and PDF/UA-1 renders of the examples, plain and signed, with veraPDF " \
       "(a local verapdf, else Docker)"
  task :conformance do
    $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
    require "stationery"
    out = File.expand_path("tmp/conformance", __dir__)
    mkdir_p out
    renders = { "invoice" => { pdf_a3b: "3b" }, "report" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                "e_invoice" => { pdf_a3b: "3b" }, "form" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                "article" => { pdf_ua1: "ua1", pdf_a3b: "3b" }, "newsletter" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                "signed_invoice" => { pdf_a3b: "3b" }, "signed_form" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                "linked_report" => { pdf_ua1: "ua1", pdf_a3b: "3b" },
                "accessible_report" => { pdf_ua1: "ua1", pdf_a3b: "3b" } }
    failures = renders.flat_map do |name, levels|
      options = { conformance: levels.keys }
      options[:sign] = identity.call if name.start_with?("signed_")
      options[:sign][:field] = "signature" if name == "signed_form"
      source = name.delete_prefix("signed_")
      document = source.start_with?("linked_") ? linked.call(source.delete_prefix("linked_")) : example.call(source)
      document.to_pdf(File.join(out, "#{name}.pdf"), **options)
      failed = levels.values.reject { |flavour| verapdf.call(out, "#{name}.pdf", flavour) }
      failed.map { |flavour| "#{name}.pdf is not #{flavour}" }
    end
    abort failures.join("\n") if failures.any?
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

# Console output for the release task.
def info(msg) = puts "\e[34m→\e[0m #{msg}"
def success(msg) = puts "\e[32m✓\e[0m #{msg}"
def skip(msg) = puts "\e[33m⊘\e[0m #{msg} \e[33m(skipped)\e[0m"
def header(msg) = puts "\n\e[1;36m#{msg}\e[0m\n#{"─" * msg.length}"

desc "Release a new version (rake release[1.2.3] or rake release[pre] or rake release[1.2.3,force])"
task :release, %i[version force] do |_t, args|
  require_relative "lib/stationery/version"

  new_version = args[:version]
  abort "\e[31mUsage: rake release[X.Y.Z] or rake release[X.Y.Z,force]\e[0m" unless new_version

  force = args[:force]&.to_s&.downcase == "force"

  dirty = `git status --porcelain`.strip
  abort "\e[31mAborting: working directory is not clean.\e[0m\n#{dirty}" unless dirty.empty?

  current = Stationery::VERSION
  prerelease = new_version.match?(/alpha|beta|rc|pre/) || new_version == "pre"

  if new_version == "pre"
    new_version = current
    prerelease = true
  end

  tag = "v#{new_version}"
  version_file = "lib/stationery/version.rb"

  title = "Release #{tag}"
  title += " (force)" if force
  header title
  info "Current version: #{current}"
  info "New version:     #{new_version}"
  info "Pre-release:     #{prerelease}"

  # Step 0a: PREFLIGHT the lockfiles — read and validate every one BEFORE the
  # task does ANYTHING destructive or irreversible. It must precede BOTH:
  #
  #   * the force cleanup below, which DELETES the GitHub release and its tag
  #     (aborting after that has thrown away release notes and assets for a
  #     problem we could have seen first), and
  #   * Step 1/1b's writes — aborting after version.rb is bumped, or after the
  #     first lockfile is rewritten, leaves a DIRTY tree that the clean-tree
  #     guard above then blocks on the next run: a half-done release that
  #     cannot be retried without manual cleanup. That is exactly the state
  #     an earlier release attempt left behind.
  #
  # It only READS files, so there is no cost to running it first — and every
  # reason to.
  #
  # Zero matches is not "already current": it means the file does not pin the
  # gem the way we think it does (a renamed gem, a changed lockfile format, a
  # file that never belonged in the list). Proceeding would ship version.rb
  # bumped against a lockfile still naming the old version — the stale-lockfile
  # release #247 exists to prevent, only silent.
  #
  # Matches the PATH-source spec ("    stationery (X.Y.Z)") and the
  # CHECKSUMS pin ("  stationery (X.Y.Z)"), leaving everything else
  # untouched. The DEPENDENCIES entry is the version-less "stationery!",
  # which carries no version and so is deliberately not matched.
  pin_pattern = /^(\s+stationery) \(([^)]*)\)$/
  lockfiles = %w[Gemfile.lock docs/Gemfile.lock].select { File.exist?(it) }
  locks = lockfiles.to_h { [it, File.read(it)] }
  locks.each do |lockfile, content|
    next unless content.scan(pin_pattern).empty?

    abort "\e[31mAborting: #{lockfile} contains no `stationery (X.Y.Z)` pin to bump.\e[0m\n" \
          "Either the lockfile format changed or this file does not pin the gem — fix it (or drop " \
          "it from the list in the release task) before releasing. Nothing has been modified."
  end

  # Step 0b: Force cleanup — delete existing release and tag
  if force
    header "Force cleanup"
    if system("gh release view #{tag} >/dev/null 2>&1")
      sh("gh release delete #{tag} --yes --cleanup-tag")
      success "Deleted release and remote tag #{tag}"
    else
      skip "No release #{tag} to delete"
    end

    if system("git rev-parse #{tag} >/dev/null 2>&1")
      sh("git tag -d #{tag}")
      success "Deleted local tag #{tag}"
    else
      skip "No local tag #{tag} to delete"
    end
  end

  # Step 1: Update version file
  header "Version"
  if new_version == current
    skip "Version already #{new_version}"
  else
    content = File.read(version_file)
    content.sub!(/VERSION = ".*"/, "VERSION = \"#{new_version}\"")
    File.write(version_file, content)
    success "Updated #{version_file}"
  end

  # Step 1b: Bump the pin in every tracked Gemfile.lock that carries this gem
  # via a local path — the root one (`gemspec` in ./Gemfile, committed since
  # #246) and the docs site's (`path: ".."`). Both carry the version string, so
  # bumping version.rb without them leaves a committed lockfile stale: the
  # Release workflow's frozen `bundle install` then refuses it ("gemspecs for
  # path gems changed, but the lockfile can't be updated because frozen mode is
  # set") and every fresh `bundle install` dirties the tree.
  #
  # The ONLY thing a version bump changes in these lockfiles is the path-gem
  # pin — so bump exactly that line, in place, with a string edit. We
  # deliberately do NOT run `bundle lock` (with or without --local): it is a
  # full re-resolve, and a re-resolve trips over constraints that have nothing
  # to do with this gem. Concretely, docs/Gemfile.lock declares Linux
  # PLATFORMS for the Kamal deploy, and `bundle lock --local` refuses to
  # resolve a platform gem like `thruster` for those against a Mac's installed
  # gems ("Could not find gems matching 'thruster' valid for all resolution
  # platforms") — which aborted an earlier release attempt, mid-release, with
  # version.rb already bumped. It also re-resolves the WHOLE lock the moment a
  # Gemfile drifted from its lock, silently folding an unrelated dependency
  # jump into the release commit (pgbus was already stale-locked in docs/
  # exactly this way). pgbus's release task hit the same thruster failure and
  # made the same call. A targeted pin edit is deterministic on any machine,
  # needs no network and no installed gems, and yields the minimal diff: the
  # PATH spec line plus the CHECKSUMS line. Committed alongside the bump in
  # Step 3. Any OTHER tracked lockfile pinning the gem belongs in this list.
  header "Lockfiles"
  locks.each do |lockfile, content|
    pins = content.scan(pin_pattern)
    if pins.all? { |_prefix, version| version == new_version }
      # A genuine re-run after a partial failure: the pins ARE there and already
      # current. Distinguishable from the zero-pin case (which aborted in the
      # preflight) only because we counted rather than comparing strings.
      skip "#{lockfile} — #{pins.size} pin(s) already #{new_version}"
      next
    end

    File.write(lockfile, content.gsub(pin_pattern, "\\1 (#{new_version})"))
    success "Bumped #{pins.size} stationery pin(s) in #{lockfile}"
  end
  skip "No tracked lockfiles" if locks.empty?

  # Step 2: Verify gem builds cleanly
  header "Build verification"
  sh("gem build stationery.gemspec --strict")
  sh("rm -f stationery-*.gem")
  success "Gem builds cleanly"

  # Step 3: Commit the version bump + the re-locked lockfiles together, so a
  # release never leaves a stale/dirty committed lockfile behind. The guard fires
  # when EITHER the version file OR any lockfile changed (a re-run where only a
  # lockfile drifted — like an earlier release attempt — still commits).
  header "Git commit"
  release_files = [version_file, *lockfiles]
  changed = release_files.any? do |f|
    !`git diff #{f}`.strip.empty? || !`git diff --cached #{f}`.strip.empty?
  end
  if changed
    sh("git add #{release_files.join(" ")}")
    sh("git commit -m 'chore: bump version to #{new_version}'")
    success "Committed version bump + lockfiles"
  else
    skip "Nothing to commit (version + lockfiles already current)"
  end

  # Step 4: Push to origin
  header "Git push"
  local_sha = `git rev-parse HEAD`.strip
  remote_sha = `git rev-parse origin/main 2>/dev/null`.strip
  if local_sha == remote_sha
    skip "origin/main already at #{local_sha[0..6]}"
  else
    sh("git push origin main")
    success "Pushed to origin/main"
  end

  # Step 5: Create release (the Release workflow publishes to RubyGems via OIDC)
  header "Release"
  tag_exists = system("git rev-parse #{tag} >/dev/null 2>&1")
  release_exists = system("gh release view #{tag} >/dev/null 2>&1")

  if release_exists
    skip "Release #{tag} already exists (use force to re-create)"
  elsif tag_exists
    info "Tag #{tag} exists, creating release from it"
    pre_flag = prerelease ? "--prerelease" : ""
    sh("gh release create #{tag} --generate-notes #{pre_flag}".strip)
    success "Release #{tag} created from existing tag"
  else
    pre_flag = prerelease ? "--prerelease" : ""
    sh("gh release create #{tag} --generate-notes --target main #{pre_flag}".strip)
    success "Release #{tag} created"
  end

  puts ""
  success "\e[1mRelease #{tag} complete!\e[0m CI will handle the rest:"
  puts "    • Run tests"
  puts "    • Build + verify gem"
  puts "    • Sign with Sigstore"
  puts "    • Publish to RubyGems (trusted publishing)"
  puts "    • Upload assets to the release"
end
