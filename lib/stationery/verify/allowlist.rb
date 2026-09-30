# frozen_string_literal: true

module Stationery
  module Verify
    # The engine messages that are the check's environment and not the PDF:
    # each names the engine, a pattern and why. Everything else an engine
    # says fails the check. An entry is added only once the cause is found
    # in the engine's source and the file; a file that lacks what a viewer
    # needs is a bug in the gem, not an entry here.
    module Allowlist
      ENTRIES = [
        { engine: "pdfjs", pattern: /\AWarning: _getAppearance: OffscreenCanvas is not supported/,
          why: "Node has no OffscreenCanvas. pdf.js builds a text field's appearance again when the form sets " \
               "/NeedAppearances, which Forms::AcroForm does for a form that is neither signed nor PDF/A or " \
               "PDF/UA, and warns whenever it builds one without OffscreenCanvas. Every widget carries its /AP." },
        { engine: "poppler", pattern: /\ANSS_Init failed: security library: bad database\.\z/,
          why: "pdfsig opens an NSS certificate database to judge trust, and says so when the machine has none " \
               "(~/.pki/nssdb). Whether the signature verifies does not need it." },
        { engine: "mupdf", pattern: /\Awarning: ICC support is not available\z/,
          why: "Debian's mutool (mupdf-tools, in the verify image) is built without colour management and says so " \
               "before it opens any file, even one that is not a PDF." }
      ].freeze

      def self.allows?(entries, engine, message)
        entries.any? { |entry| entry[:engine] == engine && entry[:pattern].match?(message) }
      end
    end
  end
end
