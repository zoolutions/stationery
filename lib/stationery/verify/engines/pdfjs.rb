# frozen_string_literal: true

module Stationery
  module Verify
    module Engines
      # pdf.js, the engine of Firefox, through Node, pdfjs-dist and
      # scripts/pdfjs.mjs. STATIONERY_PDFJS names pdfjs-dist's directory;
      # without it, the one Node resolves from the working directory, whose
      # code then runs: set STATIONERY_PDFJS where that directory is not yours.
      class Pdfjs < Engine
        NAME = "pdfjs"
        INSTALL = "npm i pdfjs-dist (STATIONERY_PDFJS names its directory)"
        SCRIPT = File.expand_path("../scripts/pdfjs.mjs", __dir__)
        RESOLVE = "console.log(require('path').dirname(require.resolve('pdfjs-dist/package.json')))"

        def available? = !directory.nil?
        def version = "pdfjs-dist #{JSON.parse(File.read(File.join(directory, "package.json")))["version"]}"

        def facts(paths, password: nil)
          scripted(["node", SCRIPT], paths, env: { "STATIONERY_PDFJS" => directory, **password_env(password) })
        end

        private

        def directory
          return @directory if defined?(@directory)

          found = ENV.fetch("STATIONERY_PDFJS") { resolved }
          @directory = found if found && File.file?(File.join(found, "legacy/build/pdf.mjs"))
        end

        def resolved
          return unless Command.which("node")

          result = run("node", "-e", RESOLVE, chdir: Dir.pwd)
          result.stdout.strip if result.success?
        end
      end
    end
  end
end
