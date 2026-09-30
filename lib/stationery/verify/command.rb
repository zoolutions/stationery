# frozen_string_literal: true

require "tempfile"
require "tmpdir"

module Stationery
  module Verify
    # Runs an engine's tool: an argument array, never through a shell, its
    # output written to files as it runs (so a large one cannot block it),
    # in `chdir` (the temporary directory unless asked: a tool that loads
    # modules from where it runs must not load a checked file's neighbours),
    # and its process group killed when it takes longer than `timeout`
    # seconds (swift runs the compiled script as a child of its own).
    module Command
      POLL = 0.01 # seconds between looks at a running child

      Result = Data.define(:stdout, :stderr, :status, :timed_out) do
        def success? = !timed_out && status&.success? == true
        def exitstatus = status&.exitstatus
      end

      def self.run(*argv, env: {}, timeout: 60, chdir: Dir.tmpdir)
        Tempfile.create("stationery-verify-out") do |out|
          Tempfile.create("stationery-verify-err") do |err|
            status, timed_out = spawn(argv, env:, timeout:, chdir:, out:, err:)
            Result.new(stdout: read(out), stderr: read(err), status:, timed_out:)
          rescue SystemCallError => e # the program could not start: that tool's failure, not the run's
            Result.new(stdout: "", stderr: "#{e.message}\n", status: nil, timed_out: false)
          end
        end
      end

      def self.spawn(argv, env:, timeout:, chdir:, out:, err:)
        # [program, argv0] never goes through a shell, whatever argv holds.
        pid = Process.spawn(env, [argv.first, argv.first], *argv.drop(1), in: File::NULL, out:, err:, chdir:,
                                                                          pgroup: true)
        waited = wait(pid, timeout)
      ensure
        kill(pid) if pid && !waited
      end

      # What a tool wrote, as UTF-8 with anything that is not replaced.
      def self.read(file) = File.read(file.path, encoding: Encoding::UTF_8).scrub

      # The executable `name` on the PATH (or at `name`, a path from the
      # working directory, answered absolute), or nil.
      def self.which(name)
        if name.include?(File::SEPARATOR)
          path = File.expand_path(name)
          return (path if File.file?(path) && File.executable?(path))
        end

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
        [kill(pid), true]
      end

      # Kills the child's process group and answers the child's status.
      def self.kill(pid)
        Process.kill(:KILL, -pid)
        Process.waitpid2(pid).last
      rescue Errno::ESRCH, Errno::ECHILD
        nil # it was gone already
      end
    end
  end
end
