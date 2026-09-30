# frozen_string_literal: true

module Stationery
  module Verify
    module Engines
      # MuPDF (`mutool draw`): each page drawn in grey and as text. What it
      # writes on stderr fails the check. mutool takes a password on its
      # command line only, where other local processes can read it.
      class Mupdf < Engine
        NAME = "mupdf"
        INSTALL = "brew install mupdf, or apt-get install mupdf-tools"

        def available? = !Command.which("mutool").nil?
        def version = "mutool #{run("mutool", "-v").stderr[/\d+(\.\d+)+/]}"

        def facts(paths, password: nil)
          paths.map { |path| Dir.mktmpdir("stationery-verify") { |dir| read(path, password, dir) } }
        end

        private

        def read(path, password, dir)
          options = password ? ["-p", password] : []
          draws = %w[pgm txt].map do |format|
            run("mutool", "draw", "-q", *options, "-r", "36", "-F", format, "-o", File.join(dir, "p%d.#{format}"), path)
          end
          errors = draws.reject(&:success?).map { |draw| failure("mutool draw", draw) }
          { "file" => path, "pages" => pages(dir), "errors" => errors,
            "warnings" => draws.flat_map { |draw| lines(draw.stderr) }.uniq }
        end

        # The pages MuPDF drew, in order, each with its picture and its text.
        def pages(dir)
          pictures = Dir[File.join(dir, "p*.pgm")].sort_by { |file| file[/(\d+)\.pgm\z/, 1].to_i }
          pictures.map.with_index(1) do |picture, number|
            text = File.join(dir, "p#{number}.txt")
            { "number" => number, "painted" => painted?(File.binread(picture)),
              "text" => File.exist?(text) ? File.read(text, encoding: Encoding::UTF_8) : nil }
          end
        end
      end
    end
  end
end
