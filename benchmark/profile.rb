# frozen_string_literal: true

# Profiles one render of the 1,500-row table document under StackProf and
# prints the 20 hottest frames:
#
#   PROFILE=1 bundle exec ruby -Ilib benchmark/profile.rb
#
# Wall mode by default: CPU mode on macOS files most samples under GC
# (compare GC.stat(:time)). MODE=cpu or MODE=object picks another mode.
#
# Without PROFILE set it only renders once.
require "stackprof"
require_relative "table_50_pages"

Bench::StationeryTable.new.to_pdf # warm the font cache so the profile shows layout and writing

if ENV["PROFILE"]
  mode = ENV.fetch("MODE", "wall").to_sym
  profile = StackProf.run(mode:, interval: mode == :object ? 1 : 100, raw: true) { Bench::StationeryTable.new.to_pdf }
  StackProf::Report.new(profile).print_text(false, 20)
else
  puts "Set PROFILE=1 to profile the table document."
end
