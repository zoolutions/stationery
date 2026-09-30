# frozen_string_literal: true

require "tempfile"

module Stationery
  module Verify
    # Runs an engine's tool: an argument array, never through a shell, its
    # output written to files as it runs (so a large one cannot block it),
    # and the child killed when it takes longer than `timeout` seconds.
    module Command
      POLL = 0.01 # seconds between looks at a running child

      Result = Data.define(:stdout, :stderr, :status, :timed_out) do
        def success? = !timed_out && status&.success?
        def exitstatus = status&.exitstatus
      end

      def self.run(*argv, env: {}, timeout: 60)
        Tempfile.create("stationery-verify-out") do |out|
          Tempfile.create("stationery-verify-err") do |err|
            # [program, argv0] never goes through a shell, whatever argv holds.
            pid = Process.spawn(env, [argv.first, argv.first], *argv.drop(1), in: File::NULL, out:, err:)
            status, timed_out = wait(pid, timeout)
            Result.new(stdout: File.read(out.path, encoding: Encoding::UTF_8),
                       stderr: File.read(err.path, encoding: Encoding::UTF_8), status:, timed_out:)
          end
        end
      end

      # The executable `name` on the PATH (or at `name`, a path), or nil.
      def self.which(name)
        return (name if File.file?(name) && File.executable?(name)) if name.include?(File::SEPARATOR)

        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |dir| File.join(dir, name) }
           .find { |path| File.file?(path) && File.executable?(path) }
      end

      def self.wait(pid, timeout)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        loop do
          _, status = Process.waitpid2(pid, Process::WNOHANG)
          return [status, false] if status

          break if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

          sleep POLL
        end
        Process.kill(:KILL, pid)
        [Process.waitpid2(pid).last, true]
      end
    end
  end
end
