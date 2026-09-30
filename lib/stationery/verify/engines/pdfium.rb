# frozen_string_literal: true

module Stationery
  module Verify
    module Engines
      # PDFium, the engine of Chrome and Edge, through pypdfium2 and
      # scripts/pdfium.py. STATIONERY_PYTHON names the Python that has it.
      class Pdfium < Engine
        NAME = "pdfium"
        INSTALL = "pip install pypdfium2 (STATIONERY_PYTHON names the Python that has it)"
        SCRIPT = File.expand_path("../scripts/pdfium.py", __dir__)
        VERSION = "import pypdfium2.version as v; print(v.PYPDFIUM_INFO, v.PDFIUM_INFO)"

        # -I everywhere: isolated, so Python loads no module from beside the
        # script or from the working directory.
        def available? = !Command.which(python).nil? && run(python, "-I", "-c", "import pypdfium2").success?

        def version
          versions = run(python, "-I", "-c", VERSION).stdout.split
          "pypdfium2 #{versions[0]}, PDFium #{versions[1]}"
        end

        def facts(paths, password: nil) = scripted([python, "-I", SCRIPT], paths, env: password_env(password))

        private

        def python = ENV.fetch("STATIONERY_PYTHON", "python3")
      end
    end
  end
end
