# frozen_string_literal: true

require "fileutils"
require_relative "../skill"

module Stationery
  class CLI
    # `stationery skill install`, `status` and `print`: writes the skill that
    # ships with the gem (see Stationery::Skill) where a coding agent finds
    # it, says whether the one there is current, or prints it.
    #
    # A target is an agent's skills directory: `~/.claude/skills` (Claude
    # Code), `~/.codex/skills` (Codex) and `~/.agents/skills` (OpenCode and
    # the other agents that read the shared directory), or the same under
    # the project with `--project`, or any directory with `--dir`.
    class Skill
      SUMMARY = "Install the skill for coding agents (Claude Code, Codex, …), print it, or check it is current"
      TARGETS = { "claude" => ".claude", "codex" => ".codex", "agents" => ".agents" }.freeze

      def initialize(out:, err:, home: Dir.home, cwd: Dir.pwd)
        @out = out
        @err = err
        @home = home
        @cwd = cwd
        @options = { targets: [] }
      end

      def run(argv)
        parser.parse!(argv)
        return OK if @options[:help]

        case argv.shift
        when "install" then install
        when "status" then status
        when "print" then print_skill
        else usage
        end
      rescue OptionParser::ParseError => e
        @err.puts "stationery skill: #{e.message}", parser
        USAGE
      end

      private

      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Usage: stationery skill install [--target NAME] [--project | --dir DIR] [--force]\n       " \
                        "stationery skill status [--target NAME] [--project | --dir DIR]\n       " \
                        "stationery skill print"
          opts.on("--target NAME", "claude, codex, agents or all (default: the agents found, else claude)") do |name|
            @options[:targets] |= target(name)
          end
          opts.on("--project", "The project's skills (./.claude/skills, …) instead of the user's") do
            @options[:project] = true
          end
          opts.on("--dir DIR", "Install into this skills directory instead") { |dir| @options[:dir] = dir }
          opts.on("--force", "Replace a skill named stationery that the gem did not write") { @options[:force] = true }
          opts.on("-h", "--help", "Show this help") do
            @out.puts opts
            @options[:help] = true
          end
        end
      end

      def usage
        @err.puts parser
        USAGE
      end

      def target(name)
        return TARGETS.keys if name == "all"
        return [name] if TARGETS.key?(name)

        raise OptionParser::InvalidArgument, "--target is claude, codex, agents or all, not #{name.inspect}"
      end

      def install = locations(found: true).map { |name, dir| write(name, dir) }.max

      def write(name, dir)
        previous = installed(dir)
        if previous == :foreign && !@options[:force]
          @err.puts "stationery skill: #{File.join(dir, "SKILL.md")} was not written by stationery; " \
                    "pass --force to replace it"
          return FAILURE
        end

        FileUtils.rm_rf(%w[reference recipes].map { |sub| File.join(dir, sub) })
        files.each do |path, text|
          FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
          File.write(File.join(dir, path), text)
        end
        was = " (was #{previous})" if previous.is_a?(String) && previous != VERSION
        @out.puts "#{name.ljust(6)}  #{File.join(dir, "SKILL.md")}  installed for stationery #{VERSION}#{was}"
        OK
      end

      def status
        locations(found: false).each do |name, dir|
          @out.puts "#{name.ljust(6)}  #{File.join(dir, "SKILL.md")}  #{state(name, installed(dir))}"
        end
        OK
      end

      def state(name, version)
        case version
        when nil then "missing: `#{install_command(name)}` writes it"
        when :foreign then "not written by stationery"
        when VERSION then "current (#{VERSION})"
        else
          return "written for #{version}, newer than the gem (#{VERSION})" if newer?(version)

          "outdated (#{version}; the gem is #{VERSION}): run `#{install_command(name)}`"
        end
      end

      def newer?(version) = Gem::Version.new(version) > Gem::Version.new(VERSION)

      def install_command(name)
        ["stationery skill install", ("--target #{name}" if TARGETS.key?(name)),
         ("--project" if @options[:project])].compact.join(" ")
      end

      # The version of the skill in `dir`, :foreign for a SKILL.md the gem did
      # not write, nil for none.
      def installed(dir)
        path = File.join(dir, "SKILL.md")
        return unless File.file?(path)

        Stationery::Skill.version_of(File.read(path, encoding: "UTF-8")) || :foreign
      end

      def print_skill
        files.each_with_index do |(path, text), index|
          @out.puts "", "<!-- #{path} -->", "" unless index.zero?
          @out.write text
        end
        OK
      end

      # [name, skill directory] for each target: the named ones, else (when
      # installing) the agents whose directory is there, else Claude Code.
      def locations(found:)
        return [["dir", File.join(File.expand_path(@options[:dir], @cwd), Stationery::Skill::NAME)]] if @options[:dir]

        base = @options[:project] ? @cwd : @home
        names = @options[:targets]
        names = TARGETS.keys.select { |name| File.directory?(File.join(base, TARGETS[name])) } if names.empty? && found
        names = found ? ["claude"] : TARGETS.keys if names.empty?
        names.map { |name| [name, File.join(base, TARGETS[name], "skills", Stationery::Skill::NAME)] }
      end

      def files = @files ||= Stationery::Skill.new.files
    end

    register "skill", Skill
  end
end
