# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake", "~> 13.0"

group :development do
  gem "rubocop", "~> 1.80", require: false
  gem "rubocop-performance", "~> 1.26", require: false
  gem "rubocop-rake", "~> 0.7", require: false
  gem "rubocop-rspec", "~> 3.0", require: false
  gem "rubocop-thread_safety", "~> 0.7", require: false
end

group :test do
  gem "pdf-inspector", "~> 1.3", require: false
  gem "pdf-reader", "~> 2.12", require: false
  gem "rspec", "~> 3.13"
  gem "simplecov", require: false
end

group :benchmark do
  gem "benchmark-ips", require: false
  gem "prawn", require: false
  gem "prawn-table", require: false
  gem "stackprof", require: false
end
