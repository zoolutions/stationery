# frozen_string_literal: true

require "json"
require "tempfile"
require "tmpdir"

module Stationery
  module Verify
    # What every engine adapter answers: its `name`, the line that
    # installs it, whether it is `available?`, its `version`, and
    # `facts(paths, password:)`, one Hash of facts per path (see Verify).
    class Engine
      TIMEOUT = 60 # seconds for each file

      def name = self.class::NAME
      def install = self.class::INSTALL

      private

      def run(*argv, env: {}, timeout: TIMEOUT, **) = Command.run(*argv, env:, timeout:, **)

      def failed(path, message) = { "file" => path, "pages" => [], "errors" => [message], "warnings" => [] }

      # Why a tool failed, from its result: timed out, or its exit status
      # and the last lines it wrote to stderr.
      def failure(tool, result)
        return "#{tool} timed out after #{TIMEOUT} s" if result.timed_out

        ["#{tool} exited #{result.exitstatus}", *result.stderr.lines.last(3).map(&:strip)].join(": ")
      end

      def lines(text) = text.to_s.lines.map(&:strip).reject(&:empty?)

      # Whether a binary PGM (P5, 8-bit) has a pixel that is not white.
      def painted?(pgm)
        header = pgm.match(/\AP5\s+(\d+)\s+(\d+)\s+(\d+)\s/n) or return false
        width = header[1].to_i
        height = header[2].to_i
        pixels = pgm.byteslice(header[0].bytesize, width * height).to_s
        pixels.count("\xFF".b) != pixels.bytesize
      end

      # Runs a script that prints one JSON line of facts per path; a path
      # the script did not answer for fails with why the script stopped.
      def scripted(argv, paths, env:)
        result = run(*argv, *paths, env:, timeout: (TIMEOUT * paths.size) + TIMEOUT)
        answers = lines(result.stdout).select { |line| line.start_with?("{") }.filter_map { |line| parse(line) }
        read = answers.to_h { |facts| [facts["file"], facts] }
        paths.map { |path| read.fetch(path) { failed(path, failure(argv.first, result)) } }
      end

      # A line that is not JSON answers for no file, which then fails.
      def parse(line)
        JSON.parse(line)
      rescue JSON::ParserError
        nil
      end

      def password_env(password) = password ? { "STATIONERY_VERIFY_PASSWORD" => password } : {}
    end
  end
end
