# frozen_string_literal: true

RSpec.describe Stationery::Component do
  let(:greeting) do
    Class.new(described_class) do
      def initialize(name)
        super()
        @name = name
      end

      def view_template = text("Hello #{@name}")
    end
  end

  let(:card) do
    Class.new(described_class) do
      def view_template(&) = box(padding: 4, background: "#EEEEEE", &)
    end
  end

  it "runs around, before, view and after template in order" do
    log = []
    component = Class.new(described_class) do
      define_method(:around_template) do |&blk|
        log << :around_in
        blk.call
        log << :around_out
      end
      define_method(:before_template) { log << :before }
      define_method(:view_template) { log << :view }
      define_method(:after_template) { log << :after }
    end
    SpecDocument.build { render component.new }.to_pdf

    expect(log).to eq(%i[around_in before view after around_out])
  end

  it "renders instances, classes, strings, procs and collections into the same document" do
    greeting_class = greeting
    no_args = Class.new(described_class) { def view_template = text("from a class") }
    pdf = SpecDocument.build do
      render greeting_class.new("Ada")
      render no_args
      render "a string"
      render -> { text "a proc" }
      render [greeting_class.new("Bo"), greeting_class.new("Cy")]
    end.to_pdf

    expect(strings_of(pdf)).to eq(["Hello Ada", "from a class", "a string", "a proc", "Hello Bo", "Hello Cy"])
  end

  it "passes a block through to a component's content" do
    card_class = card
    pdf = SpecDocument.build { render(card_class.new) { text "inside the card" } }.to_pdf

    expect(text_of(pdf)).to eq("inside the card")
    expect(page_contents(pdf).first).to include("0.9333 0.9333 0.9333 rg")
  end

  it "yields the component to blocks that take an argument" do
    seen = nil
    component = Class.new(described_class) { def view_template(&) = yield_content(&) }
    SpecDocument.build { render(component.new) { |c| seen = c } }.to_pdf

    expect(seen).to be_a(described_class)
  end

  it "refuses things it cannot render" do
    expect { SpecDocument.build { render 42 }.to_pdf }.to raise_error(ArgumentError, /can't render 42/)
  end
end
