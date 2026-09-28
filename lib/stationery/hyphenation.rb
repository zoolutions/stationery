# frozen_string_literal: true

module Stationery
  # Liang's hyphenation over the TeX `hyph-utf8` patterns bundled under
  # hyphenation/patterns/ (see LICENSES.md there). A language loads on first
  # use and stays cached per process.
  #
  #   Stationery::Hyphenation.hyphenate("Silbentrennung", "de") # => ["Sil", "ben", "tren", "nung"]
  #   Stationery::Hyphenation.points("hyphenation", "en")       # => [2, 6]
  module Hyphenation
    PATTERNS = File.expand_path("hyphenation/patterns", __dir__)

    # Language tags accepted by `hyphenate:`, mapped to a bundled pattern set.
    LANGUAGES = {
      "en" => "en-us", "en-us" => "en-us", "en_us" => "en-us",
      "de" => "de-1996", "de-1996" => "de-1996", "de-de" => "de-1996",
      "sv" => "sv", "sv-se" => "sv"
    }.freeze

    # Letters kept intact at either end of a word (the pattern sets' own
    # typesetting minimums).
    MINIMUMS = { "en-us" => [2, 3], "de-1996" => [2, 2], "sv" => [2, 2] }.freeze

    LOCK = Mutex.new

    # One pattern set: the patterns keyed by their letters, the longest
    # pattern's length and the exception list.
    class Patterns
      attr_reader :left_min, :right_min

      def initialize(tag)
        @left_min, @right_min = MINIMUMS.fetch(tag)
        @patterns = {}
        @longest = 0
        @exceptions = {}
        load_patterns(File.join(PATTERNS, "#{tag}.pat.txt"))
        exceptions = File.join(PATTERNS, "#{tag}.hyp.txt")
        load_exceptions(exceptions) if File.exist?(exceptions)
      end

      # Indexes where `word` may break (a break before word[index]),
      # honouring the minimums.
      def points(word)
        key = word.downcase
        return @exceptions[key] if @exceptions.key?(key)

        levels = levels_for(".#{key}.")
        (left_min..(word.length - right_min)).select { |index| levels[index].odd? }
      end

      private

      def load_patterns(path)
        File.foreach(path, chomp: true) do |line|
          next if line.empty? || line.start_with?("%")

          letters = line.delete("0-9")
          values = Array.new(letters.length + 1, 0)
          position = 0
          line.each_char do |char|
            if char.match?(/\d/) then values[position] = char.to_i
            else position += 1
            end
          end
          @patterns[letters] = values
          @longest = letters.length if letters.length > @longest
        end
      end

      # "as-so-ciate" → { "associate" => [2, 4] }
      def load_exceptions(path)
        File.foreach(path, chomp: true) do |line|
          next if line.empty? || line.start_with?("%")

          pieces = line.downcase.split("-")
          positions = pieces[0..-2].each_with_object([]) { |piece, list| list << (list.last.to_i + piece.length) }
          @exceptions[pieces.join] = positions
        end
      end

      # Liang: the highest digit any matching pattern puts between two
      # letters of the dotted word; odd means a break may go there. Index i
      # in the result is the gap before letter i of the undotted word.
      def levels_for(dotted)
        levels = Array.new(dotted.length + 1, 0)
        dotted.length.times do |start|
          1.upto([@longest, dotted.length - start].min) do |length|
            values = @patterns[dotted[start, length]] or next
            values.each_with_index do |value, offset|
              levels[start + offset] = value if value > levels[start + offset]
            end
          end
        end
        levels.drop(1)
      end
    end

    module_function

    # The bundled pattern set for a `hyphenate:` value: true is English,
    # a tag is looked up case-insensitively; nil for false or nil.
    def tag(value)
      return nil if value.nil? || value == false
      return "en-us" if value == true

      LANGUAGES.fetch(value.to_s.downcase) do
        raise ArgumentError, "unknown hyphenation language #{value.inspect} (bundled: #{LANGUAGES.keys.join(", ")})"
      end
    end

    def patterns(language)
      tag = tag(language)
      @sets ||= {} # rubocop:disable ThreadSafety/ClassInstanceVariable
      LOCK.synchronize { @sets[tag] ||= Patterns.new(tag) }
    end

    # Indexes where `word` may be broken (before word[index]); an empty
    # array for a word too short to break or holding anything but letters.
    def points(word, language)
      return [] unless word.match?(/\A\p{L}+\z/)

      patterns(language).points(word)
    end

    # The word cut at its break points.
    def hyphenate(word, language)
      last = 0
      pieces = points(word, language).map { |index| word[last...index].tap { last = index } }
      pieces << word[last..]
    end
  end
end
