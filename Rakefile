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

task default: %i[spec rubocop]

desc "Benchmark against Prawn (bundle exec rake bench)"
task :bench do
  ruby "-Ilib benchmark/invoice.rb"
  ruby "-Ilib benchmark/table_50_pages.rb"
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
