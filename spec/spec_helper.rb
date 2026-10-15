# frozen_string_literal: true

if ENV["COVERAGE"] != "false"
  require "simplecov"
  SimpleCov.start do
    skip "/spec/"
    enable_coverage :branch
  end
end

require "stationery"
require "conformance_kit/rspec"
require "stationery/rspec"

Dir[File.join(__dir__, "support/**/*.rb")].each { |file| require file }

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.order = :random
  Kernel.srand config.seed
  # The Ractor examples run in a process of their own, `bundle exec rspec
  # --tag ractor` (what conformance-kit's gate runs): once a process has
  # started a Ractor, ObjectSpace.each_object finds nothing on Ruby 4.0, and
  # the specs of what a render keeps in memory count objects with it.
  config.filter_run_excluding :ractor
end
