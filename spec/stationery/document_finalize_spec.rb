# frozen_string_literal: true

# A document class finalized at boot: its settings are Ractor-shareable, so
# it renders inside any Ractor (spec/integration/ractor_canary_spec.rb).
FinalizedSpecDocument = Class.new(SpecDocument) do
  page size: :a6, margin: 24
  metadata title: "Finalized"
  page_template { |page| text "#{page.number}/#{page.count}" }
  footer { text "footer" }
end.finalize!

RSpec.describe Stationery::Document do
  describe ".finalize!" do
    it_behaves_like "a boot-finalized configuration",
                    readers: { "FinalizedSpecDocument.config" => -> { FinalizedSpecDocument.config } }

    it "answers the class" do
      klass = Class.new(SpecDocument)

      expect(klass.finalize!).to be(klass)
    end

    it "leaves the settings as they were, frozen" do
      expect(FinalizedSpecDocument.config).to be_frozen
      expect(FinalizedSpecDocument.config[:page]).to include(size: :a6, margin: 24)
      expect(FinalizedSpecDocument.config[:metadata]).to eq(title: "Finalized")
      expect { FinalizedSpecDocument.page(size: :a4) }.to raise_error(FrozenError)
    end

    it "lets a subclass of a finalized class have settings of its own" do
      subclass = Class.new(FinalizedSpecDocument) { page size: :a5 }

      expect(subclass.config[:page]).to include(size: :a5)
      expect(FinalizedSpecDocument.config[:page]).to include(size: :a6)
    end

    it "renders what the class rendered before it was finalized" do
      allow(Time).to receive(:now).and_return(Time.utc(2026, 1, 1, 12))
      body = proc do
        page size: :a6, margin: 24
        page_template { |page| text "#{page.number}/#{page.count}" }
        footer { text "footer" }
        def view_template = 3.times { text "Hello" }
      end
      open = Class.new(SpecDocument, &body)
      finalized = Class.new(SpecDocument, &body).finalize!

      expect(finalized.new.to_pdf).to eq(open.new.to_pdf)
    end
  end

  describe ".config" do
    it "is built when a class is defined, before anything reads it" do
      expect(Class.new(described_class).instance_variable_get(:@config)).to be_a(Hash)
    end

    it "keeps the defaults of Stationery::Document itself frozen" do
      expect(described_class.config).to be_frozen
      expect(Ractor.shareable?(described_class.config)).to be(true) if defined?(Ractor)
    end

    it "copies each setting from the parent, so a subclass's never reaches it" do
      parent = Class.new(described_class) { font_family "Inter" }
      child = Class.new(parent) { font_family "Brand", regular: "Brand.ttf" }

      expect(parent.config[:families].keys).to eq(["Inter"])
      expect(child.config[:families].keys).to eq(%w[Inter Brand])
    end
  end
end
