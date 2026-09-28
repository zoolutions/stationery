# frozen_string_literal: true

class Views::Docs::Pages::Performance < DocsUI::Page
  title "Performance"
  eyebrow "Reference"

  def lead = "Reproducible benchmarks against Prawn + prawn-table, a StackProf profile of the hottest frames, and the events a render emits."

  def content
    DocsUI::Section("Benchmarks", description: "From the README — rake bench.") do
      md SourceMarkdown.readme_section("Performance")
    end

    DocsUI::Section("Running them", description: "Not part of CI.") do
      md <<~'MD'
        ```shell
        bundle exec rake bench                                    # Stationery vs Prawn 2.5 + prawn-table
        PROFILE=1 bundle exec ruby -Ilib benchmark/profile.rb     # 20 hottest frames under StackProf
        ```

        The benchmark documents live in `benchmark/` and embed the same Open Sans TTF files on both sides.
        Prawn and StackProf are development dependencies of the gem only; applications never load them.
      MD
    end

    DocsUI::Section("Large documents", description: "What streaming does and does not save.") do
      md <<~'MD'
        `to_pdf { |chunk| … }` hands the file out in pieces as it is written: first bytes sooner, no
        output buffer. It does not lower peak memory, which layout sets before the first byte is
        written: a 938-page text document peaks at 187 MB as a String and 185 MB streamed, for a
        1.1 MB file. The metrics gate renders the ten-page text document both ways (`text` and
        `text_streamed`).
      MD
    end

    DocsUI::Section("Instrumentation", description: "From the README — events for AppSignal and friends.") do
      md SourceMarkdown.readme_section("Instrumentation")
    end

    DocsUI::Section("Why the trade-off", description: "Why not Prawn, Chrome or Typst?") do
      md SourceMarkdown.readme_section("Why not Prawn, Chrome or Typst?")
    end
  end
end
