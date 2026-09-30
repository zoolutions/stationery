# frozen_string_literal: true

require "stationery/verify"

RSpec.describe Stationery::Verify::Command do
  it "runs an argument array, with no shell between, and answers its output and status" do
    result = described_class.run("ruby", "-e", "print ARGV.first; warn 'noted'; exit 3", "$HOME; echo no")

    expect(result).to have_attributes(stdout: "$HOME; echo no", stderr: end_with("noted\n"), exitstatus: 3,
                                      timed_out: false)
    expect(result.success?).to be(false)
  end

  it "hands the child its environment" do
    expect(described_class.run("ruby", "-e", "print ENV['STATIONERY_VERIFY_PASSWORD']",
                               env: { "STATIONERY_VERIFY_PASSWORD" => "secret" }).stdout).to eq("secret")
  end

  it "drains a large output while the child runs" do
    expect(described_class.run("ruby", "-e", "$stdout.write('x' * 1_000_000); $stderr.write('y' * 1_000_000)")
      .stdout.size).to eq(1_000_000)
  end

  it "kills a child that runs past its timeout" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = described_class.run("ruby", "-e", "sleep 30", timeout: 0.2)

    expect(result.timed_out).to be(true)
    expect(result.success?).to be(false)
    expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 10
  end

  it "finds an executable on the PATH or at a path, and nothing else" do
    ruby = described_class.which("ruby")

    expect(ruby).to end_with("/ruby")
    expect(described_class.which(ruby)).to eq(ruby)
    expect(described_class.which("stationery-no-such-tool")).to be_nil
    expect(described_class.which(__FILE__)).to be_nil
  end
end
