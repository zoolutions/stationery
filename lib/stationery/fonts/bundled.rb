# frozen_string_literal: true

module Stationery
  module Fonts
    # Families shipped inside the gem. Only file names live here; a face is
    # read the first time a document draws with it, so requiring the gem
    # never touches the files.
    module Bundled
      DIR = File.expand_path("data", __dir__)
      DEFAULT = "Inter"
      FAMILIES = {
        "Inter" => { regular: "Inter-Regular.ttf", bold: "Inter-Bold.ttf",
                     italic: "Inter-Italic.ttf", bold_italic: "Inter-BoldItalic.ttf" }
      }.freeze

      def self.names = FAMILIES.keys

      # A Family for a bundled name, or nil.
      def self.family(name)
        files = FAMILIES[name.to_s]
        files && Family.new(name, **files.transform_values { |file| File.join(DIR, file) })
      end
    end
  end
end
