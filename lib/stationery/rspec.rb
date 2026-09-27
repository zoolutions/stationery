# frozen_string_literal: true

require "stationery"
require_relative "testing/matchers"

RSpec.configure { |config| config.include Stationery::Testing::Matchers }
