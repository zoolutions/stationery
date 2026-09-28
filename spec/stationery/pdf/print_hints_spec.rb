# frozen_string_literal: true

RSpec.describe Stationery::PDF::PrintHints do
  def entries(hints, pages = 5) = described_class.catalog_entries(described_class.options(hints), pages:)
  def preferences(hints, pages = 5) = entries(hints, pages)[:ViewerPreferences]

  describe ".options" do
    it "answers the hints it was given" do
      hints = { scaling: :none, copies: 2, pick_tray_by_size: true, duplex: :simplex, pages: 1..3, dialog: :on_open }

      expect(described_class.options(hints)).to eq(hints)
    end

    it "lets a nil through, which takes a hint away" do
      expect(described_class.options(copies: nil, pages: nil)).to eq(copies: nil, pages: nil)
    end

    it "refuses an unknown hint, naming the ones there are" do
      expect { described_class.options(colour: :red) }
        .to raise_error(ArgumentError, "unknown print hint :colour (use :scaling, :copies, :pick_tray_by_size, " \
                                       ":duplex, :pages, :dialog)")
    end

    it "refuses a value a hint does not take, naming what it takes" do
      {
        { scaling: :fit } => "print scaling: is :none or :default, not :fit",
        { copies: 0 } => "print copies: is an Integer of 1 or more, not 0",
        { copies: "2" } => 'print copies: is an Integer of 1 or more, not "2"',
        { copies: 1.5 } => "print copies: is an Integer of 1 or more, not 1.5",
        { pick_tray_by_size: :yes } => "print pick_tray_by_size: is true or false, not :yes",
        { duplex: :both } => "print duplex: is :simplex, :long_edge or :short_edge, not :both",
        { dialog: true } => "print dialog: is :on_open, not true"
      }.each do |hints, message|
        expect { described_class.options(hints) }.to raise_error(ArgumentError, message)
      end
    end

    it "refuses pages that are not ranges of page numbers from 1" do
      message = /print pages: is a Range of page numbers from 1 \(1\.\.3\) or a list of them, not /
      [3, "1-3", 0..2, 3..1, 1.0..2.0, [], [1..2, 4], ("a".."c"), 2...2].each do |pages|
        expect { described_class.options(pages:) }.to raise_error(ArgumentError, message)
      end
    end

    it "refuses ranges that overlap" do
      expect { described_class.options(pages: [1..3, 3..4]) }
        .to raise_error(ArgumentError, "print pages: 1..3 and 3..4 overlap")
      expect { described_class.options(pages: [4..6, 1..]) }
        .to raise_error(ArgumentError, "print pages: 1.. and 4..6 overlap")
    end
  end

  describe ".merge" do
    it "is nil without a hint" do
      expect(described_class.merge({}, {})).to be_nil
      expect(described_class.merge({}, { copies: nil })).to be_nil
    end

    it "lays the render's hints over the class's, and a nil takes one away" do
      declared = { scaling: :none, copies: 2 }

      expect(described_class.merge(declared, {})).to eq(scaling: :none, copies: 2)
      expect(described_class.merge(declared, { copies: 1, duplex: :simplex }))
        .to eq(scaling: :none, copies: 1, duplex: :simplex)
      expect(described_class.merge(declared, { copies: nil })).to eq(scaling: :none)
    end

    it "takes every hint away with nil or false" do
      expect(described_class.merge({ copies: 2 }, nil)).to be_nil
      expect(described_class.merge({ copies: 2 }, false)).to be_nil
    end

    it "checks what the render gives" do
      expect { described_class.merge({}, { copies: 0 }) }.to raise_error(ArgumentError, /copies:/)
      expect { described_class.merge({}, :none) }
        .to raise_error(ArgumentError, "print: takes a Hash of hints, nil or false, not :none")
    end
  end

  describe ".catalog_entries" do
    it "writes each hint under its key of ISO 32000-1, table 150" do
      expect(preferences(scaling: :none, copies: 2, pick_tray_by_size: true, duplex: :simplex, pages: 1..3))
        .to eq(PrintScaling: :None, NumCopies: 2, PickTrayByPDFSize: true, Duplex: :Simplex, PrintPageRange: [1, 3])
    end

    it "maps every scaling and duplex" do
      expect(preferences(scaling: :default)).to eq(PrintScaling: :AppDefault)
      expect(preferences(duplex: :long_edge)).to eq(Duplex: :DuplexFlipLongEdge)
      expect(preferences(duplex: :short_edge)).to eq(Duplex: :DuplexFlipShortEdge)
      expect(preferences(pick_tray_by_size: false)).to eq(PickTrayByPDFSize: false)
    end

    it "writes page ranges as pairs of 1-based page numbers, in page order" do
      expect(preferences(pages: [4..5, 1..1])).to eq(PrintPageRange: [1, 1, 4, 5])
      expect(preferences(pages: 1...3)).to eq(PrintPageRange: [1, 2])
      expect(preferences(pages: 2..)).to eq(PrintPageRange: [2, 5])
      expect(preferences(pages: ..2)).to eq(PrintPageRange: [1, 2])
    end

    it "cuts a range at the last page and leaves out one that starts after it" do
      expect(preferences({ pages: 2..9 }, 3)).to eq(PrintPageRange: [2, 3])
      expect(preferences({ pages: [1..1, 4..6] }, 3)).to eq(PrintPageRange: [1, 1])
      expect(entries({ pages: 4..6 }, 3)).to eq({})
    end

    it "opens the print dialog with a named action" do
      expect(entries(dialog: :on_open)).to eq(OpenAction: { Type: :Action, S: :Named, N: :Print })
    end
  end

  describe ".read" do
    it "reads the hints back from the catalog's entries" do
      catalog = { ViewerPreferences: { DisplayDocTitle: true, PrintScaling: :None, NumCopies: 2,
                                       PickTrayByPDFSize: true, Duplex: :DuplexFlipLongEdge,
                                       PrintPageRange: [1, 1, 3, 4] },
                  OpenAction: { S: :Named, N: :Print } }

      expect(described_class.read(catalog))
        .to eq(scaling: :none, copies: 2, pick_tray_by_size: true, duplex: :long_edge, pages: [1..1, 3..4],
               dialog: :on_open)
    end

    it "is empty without any, and keeps a name it does not know" do
      expect(described_class.read({})).to eq({})
      expect(described_class.read(ViewerPreferences: { DisplayDocTitle: true }, OpenAction: [1, :Fit])).to eq({})
      expect(described_class.read(ViewerPreferences: { PrintScaling: :Other })).to eq(scaling: :Other)
    end
  end
end
