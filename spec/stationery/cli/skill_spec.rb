# frozen_string_literal: true

require "tmpdir"
require "stationery/cli"

RSpec.describe Stationery::CLI::Skill do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:home) { Dir.mktmpdir("home") }
  let(:project) { Dir.mktmpdir("project") }
  let(:files) { Stationery::Skill.new.files }

  after { FileUtils.rm_rf([home, project]) }

  def skill(*argv) = described_class.new(out:, err:, home:, cwd: project).run(argv)
  def installed(*path) = File.join(home, *path, "stationery")

  it "is registered with the CLI" do
    expect(Stationery::CLI.commands).to include("skill" => described_class)
  end

  it "installs the skill for Claude Code in the user's skills" do
    expect(skill("install", "--target", "claude")).to eq(0)

    dir = installed(".claude", "skills")
    expect(File.read(File.join(dir, "SKILL.md"))).to eq(files.fetch("SKILL.md"))
    expect(File.read(File.join(dir, "reference/elements.md"))).to eq(files.fetch("reference/elements.md"))
    expect(out.string).to include("claude", File.join(dir, "SKILL.md"), Stationery::VERSION)
  end

  it "installs into the project's .claude/skills with --project" do
    expect(skill("install", "--target", "claude", "--project")).to eq(0)

    expect(File).to exist(File.join(project, ".claude/skills/stationery/SKILL.md"))
    expect(Dir.children(home)).to be_empty
  end

  it "installs into a skills directory of one's choosing with --dir" do
    dir = File.join(project, "agent-skills")

    expect(skill("install", "--dir", dir)).to eq(0)
    expect(File).to exist(File.join(dir, "stationery/SKILL.md"))
  end

  it "installs for the agents it finds when no target is named, and for Claude Code when it finds none" do
    expect(skill("install")).to eq(0)
    expect(Dir.children(home)).to eq([".claude"])

    FileUtils.mkdir_p(File.join(home, ".codex"))
    expect(skill("install")).to eq(0)
    expect(File).to exist(installed(".codex", "skills", ""))
    expect(File).not_to exist(installed(".agents", "skills", ""))
  end

  it "installs for every agent with --target all" do
    expect(skill("install", "--target", "all")).to eq(0)

    %w[.claude .codex .agents].each { expect(File).to exist(File.join(installed(it, "skills"), "SKILL.md")) }
  end

  it "replaces a skill of its own, from an older version" do
    dir = installed(".claude", "skills")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "SKILL.md"), files.fetch("SKILL.md").sub(Stationery::VERSION, "0.1.0"))

    expect(skill("install", "--target", "claude")).to eq(0)
    expect(File.read(File.join(dir, "SKILL.md"))).to eq(files.fetch("SKILL.md"))
    expect(out.string).to include("0.1.0")
  end

  it "refuses to overwrite a skill that is not its own, unless --force" do
    dir = installed(".claude", "skills")
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "SKILL.md"), "---\nname: stationery\n---\nMine.\n")

    expect(skill("install", "--target", "claude")).to eq(1)
    expect(err.string).to include("not written by stationery", "--force")
    expect(File.read(File.join(dir, "SKILL.md"))).to eq("---\nname: stationery\n---\nMine.\n")

    expect(skill("install", "--target", "claude", "--force")).to eq(0)
    expect(File.read(File.join(dir, "SKILL.md"))).to eq(files.fetch("SKILL.md"))
  end

  describe "status" do
    it "says missing, current or outdated for each agent, by the gem's version" do
      skill("install", "--target", "claude")
      dir = installed(".codex", "skills")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "SKILL.md"), files.fetch("SKILL.md").sub(Stationery::VERSION, "0.1.0"))
      out.string = +""

      expect(skill("status")).to eq(0)
      lines = out.string.lines
      expect(lines.grep(/\Aclaude/).first).to include("current", Stationery::VERSION)
      expect(lines.grep(/\Acodex/).first).to include("outdated", "0.1.0", "stationery skill install")
      expect(lines.grep(/\Aagents/).first).to include("missing")
    end

    it "says so of a skill that is not its own" do
      dir = installed(".claude", "skills")
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "SKILL.md"), "# Mine\n")

      skill("status")
      expect(out.string.lines.grep(/\Aclaude/).first).to include("not written by stationery")
    end

    it "says where else to look when it finds none, and finds one installed with --dir there" do
      dir = File.join(project, "agent-skills")
      skill("install", "--dir", dir)
      out.string = +""

      skill("status")
      expect(out.string).to include("home directory", "--project", "--dir DIR")

      out.string = +""
      skill("status", "--dir", dir)
      expect(out.string).to include(File.join(dir, "stationery/SKILL.md"), "current")
      expect(out.string).not_to include("--dir DIR")
    end

    it "looks in the project with --project" do
      skill("install", "--target", "claude", "--project")
      out.string = +""

      skill("status", "--project")
      expect(out.string.lines.grep(/\Aclaude/).first).to include(project, "current")
    end
  end

  it "prints the skill, its reference files after it, for an agent that takes one file" do
    expect(skill("print")).to eq(0)

    expect(out.string).to start_with(files.fetch("SKILL.md"))
    files.each_value { expect(out.string).to include(it) }
    expect(out.string).to include("<!-- reference/elements.md -->")
    expect(Dir.children(home)).to be_empty
  end

  it "prints help, and usage for what it does not know" do
    expect(skill("--help")).to eq(0)
    expect(out.string).to include("stationery skill install", "status", "print", "--target", "--project", "--force")

    expect(skill("frobnicate")).to eq(2)
    expect(skill("install", "--target", "vim")).to eq(2)
    expect(err.string).to include("claude, codex, agents or all")
  end
end
