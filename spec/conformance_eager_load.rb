# frozen_string_literal: true

# conformance-kit's audit.require (.conformance.yml): loads all of
# lib/stationery, as an app that used every part of the gem would, then ends
# its boot as an app does (Stationery.finalize!), so `conformance-audit
# --strict` sees every constant and class instance variable the gem keeps.
require "rspec/core" # stationery/rspec adds to RSpec's matchers
require "rspec/expectations"

# The entry points first, as an app requires them: each loads its own parts
# in the order they need (the CLI's commands register with Stationery::CLI).
%w[stationery stationery/cli stationery/verify stationery/preview stationery/skill stationery/rspec
   stationery/minitest stationery/rails].each { |feature| require feature }

lib = File.expand_path("../lib", __dir__)
# Both need Rails, which this bundle has not; the Rails lane
# (gemfiles/rails.gemfile) loads them. So does lib/generators, outside
# lib/stationery.
rails_only = %w[stationery/railtie.rb stationery/rails/previews_controller.rb]
Dir[File.join(lib, "stationery/**/*.rb")].each do |file|
  require file unless rails_only.include?(file.delete_prefix("#{lib}/"))
end

Stationery.finalize!
