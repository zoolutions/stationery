# frozen_string_literal: true

module Stationery
  module Verify
    module Engines
      # PDFKit, the engine of Preview and Safari, through scripts/pdfkit.swift.
      # macOS only; Swift comes with Xcode or its command line tools.
      class Pdfkit < Engine
        NAME = "pdfkit"
        INSTALL = "macOS only: xcode-select --install"
        SCRIPT = File.expand_path("../scripts/pdfkit.swift", __dir__)

        def available? = RUBY_PLATFORM.include?("darwin") && !Command.which("swift").nil?
        def version = "macOS #{run("sw_vers", "-productVersion").stdout.strip}"

        def facts(paths, password: nil) = scripted(["swift", SCRIPT], paths, env: password_env(password))
      end
    end
  end
end
