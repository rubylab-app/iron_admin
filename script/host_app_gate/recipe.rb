require_relative "failure"

# The Rails 8 admin-only blocks from the authentication guide, read when the
# gate runs so the guide and the checks cannot drift.
class HostAppGateRecipe
  HEADING = "### With the Rails 8 authentication generator".freeze
  GUIDE = "docs/guides/authentication.md".freeze

  def self.install!
    code = source
    path = Rails.root.join("tmp/host_app_gate_recipe.rb")
    File.write(path, <<~RUBY)
      IronAdmin.configure do |config|
        config.title = "Shop Admin"
      #{code}
      end
    RUBY
    load path.to_s
  end

  def self.source
    text = guide_text
    index = text.index(HEADING)
    raise HostAppGateFailure, missing("heading") unless index

    section = text[index..]
    next_heading = section.index(/\n### /, HEADING.length)
    section = section[0...next_heading] if next_heading
    code = section[/\n```ruby\n(.*?)```/m, 1]
    raise HostAppGateFailure, missing("ruby block") if code.blank?
    unless code.include?("config.authenticate") && code.include?("config.current_user") && code.include?("|| false")
      raise HostAppGateFailure, missing("admin-only block")
    end

    code
  end

  def self.guide_text
    File.read(File.expand_path("../../#{GUIDE}", __dir__))
  rescue Errno::ENOENT
    raise HostAppGateFailure, missing("file")
  end

  def self.missing(kind)
    "Rails 8 authentication recipe #{kind} not found in #{GUIDE}"
  end
  private_class_method :guide_text, :missing
end
