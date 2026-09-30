# frozen_string_literal: true

# A Stationery::Verify engine without the tool: it answers what `read` makes
# of each path, or a read of no pages, and keeps the passwords it was given.
FakeEngine = Struct.new(:name, :available, :read, :passwords) do
  def install = "install #{name}"
  def available? = available
  def version = "#{name} 1.0"

  def facts(paths, password: nil)
    (self.passwords ||= []) << password
    paths.map { |path| read&.call(path) || { "file" => path, "pages" => [], "errors" => [], "warnings" => [] } }
  end
end
