# frozen_string_literal: true

# Profiles one render of the 1,500-row table document under StackProf (CPU
# mode) and prints the 20 hottest frames:
#
#   PROFILE=1 bundle exec ruby -Ilib benchmark/profile.rb
#
# Without PROFILE set it only renders once.
require "stackprof"
require_relative "table_50_pages"

Bench::StationeryTable.new.to_pdf # warm the font cache so the profile shows layout and writing

if ENV["PROFILE"]
  profile = StackProf.run(mode: :cpu, interval: 100, raw: true) { Bench::StationeryTable.new.to_pdf }
  StackProf::Report.new(profile).print_text(false, 20)
else
  puts "Set PROFILE=1 to profile the table document."
end
