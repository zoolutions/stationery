# frozen_string_literal: true

require "optparse"
require "stationery"

module Stationery
  # The `stationery` executable. Commands register themselves by name:
  #
  #   Stationery::CLI.register("render", Stationery::CLI::Render)
  #
  # A command is a class built with `new(out:, err:)` whose `#run(argv)`
  # returns an exit code and that has a one-line `SUMMARY`.
  class CLI
    OK = 0
    FAILURE = 1
    USAGE = 2

    # Raised by a command to fail with a message and exit code 1.
    class Error < StandardError; end

    class << self
      def commands = @commands ||= {}

      def register(name, command)
        commands[name.to_s] = command
      end

      def start(argv, out: $stdout, err: $stderr) = new(out:, err:).run(argv.dup)
    end

    def initialize(out:, err:)
      @out = out
      @err = err
    end

    def run(argv)
      case (name = argv.shift)
      when nil then usage(@err, USAGE)
      when "help", "--help", "-h" then usage(@out, OK)
      when "--version", "-v" then version
      else dispatch(name, argv)
      end
    end

    private

    def dispatch(name, argv)
      command = self.class.commands.fetch(name) do
        @err.puts "stationery: unknown command #{name.inspect}"
        return usage(@err, USAGE)
      end
      command.new(out: @out, err: @err).run(argv)
    rescue Error => e
      @err.puts "stationery: #{e.message}"
      FAILURE
    end

    def version
      @out.puts VERSION
      OK
    end

    def usage(io, code)
      io.puts "Usage: stationery COMMAND [options]", "", "Commands:"
      width = self.class.commands.keys.map(&:size).max.to_i
      self.class.commands.each { |name, command| io.puts "  #{name.ljust(width)}  #{command::SUMMARY}" }
      io.puts "", "Run `stationery COMMAND --help` for a command's options; `stationery --version` for the version."
      code
    end
  end
end

require_relative "cli/pictures"
require_relative "cli/render"
require_relative "cli/fonts"
require_relative "cli/examples"
require_relative "cli/layout_text"
require_relative "cli/inspect"
require_relative "cli/skill"
require_relative "cli/verify"
