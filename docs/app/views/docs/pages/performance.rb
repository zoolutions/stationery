# frozen_string_literal: true

class Views::Docs::Pages::Performance < DocsUI::Page
  title "Performance"
  eyebrow "Reference"

  def lead = "Benchmarks against Prawn and sghtmltopdf, the metrics gate CI holds, a StackProf profile, and the events a render emits."

  def content
    DocsUI::Section("Benchmarks", description: "From the README — rake bench.") do
      md SourceMarkdown.readme_section("Performance")
    end

    DocsUI::Section("Running them", description: "Time locally, allocations and bytes in CI.") do
      md <<~'MD'
        ```shell
        bundle exec rake bench                                    # Stationery vs Prawn vs sghtmltopdf, renders/s
        bundle exec rake metrics                                  # allocations, pages and bytes against the baseline
        PROFILE=1 bundle exec ruby -Ilib benchmark/profile.rb     # 20 hottest frames under StackProf
        ```

        The documents live in `benchmark/`; every engine embeds the same Open Sans TTF files, and
        sghtmltopdf renders HTML/CSS twins of them at `dpi: 72` so a CSS pixel is a point. `rake bench`
        needs the Gemfile's `:benchmark` group (Prawn, prawn-table, benchmark-ips, StackProf and the
        precompiled sghtmltopdf gem); without sghtmltopdf it prints two engines and says so, and
        `SGHTMLTOPDF=0` does the same on purpose. None of them is a dependency of the gem.

        Time depends on the machine, so `rake bench` is not part of CI. `rake metrics` is: it renders
        six fixed documents and fails when the objects a render allocates grow more than 3%, its bytes
        more than 1%, or its page count changes, against `benchmark/baseline.json`. A change that moves
        them on purpose records a new baseline with `rake metrics:update`. The feature-by-feature
        picture is on the [Comparison](/docs/comparison) page.
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
