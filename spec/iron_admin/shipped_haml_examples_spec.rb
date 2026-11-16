# frozen_string_literal: true

require "rails_helper"
require "fileutils"
require "tmpdir"
require "open3"

# Compiles the haml examples shipped in the gem. Rendering is out of scope:
# a block that does not compile, or that names a component that does not exist, fails here.
class ShippedHamlExampleScanner
  FENCE_OPENER = /\A(?<indent> *)(?<mark>(?:`{3,}|~{3,}))[ \t]*(?:\{\.)?haml\b(?<info>.*)\s*\z/i
  EXEMPT = /haml-compile:\s*skip/i
  MARKDOWN_PREFIX = /\A(?:[ \t]{0,3}>[ \t]?|[ \t]*(?:[-*+]|\d+\.)[ \t]+)/
  COMPONENT_CONSTANT = /(?<![:\w])IronAdmin::(?:[A-Z][A-Za-z0-9]*::)*[A-Z][A-Za-z0-9]*Component\b/
  PATHSPEC = ["README.md", "UPGRADING.md", ":(glob)docs/**/*.md"].freeze
  Failure = Struct.new(:location, :message, keyword_init: true)
  Block = Struct.new(:location, :source, keyword_init: true)

  class << self
    delegate :root, to: :"IronAdmin::Engine"

    def files
      listed = tracked_files
      listed = filter_ignored(fallback_paths) if listed.nil?
      listed.select { |path| File.file?(path) && shipped?(path) }
    end

    # Fences scan compiles. An exempt fence is left out, so the count and the
    # scan share one extraction.
    def blocks(paths)
      paths.flat_map { |path| blocks_in(path) }
    end

    def scan(paths)
      blocks(paths).filter_map { |block| failure_for(block) }
    end

    # Compile the way ActionView does: the handler Rails registered for the
    # installed Haml, then the Ruby inside a method body. A parser that can
    # raise (Haml 6 and later) runs first, because those versions otherwise
    # hide a parse error inside Ruby that compiles. Haml 5 registers that
    # handler when ActionView::Base loads.
    def compile(source)
      parse_raising(source)
      handler = haml_handler
      template = ActionView::Template.new(
        source, "shipped_haml_example.haml", handler, locals: [], format: :html
      )
      ruby = "def __haml_example(local_assigns, output_buffer)\n#{handler.call(template, source)}\nend"
      RubyVM::InstructionSequence.compile(ruby)
      resolve_components(source)
    end

    private

    def tracked_files
      stdout, _stderr, status = Open3.capture3(
        "git", "ls-files", "-z", "--cached", "--others", "--exclude-standard", "--",
        *PATHSPEC,
        chdir: root.to_s
      )
      return nil unless status.success?

      stdout.split("\0").reject(&:empty?).map { |relative| root.join(relative).to_s }
    rescue Errno::ENOENT
      nil
    end

    def fallback_paths
      [root.join("README.md"), root.join("UPGRADING.md"), *Dir[root.join("docs/**/*.md")]].map(&:to_s)
    end

    def filter_ignored(paths)
      rules = gitignore_rules
      paths.reject { |path| gitignore_match?(relative_path(path), rules) }
    end

    def gitignore_rules
      file = root.join(".gitignore")
      return [] unless file.file?

      file.each_line.filter_map { |line| gitignore_rule(line) }
    end

    def gitignore_rule(line)
      entry = line.strip
      return if entry.empty? || entry.start_with?("#")

      [entry.delete_prefix("/").delete_suffix("/"), entry.end_with?("/")]
    end

    def gitignore_match?(relative, rules)
      rules.any? { |pattern, directory| gitignore_rule_match?(relative, pattern, directory) }
    end

    def gitignore_rule_match?(relative, pattern, directory)
      if directory
        relative == pattern || relative.start_with?("#{pattern}/")
      else
        File.fnmatch?(pattern, relative, File::FNM_PATHNAME)
      end
    end

    def shipped?(path)
      relative = relative_path(path)
      !relative.start_with?("docs/site/") && relative != "docs/mobile-responsiveness-audit.md"
    end

    def relative_path(path)
      Pathname.new(path).relative_path_from(root).to_s
    end

    def parse_raising(source)
      return unless defined?(Haml::Parser)

      parser = Haml::Parser.new({})
      return unless parser.instance_variable_defined?(:@raise_error)
      return unless parser.instance_variable_get(:@raise_error)

      parser.call(source)
    rescue ArgumentError
      nil
    end

    def resolve_components(source)
      source.scan(COMPONENT_CONSTANT).uniq.each { |name| Object.const_get(name) }
    end

    def haml_handler
      handler = template_handler(ActionView::Base)
      raise "no :haml template handler registered" if handler.nil?

      handler
    end

    # The argument loads ActionView::Base before the lookup. Haml 5 registers
    # its handler from ActiveSupport.on_load(:action_view), which runs then.
    def template_handler(_action_view)
      ActionView::Template.registered_template_handler(:haml)
    end

    def blocks_in(path)
      relative = relative_path(path)
      each_fence(File.read(path)).filter_map do |line, source|
        next if source.match?(EXEMPT)

        Block.new(location: "#{relative}:#{line}", source: source)
      end
    end

    def failure_for(block)
      compile(block.source)
      nil
    rescue StandardError, SyntaxError => e
      Failure.new(location: block.location, message: e.message.lines.first.to_s.strip)
    end

    def each_fence(text)
      lines = text.lines
      index = 0
      found = []
      while index < lines.length
        opener = fence_opener(lines[index])
        unless opener
          index += 1
          next
        end

        body_line = index + 2
        body, index = fence_body(lines, index + 1, opener, markdown_prefixed?(lines[index]))
        found << [body_line, body]
      end
      found
    end

    def fence_opener(line)
      match = FENCE_OPENER.match(strip_markdown_prefix(line))
      return unless match

      { indent: match[:indent].length, mark: match[:mark], info: match[:info] }
    end

    def fence_body(lines, index, opener, quoted)
      body = +""
      while index < lines.length && !fence_closer?(lines[index], opener)
        line = lines[index]
        line = strip_markdown_prefix(line) if quoted
        body << dedent_line(line, opener[:indent])
        index += 1
      end
      [body, index + 1]
    end

    def fence_closer?(line, opener)
      stripped = strip_markdown_prefix(line)
      indent = [opener[:indent], 3].max
      character = Regexp.escape(opener[:mark][0])
      stripped.match?(/\A {0,#{indent}}#{character}{#{opener[:mark].length},}\s*\z/)
    end

    def dedent_line(line, width)
      width.zero? ? line : line.sub(/\A {0,#{width}}/, "")
    end

    def markdown_prefixed?(line)
      strip_markdown_prefix(line) != line
    end

    def strip_markdown_prefix(line)
      rest = line
      rest = rest.sub(MARKDOWN_PREFIX, "") while rest.match?(MARKDOWN_PREFIX)
      rest
    end
  end
end

module IronAdmin
  module ShippedHamlExamples
    class << self
      delegate :compile, :files, :blocks, :scan, to: :ShippedHamlExampleScanner
    end
  end
end

RSpec.describe IronAdmin::ShippedHamlExamples do
  describe ".compile" do
    it "compiles a call whose arguments continue after a comma" do
      source = <<~HAML
        = render IronAdmin::Ui::ScopesComponent.new(scopes: scopes,
          current_scope: current,
          counts: counts)
      HAML

      expect { described_class.compile(source) }.not_to raise_error
    end

    it "rejects a call split before its arguments" do
      source = <<~HAML
        = render IronAdmin::Ui::ScopesComponent.new(
          scopes: scopes)
      HAML

      expect { described_class.compile(source) }.to raise_error(/Illegal nesting|syntax error/i)
    end

    it "rejects a block that assigns a constant" do
      expect { described_class.compile("- ExampleConst = 1\n") }.to raise_error(SyntaxError)
    end

    it "compiles a block that yields" do
      expect { described_class.compile("= yield\n") }.not_to raise_error
    end

    it "rejects a call whose closing parenthesis opens the block" do
      source = <<~HAML
        = render IronAdmin::Ui::ButtonComponent.new(label: "Save",
          variant: :primary
        ) do |bar|
          = bar
      HAML

      expect { described_class.compile(source) }.to raise_error(/Illegal nesting|syntax error/i)
    end

    it "rejects a block that names a component that does not exist" do
      source = "= render IronAdmin::Filters::MissingFilterComponent.new\n"

      expect { described_class.compile(source) }.to raise_error(NameError)
    end
  end

  describe ".files" do
    subject(:files) do
      root = IronAdmin::Engine.root
      described_class.files.map { |path| Pathname.new(path).relative_path_from(root).to_s }
    end

    it "includes the upgrade guide" do
      expect(files).to include("UPGRADING.md", "docs/components/ui-components.md")
    end

    it "leaves out the documentation site and the mobile audit" do
      expect(files.grep(%r{\Adocs/site/|mobile-responsiveness-audit})).to eq([])
    end

    it "leaves out git-ignored plans" do
      directory = IronAdmin::Engine.root.join("docs/plans")
      created_directory = !directory.exist?
      FileUtils.mkdir_p(directory)
      File.write(directory.join("zz_haml_fixture.md"), "```haml\n%p ignored\n```\n")

      expect(files.grep(%r{docs/plans/})).to eq([])
    ensure
      directory = IronAdmin::Engine.root.join("docs/plans")
      FileUtils.rm_f(directory.join("zz_haml_fixture.md"))
      Dir.rmdir(directory) if created_directory && directory.exist? && Dir.empty?(directory)
    end

    context "when git is not available" do
      before { allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT) }

      it "includes the upgrade guide" do
        expect(files).to include("UPGRADING.md", "docs/components/ui-components.md")
      end

      it "leaves out git-ignored plans" do
        directory = IronAdmin::Engine.root.join("docs/plans")
        created_directory = !directory.exist?
        FileUtils.mkdir_p(directory)
        File.write(directory.join("zz_haml_fixture.md"), "```haml\n%p ignored\n```\n")

        expect(files.grep(%r{docs/plans/})).to eq([])
      ensure
        directory = IronAdmin::Engine.root.join("docs/plans")
        FileUtils.rm_f(directory.join("zz_haml_fixture.md"))
        Dir.rmdir(directory) if created_directory && directory.exist? && Dir.empty?(directory)
      end
    end
  end

  describe ".scan" do
    def broken_call
      <<~HAML
        = render IronAdmin::Ui::ScopesComponent.new(
          scopes: scopes)
      HAML
    end

    it "compiles every shipped haml example" do
      failures = described_class.scan(described_class.files)

      expect(failures.map { |failure| "#{failure.location} #{failure.message}" }).to eq([])
    end

    it "compiles at least the fences the gem ships" do
      expect(described_class.blocks(described_class.files).size).to be >= 47
    end

    it "reports one failure for a file with a valid fence and a broken fence" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "note.md")
        File.write(path, <<~MARKDOWN)
          ```haml
          %p ok
          ```

          ```haml
          #{broken_call.strip}
          ```
        MARKDOWN
        relative = Pathname.new(path).relative_path_from(IronAdmin::Engine.root)

        expect(described_class.scan([path]).map(&:location)).to eq(["#{relative}:6"])
      end
    end

    it "skips a fence marked haml-compile: skip" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "note.md")
        File.write(path, <<~MARKDOWN)
          ```haml
          -# haml-compile: skip
          #{broken_call.strip}
          ```
        MARKDOWN

        expect(described_class.scan([path])).to eq([])
      end
    end
  end
end
