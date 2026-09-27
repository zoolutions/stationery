# frozen_string_literal: true

require "stationery"
require_relative "testing/matchers"

# Composable adds `and`/`or` and lets a matcher sit inside `include`, `match`
# and `all`; Base stays framework-free for Minitest, so it is mixed in here.
Stationery::Testing::Matchers::Base.include(RSpec::Matchers::Composable)

RSpec.configure { |config| config.include Stationery::Testing::Matchers }
