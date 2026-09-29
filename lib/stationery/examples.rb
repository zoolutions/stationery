# frozen_string_literal: true

module Stationery
  # The examples that ship with the gem, under examples/: their names, where
  # each is and what each shows. `stationery examples` lists them and the
  # skill (see Skill) names them.
  module Examples
    DIR = File.expand_path("../../examples", __dir__)

    module_function

    def names = Dir.glob("**/*.rb", base: DIR).map { |file| file.delete_suffix(".rb") }.sort
    def path(name) = File.join(DIR, "#{name}.rb")

    # The first sentence of the comment that opens the file.
    def summary(name)
      comment = File.foreach(path(name), chomp: true).drop(2).take_while { |line| line.match?(/\A# *\S/) }
      text = comment.map { |line| line.delete_prefix("#").strip }.join(" ").sub(/\s*Run it.*\z/, "")
      (text[/\A.*?\.(?=\s|\z)/] || text).delete_suffix(":")
    end
  end
end
