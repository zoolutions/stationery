# frozen_string_literal: true

module Stationery
  module Verify
    module Engines
      # qpdf: the file's structure (`--check`, whose warnings fail it too)
      # and its page count. The password goes through a file.
      class Qpdf < Engine
        NAME = "qpdf"
        INSTALL = "brew install qpdf, or apt-get install qpdf"

        def available? = !Command.which("qpdf").nil?
        def version = run("qpdf", "--version").stdout.lines.first.to_s.strip

        def facts(paths, password: nil)
          with_password_file(password) do |options|
            paths.map { |path| read(path, options) }
          end
        end

        private

        def read(path, options)
          check = run("qpdf", *options, "--check", path)
          count = run("qpdf", *options, "--show-npages", path)
          errors = check.exitstatus == 2 || check.timed_out ? [failure("qpdf --check", check)] : []
          errors << failure("qpdf --show-npages", count) unless count.success?
          warnings = check.exitstatus == 3 ? lines(check.stderr) + lines(check.stdout).grep(/WARNING/) : []
          { "file" => path, "pages" => (1..count.stdout.to_i).map { |number| { "number" => number } },
            "errors" => errors, "warnings" => warnings.uniq }
        end

        def with_password_file(password)
          return yield([]) unless password

          Tempfile.create("stationery-verify") do |file|
            file.chmod(0o600)
            file.write(password)
            file.flush
            yield(["--password-file=#{file.path}"])
          end
        end
      end
    end
  end
end
