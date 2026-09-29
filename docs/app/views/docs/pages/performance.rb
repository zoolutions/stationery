# frozen_string_literal: true

class Views::Docs::Pages::Performance < DocsUI::Page
  title "Performance"
  eyebrow "Reference"

  def lead = "Benchmarks against Prawn and sghtmltopdf, the metrics gate CI holds, what a long document holds in memory, a StackProf profile, and the events a render emits."

  def content
    DocsUI::Section("Benchmarks", description: "From the README — rake bench.") do
      md SourceMarkdown.readme_section("Performance")
    end

    DocsUI::Section("Running them", description: "Time locally, allocations and bytes in CI.") do
      md <<~'MD'
        ```shell
        bundle exec rake bench                                    # Stationery vs Prawn vs sghtmltopdf, renders/s
        bundle exec rake metrics                                  # allocations, pages and bytes against the baseline
        PAGES=1000 bundle exec rake memory                        # peak memory of long documents, and what stays alive
        PROFILE=1 bundle exec ruby -Ilib benchmark/profile.rb     # 20 hottest frames under StackProf
        ```

        The documents live in `benchmark/`; every engine embeds the same Open Sans TTF files, and
        sghtmltopdf renders HTML/CSS twins of them at `dpi: 72` so a CSS pixel is a point. `rake bench`
        needs the Gemfile's `:benchmark` group (Prawn, prawn-table, benchmark-ips, StackProf and the
        precompiled sghtmltopdf gem); without sghtmltopdf it prints two engines and says so, and
        `SGHTMLTOPDF=0` does the same on purpose. None of them is a dependency of the gem.

        Time depends on the machine, so `rake bench` is not part of CI. `rake metrics` is: it renders
        fourteen fixed documents (the table above) and fails when the objects a render allocates grow more than 3%, its bytes
        more than 1%, or its page count changes, against `benchmark/baseline.json`. A change that moves
        them on purpose records a new baseline with `rake metrics:update`. The feature-by-feature
        picture is on the [Comparison](/docs/comparison) page.
      MD
    end

    DocsUI::Section("Large documents", description: "What a render holds, and what incremental saves.") do
      md <<~'MD'
        A render holds what it still has to paint: the nodes of a page are let go once it is painted, a
        table measures its rows as pages reach them, the fonts forget the lines they shaped after 64 KB
        of text, and a page nothing paints on again keeps its deflated content stream instead of its
        operators. Every form of `to_pdf` writes the same bytes as before.

        Headers, footers, page templates and a table of contents are painted once every page is known,
        so a document with them holds the operators of every page until then. `to_pdf(incremental: true)`
        (or `incremental` at class level) writes each page's content as soon as the page is painted
        instead, and what is painted later as content streams of its own:

        | Document | Pages | | Before | Now | `incremental: true` |
        |---|---:|---|---:|---:|---:|
        | Headings and paragraphs | 1,000 | peak | 391 MB | 111 MB | 108 MB |
        | | | alive | 216 MB | 17 MB | 14 MB |
        | | 5,001 | peak | 1,556 MB | 350 MB | 415 MB |
        | | | alive | 1,062 MB | 41 MB | 25 MB |
        | With a footer and a table of contents | 1,039 | peak | 397 MB | 145 MB | 106 MB |
        | | | alive | 222 MB | 44 MB | 11 MB |
        | | 5,189 | peak | 1,643 MB | 614 MB | 446 MB |
        | | | alive | 1,080 MB | 180 MB | 20 MB |
        | One table of 33,000 rows | 1,000 | peak | 901 MB | 174 MB | 174 MB |
        | | | alive | 494 MB | 26 MB | 23 MB |
        | One table of 165,000 rows | 5,000 | peak | 3,792 MB | 584 MB | 586 MB |
        | | | alive | 2,437 MB | 40 MB | 25 MB |

        "Peak" is the resident set size of one render in a fresh process, "alive" the megabytes that
        survive a garbage collection when pagination ends (`rake memory`, Apple M2 Max, Ruby 3.4.2
        +YJIT). The peak moves with the machine, up to a fifth between two runs here, so nothing gates
        on it. A document without headers, footers, templates or contents gains nothing from
        `incremental:`, and what is left in every case is the document as it was built: every node
        exists before the first page is painted. A table resolves its column widths from every cell
        and keeps the widths, not the cell's text: a cell's node is built when a page reaches its row
        and let go with the page. In a tagged render a row's `TR`, `TH` and `TD` are built when a page
        paints it, and the structure tree holds them until the file is written, so the table of
        165,000 rows tagged peaks at 2.2 GB. When `incremental:` takes the usual path instead is under
        [Rendering](/docs/documents-and-components#rendering).

        A table whose every column has a width measures no cell for its columns, and given its rows
        as an Enumerator, lazy or not, it reads them as pages reach them
        ([Elements](/docs/elements)): nothing of the table exists before its first page. A price
        list with a header row and zebra stripes, `incremental: true`:

        | Rows | Pages | Rows given as | Peak | Alive when built | Alive when paginated |
        |---:|---:|---|---:|---:|---:|
        | 100,000 | 3,031 | an Enumerator | 81 MB | 9 MB | 18 MB |
        | | | an Array | 485 MB | 155 MB | 20 MB |
        | 1,000,000 | 30,303 | an Enumerator | 130 MB | 9 MB | 47 MB |
        | | | an Array | 2,758 MB | 1,474 MB | 64 MB |

        What still grows with a streamed table is what the file needs of every page until it is
        written. Tagged, the structure tree holds the `TR`, `TH` and `TD` of every painted row until
        then, streamed or not: the 100,000 rows tagged peak at 989 MB streamed, 1,230 MB as an Array.
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
