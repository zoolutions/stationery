# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
namespace :spec do
  desc "Run the Rails integration specs (BUNDLE_GEMFILE=gemfiles/rails.gemfile)"
  RSpec::Core::RakeTask.new(:rails) do |task|
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
