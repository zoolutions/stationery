# frozen_string_literal: true

module Stationery
  module Verify
    module Engines
      # Poppler, the engine of the Linux desktop viewers (Evince, Okular):
      # pdfinfo for the pages and the structure tree, pdftotext, pdftoppm
      # in grey, pdffonts, pdfdetach and pdfsig. What any of them writes on
      # stderr fails the check. The tools take a password on their command
      # line only, where other local processes can read it; pdfsig takes
      # none, so a file opened with one reports no signatures.
      class Poppler < Engine
        NAME = "poppler"
        INSTALL = "brew install poppler, or apt-get install poppler-utils"
        TOOLS = %w[pdfinfo pdftotext pdftoppm pdffonts pdfdetach pdfsig].freeze
        UNSIGNED = "does not contain any signatures"
        NOT_SIGNED = "The signature form field is not signed."

        def available? = TOOLS.all? { |tool| Command.which(tool) }
        def version = "poppler #{run("pdfinfo", "-v").stderr[/\d+(\.\d+)+/]}"

        def facts(paths, password: nil)
          paths.map { |path| Dir.mktmpdir("stationery-verify") { |dir| read(path, password, dir) } }
        end

        private

        def read(path, password, dir)
          @results = []
          options = password ? ["-upw", password] : []
          count = tool("pdfinfo", *options, path).stdout[/^Pages:\s+(\d+)/, 1].to_i
          { "file" => path, "pages" => pages(path, options, dir, count), "fonts" => fonts(path, options),
            "attachments" => attachments(path, options), "signatures" => (signatures(path) unless password),
            "structure" => !tool("pdfinfo", "-struct", *options, path).stdout.strip.empty?,
            "errors" => @results.reject { |(_, result)| result.success? || unsigned?(result) }
                                .map { |(name, result)| failure(name, result) },
            "warnings" => @results.flat_map { |(_, result)| lines(result.stderr) }.uniq }
        end

        def tool(name, *)
          run(name, *).tap { |result| @results << [name, result] }
        end

        def pages(path, options, dir, count)
          texts = tool("pdftotext", "-enc", "UTF-8", *options, path, "-").stdout.split("\f")
          tool("pdftoppm", "-gray", "-r", "36", *options, path, File.join(dir, "p"))
          pictures = Dir[File.join(dir, "p-*.pgm")].sort_by { |file| file[/-(\d+)\.pgm\z/, 1].to_i }
          (1..count).map do |number|
            picture = pictures[number - 1]
            { "number" => number, "text" => texts[number - 1].to_s,
              "painted" => picture && painted?(File.binread(picture)) }
          end
        end

        def fonts(path, options)
          tool("pdffonts", *options, path).stdout.lines.drop(2).map do |line|
            columns = line.split
            { "name" => columns.first, "embedded" => columns[-5] == "yes", "unicode" => columns[-3] == "yes" }
          end
        end

        def attachments(path, options)
          tool("pdfdetach", "-list", *options, path).stdout.lines.filter_map { |line| line[/\A\d+: (.*)$/, 1] }
        end

        # pdfsig answers "valid" for a signature over the whole file whose
        # CMS verifies; -nocert leaves the certificate's trust out of it.
        def signatures(path)
          result = tool("pdfsig", "-nocert", path)
          return { "count" => 0, "valid" => nil } if unsigned?(result)

          blocks = result.stdout.split(/^Signature #\d+:$/).drop(1).reject { |block| block.include?(NOT_SIGNED) }
          { "count" => blocks.size,
            "valid" => blocks.all? do |block|
              block.include?("Signature is Valid") && block.include?("Total document signed")
            end }
        end

        def unsigned?(result) = result.exitstatus == 2 && result.stdout.include?(UNSIGNED)
      end
    end
  end
end
