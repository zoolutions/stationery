# frozen_string_literal: true

module Stationery
  module Verify
    # What Verify.run found: a Result for each file and engine that ran, and
    # the engines that are not installed. It passes when every engine that
    # ran finds nothing wrong with any file, and at least one ran.
    Report = Data.define(:results, :missing) do
      self::Result = Data.define(:file, :engine, :version, :problems) do
        def passed? = problems.empty?
      end

      def passed? = results.any? && results.all?(&:passed?)

      # One line per file and engine, its problems under it, then the
      # engines not run with the line that installs each.
      def lines
        width = results.map { |result| result.engine.size }.max.to_i
        found = results.group_by(&:file).flat_map do |file, ran|
          [file, *ran.flat_map { |result| result_lines(result, width) }]
        end
        found + (if missing.empty?
                   []
                 else
                   ["not run: #{missing.map do |engine|
                     "#{engine.name} (#{engine.install})"
                   end.join(", ")}"]
                 end)
      end

      def to_h
        { passed: passed?, results: results.map(&:to_h),
          missing: missing.map { |engine| { engine: engine.name, install: engine.install } } }
      end

      private

      def result_lines(result, width)
        verdict = result.passed? ? "ok" : "FAILED"
        ["  #{result.engine.ljust(width)}  #{verdict}  (#{result.version})", *result.problems.map do |problem|
          "      #{problem}"
        end]
      end
    end
  end
end
