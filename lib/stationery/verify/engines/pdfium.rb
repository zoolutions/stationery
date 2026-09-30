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

        def available? = !Command.which(python).nil? && run(python, "-c", "import pypdfium2").success?

        def version
          versions = run(python, "-c",
                         "import pypdfium2.version as v; print(v.PYPDFIUM_INFO, v.PDFIUM_INFO)").stdout.split
          "pypdfium2 #{versions[0]}, PDFium #{versions[1]}"
        end

        def facts(paths, password: nil) = scripted([python, SCRIPT], paths, env: password_env(password))

        private

        def python = ENV.fetch("STATIONERY_PYTHON", "python3")
      end
    end
  end
end
