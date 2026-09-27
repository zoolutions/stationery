# frozen_string_literal: true

require "bundler/gem_tasks"
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
