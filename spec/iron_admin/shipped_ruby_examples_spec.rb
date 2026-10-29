# frozen_string_literal: true

require "rails_helper"
require "prism"
require "open3"
require "fileutils"

# Parses shipped Ruby examples and reports an engine class outside the namespace Zeitwerk expects.
class ShippedRubyExampleScanner
  TARGETS = {
    "IronAdmin::Resource" => "IronAdmin::Resources::",
    "IronAdmin::Dashboard" => "IronAdmin::Dashboards::",
    "IronAdmin::Tool" => "IronAdmin::Tools::",
  }.freeze
  BEFORE_MARKER = /\A# Before \([^)]+\):\s*\z/
  AFTER_MARKER = /\A# After\b/
  FENCE_OPENER = /\A(?<indent> *)(?<mark>(?:`{3,}|~{3,}))[ \t]*(?:\{\.)?(?<lang>ruby|rb)\b.*\s*\z/i
  FENCE_COUNT = /\A *(?:`{3,}|~{3,})[ \t]*(?:\{\.)?(?:ruby|rb)\b/i
  EXAMPLE_TAG = /\A\s*#\s*@example\b/i
  COMMENT_LINE = /\A\s*#/
  MARKDOWN_PREFIX = /\A(?:[ \t]{0,3}>[ \t]?|[ \t]*(?:[-*+]|\d+\.)[ \t]+)/
  PATHSPEC = ["README.md", "UPGRADING.md", "docs/*.md", ":(glob)lib/**/*.rb", ":(glob)app/**/*.rb"].freeze
  ClassRef = Struct.new(:full, :superclass, :line, keyword_init: true)
  Opener = Struct.new(:indent, :mark, keyword_init: true)
  Result = Struct.new(:offenses, :checked, :partial, :skipped, :fences, :yard_blocks, keyword_init: true)

  class << self
    delegate :root, to: :"IronAdmin::Engine"

    def files
      listed = tracked_files
      listed = filter_ignored(fallback_paths) if listed.nil?
      listed.select { |path| File.file?(path) }
    end

    def filter_ignored(paths)
      rules = gitignore_rules
      paths.reject { |path| gitignore_match?(relative_path(path), rules) }
    end

    def scan(paths)
      result = blank_result
      paths.each { |path| scan_file(path, result) }
      result
    end

    def scan_source(code, file:, body_start:)
      result = blank_result
      classify(code, file, body_start, result)
      result
    end

    private

    def blank_result
      Result.new(offenses: [], checked: 0, partial: 0, skipped: 0, fences: 0, yard_blocks: 0)
    end

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
      [
        root.join("README.md"),
        root.join("UPGRADING.md"),
        *Dir[root.join("docs/**/*.md")],
        *Dir[root.join("lib/**/*.rb")],
        *Dir[root.join("app/**/*.rb")],
      ].map(&:to_s)
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

    def scan_file(path, result)
      text = File.read(path)
      relative = relative_path(path)
      if path.end_with?(".rb")
        scan_yard(text, relative, result)
      else
        scan_markdown(text, relative, result)
      end
    end

    def scan_markdown(text, file, result)
      result.fences += count_ruby_fences(text)
      each_fence(text) { |body_start, code| classify(code, file, body_start, result) }
    end

    def count_ruby_fences(text)
      text.lines.count { |line| strip_markdown_prefix(line).match?(FENCE_COUNT) }
    end

    def scan_yard(text, file, result)
      result.yard_blocks += text.lines.count { |line| line.match?(EXAMPLE_TAG) }
      each_example(text) { |body_start, code| classify(code, file, body_start, result) }
    end

    def relative_path(path)
      pathname = Pathname.new(path)
      return path unless pathname.absolute?

      pathname.relative_path_from(root).to_s
    rescue ArgumentError
      path
    end

    def each_fence(text)
      lines = text.lines
      index = 0
      while index < lines.length
        opener = fence_opener(lines[index])
        unless opener
          index += 1
          next
        end

        quoted = markdown_prefixed?(lines[index])
        body_start = index + 2
        body, index = fence_body(lines, index + 1, opener, quoted)
        yield body_start, body
      end
    end

    def fence_opener(line)
      match = FENCE_OPENER.match(strip_markdown_prefix(line))
      return unless match

      Opener.new(indent: match[:indent].length, mark: match[:mark])
    end

    def fence_body(lines, index, opener, quoted)
      body = +""
      while index < lines.length && !fence_closer?(lines[index], opener)
        line = lines[index]
        body << (quoted ? strip_markdown_prefix(line) : line)
        index += 1
      end
      [body, index + 1]
    end

    def fence_closer?(line, opener)
      stripped = strip_markdown_prefix(line)
      indent = [opener.indent, 3].max
      character = Regexp.escape(opener.mark[0])
      stripped.match?(/\A {0,#{indent}}#{character}{#{opener.mark.length},}\s*\z/)
    end

    def markdown_prefixed?(line)
      strip_markdown_prefix(line) != line
    end

    def strip_markdown_prefix(line)
      rest = line
      rest = rest.sub(MARKDOWN_PREFIX, "") while rest.match?(MARKDOWN_PREFIX)
      rest
    end

    def each_example(text)
      lines = text.lines
      index = 0
      while index < lines.length
        column = example_column(lines[index])
        unless column
          index += 1
          next
        end

        body_start = index + 2
        body, index = example_body(lines, index + 1, column)
        yield body_start, body
      end
    end

    def example_column(line)
      return unless line.match?(EXAMPLE_TAG)

      line.index("@")
    end

    def example_body(lines, index, column)
      body = +""
      while index < lines.length && comment_body?(lines[index], column)
        body << lines[index].sub(/\A\s*# ?/, "")
        index += 1
      end
      [body, index]
    end

    def comment_body?(line, column)
      line.match?(COMMENT_LINE) && !tag_at?(line, column)
    end

    def tag_at?(line, column)
      at = line.index("@")
      at == column && line.match?(/@[a-z]/i)
    end

    def classify(code, file, body_start, result)
      parsed = Prism.parse(code)
      if parsed.value.nil?
        result.skipped += 1
        return
      end

      record_parse(parsed, result)
      classes = []
      gather_classes(parsed.value, "", classes)
      kinds = kind_prefixes(classes)
      classes.each do |ref|
        next if exempt_line?(file, code, ref.line)

        record_offense(ref, kinds, file, body_start, result)
      end
    end

    def exempt_line?(file, code, line)
      return false unless upgrading_before?(file, code)

      cutoff = after_cutoff(code)
      cutoff.nil? || line < cutoff
    end

    def upgrading_before?(file, code)
      file == "UPGRADING.md" && before_marker?(code)
    end

    def before_marker?(code)
      line = code.each_line.find { |entry| !entry.strip.empty? }
      line&.match?(BEFORE_MARKER) || false
    end

    def after_cutoff(code)
      code.each_line.with_index(1) do |entry, number|
        return number if entry.strip.match?(AFTER_MARKER)
      end
      nil
    end

    def record_parse(parsed, result)
      if parsed.success?
        result.checked += 1
      else
        result.partial += 1
      end
    end

    def gather_classes(node, nesting, classes)
      return if node.nil?

      if node.is_a?(Prism::ClassNode)
        remember_class(node, nesting, classes)
        gather_classes(node.body, child_nesting(node, nesting), classes)
      elsif node.is_a?(Prism::ModuleNode)
        gather_classes(node.body, child_nesting(node, nesting), classes)
      else
        node.child_nodes.each { |child| gather_classes(child, nesting, classes) }
      end
    end

    def remember_class(node, nesting, classes)
      full = lexical_name(node.constant_path, nesting)
      return if full.nil?

      classes << ClassRef.new(
        full: full,
        superclass: resolve_reference(node.superclass, nesting, classes),
        line: node.location.start_line
      )
    end

    def child_nesting(node, nesting)
      lexical_name(node.constant_path, nesting) || nesting
    end

    def lexical_name(node, nesting)
      name, rooted = const_parts(node)
      return if name.nil?
      return name if rooted

      reference_candidates(name, nesting).first
    end

    def resolve_reference(node, nesting, classes)
      name, rooted = const_parts(node)
      return if name.nil?
      return name if rooted

      choices = reference_candidates(name, nesting)
      known = known_names(classes)
      choices.find { |candidate| known.include?(candidate) } || choices.first
    end

    def reference_candidates(name, nesting)
      prefixes = nesting.split("::").reject(&:empty?)
      choices = []
      while prefixes.any?
        choices << "#{prefixes.join("::")}::#{name}"
        prefixes.pop
      end
      choices << name
      choices
    end

    def known_names(classes)
      TARGETS.keys | classes.map(&:full)
    end

    def const_parts(node)
      case node
      when Prism::ConstantReadNode
        [node.name.to_s, false]
      when Prism::ConstantPathNode
        path_parts(node)
      else
        [nil, false]
      end
    end

    def path_parts(node)
      return [node.name.to_s, true] if node.parent.nil?

      parent, rooted = const_parts(node.parent)
      ["#{parent}::#{node.name}", rooted]
    end

    def kind_prefixes(classes)
      supers = superclass_map(classes)
      kinds = {}
      loop { break if add_kinds(supers, kinds).zero? }
      kinds
    end

    def superclass_map(classes)
      classes.each_with_object({}) do |ref, supers|
        next if supers[ref.full]

        supers[ref.full] = ref.superclass unless supers.key?(ref.full) && ref.superclass.nil?
      end
    end

    def add_kinds(supers, kinds)
      added = 0
      supers.each do |full, superclass|
        next if kinds.key?(full)

        prefix = prefix_for(superclass, kinds)
        next unless prefix

        kinds[full] = prefix
        added += 1
      end
      added
    end

    def prefix_for(superclass, kinds)
      return if superclass.nil?

      TARGETS[superclass] || kinds[superclass]
    end

    def record_offense(ref, kinds, file, body_start, result)
      prefix = kinds[ref.full]
      return if prefix.nil? || ref.full.start_with?(prefix)

      result.offenses << "#{file}:#{body_start + ref.line - 1} #{ref.full}"
    end
  end
end

module IronAdmin
  module ShippedRubyExamples
    class << self
      delegate :root, :files, :filter_ignored, :scan, to: :ShippedRubyExampleScanner

      def scan_source(code, file:, body_start:)
        ShippedRubyExampleScanner.scan_source(code, file: file, body_start: body_start)
      end
    end
  end
end

RSpec.describe IronAdmin::ShippedRubyExamples do
  describe ".scan_source" do
    subject(:result) { described_class.scan_source(code, file: file, body_start: body_start) }

    let(:file) { "example.rb" }
    let(:body_start) { 10 }

    context "when Prism reports an error inside a class" do
      let(:code) { "class UserResource < IronAdmin::Resource\n  ...\nend\n" }

      it "reports the class" do
        expect(result.offenses).to eq(["example.rb:10 UserResource"])
      end

      it "counts the block as partial" do
        expect(result).to have_attributes(partial: 1, checked: 0, skipped: 0, fences: 0, yard_blocks: 0)
      end
    end

    context "when a resource is defined at the top level" do
      let(:code) { "class UserResource < IronAdmin::Resource\nend\n" }
      let(:file) { "docs/guides/resources.md" }

      it "reports the file and line" do
        expect(result.offenses).to eq(["docs/guides/resources.md:10 UserResource"])
      end
    end

    context "when the class is nested in the autoloaded modules" do
      let(:code) do
        <<~RUBY
          module IronAdmin
            module Resources
              class UserResource < IronAdmin::Resource
              end
            end
          end
        RUBY
      end

      it "accepts the class" do
        expect(result.offenses).to be_empty
      end
    end

    context "when the class name is a compact constant path" do
      let(:code) { "class IronAdmin::Resources::UserResource < IronAdmin::Resource\nend\n" }

      it "accepts the class" do
        expect(result.offenses).to be_empty
      end
    end

    context "when a dashboard and a tool are defined at the top level" do
      let(:code) { "class AdminDashboard < IronAdmin::Dashboard\nend\nclass ReportTool < IronAdmin::Tool\nend\n" }

      it "reports both classes" do
        expect(result.offenses).to eq(["example.rb:10 AdminDashboard", "example.rb:12 ReportTool"])
      end
    end

    context "when the superclass is not an engine base class" do
      let(:code) { "class UserResource < ApplicationResource\nend\n" }

      it "ignores the class" do
        expect(result.offenses).to be_empty
      end
    end

    context "when the class is nested only in IronAdmin" do
      let(:code) do
        <<~RUBY
          module IronAdmin
            class UserResource < IronAdmin::Resource
            end
          end
        RUBY
      end

      it "reports the class" do
        expect(result.offenses).to eq(["example.rb:11 IronAdmin::UserResource"])
      end
    end

    context "when the superclass is relative to IronAdmin" do
      let(:code) do
        <<~RUBY
          module IronAdmin
            class UserResource < Resource
            end
          end
        RUBY
      end

      it "reports the class" do
        expect(result.offenses).to eq(["example.rb:11 IronAdmin::UserResource"])
      end
    end

    context "when a relative superclass names a different constant" do
      let(:code) do
        <<~RUBY
          module IronAdmin
            module Resources
              class UserResource < Resource
              end
            end
          end
        RUBY
      end

      it "does not treat that constant as the engine base class" do
        expect(result.offenses).to be_empty
      end
    end

    context "when a class inherits from a base defined in the same block" do
      let(:code) do
        <<~RUBY
          class BaseTool < IronAdmin::Tool
          end
          class ReportsTool < BaseTool
          end
        RUBY
      end

      it "reports both classes" do
        expect(result.offenses).to eq(["example.rb:10 BaseTool", "example.rb:12 ReportsTool"])
      end
    end

    context "when the subclass appears before its base" do
      let(:code) do
        <<~RUBY
          class ReportsTool < BaseTool
          end
          class BaseTool < IronAdmin::Tool
          end
        RUBY
      end

      it "reports both classes" do
        expect(result.offenses).to eq(["example.rb:10 ReportsTool", "example.rb:12 BaseTool"])
      end
    end

    context "when the base and the subclass share the autoloaded namespace" do
      let(:code) do
        <<~RUBY
          module IronAdmin
            module Tools
              class BaseTool < IronAdmin::Tool
              end
              class ReportsTool < BaseTool
              end
            end
          end
        RUBY
      end

      it "accepts both classes" do
        expect(result.offenses).to be_empty
      end
    end

    context "when the before marker is outside the upgrade guide" do
      let(:code) do
        <<~RUBY
          # Before (0.7):
          class UserResource < IronAdmin::Resource
          end
        RUBY
      end

      it "reports the class" do
        expect(result.offenses).to eq(["example.rb:11 UserResource"])
      end
    end

    context "when the upgrade guide marks the block as before" do
      let(:file) { "UPGRADING.md" }
      let(:code) do
        <<~RUBY
          # Before (0.7):
          class UserResource < IronAdmin::Resource
          end
        RUBY
      end

      it "records no offense" do
        expect(result.offenses).to be_empty
      end

      it "still counts the block" do
        expect(result.checked).to eq(1)
      end
    end

    context "when a before block and an after block share a fence" do
      let(:file) { "UPGRADING.md" }
      let(:code) do
        <<~RUBY
          # Before (0.7):
          class UserResource < IronAdmin::Resource
          end
          # After
          class OrderResource < IronAdmin::Resource
          end
        RUBY
      end

      it "reports only the class after the marker" do
        expect(result.offenses).to eq(["UPGRADING.md:14 OrderResource"])
      end
    end

    context "when a class is opened twice" do
      let(:code) do
        <<~RUBY
          class UserResource < IronAdmin::Resource
          end
          class UserResource
          end
        RUBY
      end

      it "keeps the superclass from the first opening" do
        expect(result.offenses).to eq(["example.rb:10 UserResource", "example.rb:12 UserResource"])
      end
    end

    context "when a relative path contains a scope operator" do
      let(:code) do
        <<~RUBY
          module IronAdmin
            class UserResource < Resources::Resource
            end
          end
        RUBY
      end

      it "does not treat the trailing constant as the engine base" do
        expect(result.offenses).to be_empty
      end
    end

    context "when the before marker is not the first line" do
      let(:code) do
        <<~RUBY
          class UserResource < IronAdmin::Resource
          end
          # Before (0.7):
        RUBY
      end

      it "reports the class" do
        expect(result.offenses).to eq(["example.rb:10 UserResource"])
      end
    end
  end

  describe ".scan" do
    def scan_markdown(text)
      path = described_class.root.join("tmp/shipped_ruby_example.md")
      FileUtils.mkdir_p(path.dirname)
      File.write(path, text)
      described_class.scan([path.to_s])
    ensure
      FileUtils.rm_f(described_class.root.join("tmp/shipped_ruby_example.md"))
    end

    def scan_ruby(text)
      path = described_class.root.join("tmp/shipped_ruby_example.rb")
      FileUtils.mkdir_p(path.dirname)
      File.write(path, text)
      described_class.scan([path.to_s])
    ensure
      FileUtils.rm_f(described_class.root.join("tmp/shipped_ruby_example.rb"))
    end

    context "when the fence opens on line 3" do
      subject(:result) { scan_markdown("Intro\n\n```ruby\nclass UserResource < IronAdmin::Resource\nend\n```\n") }

      it "reports the class on the next line" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.md:4 UserResource"])
      end
    end

    context "when the fence is indented" do
      subject(:result) do
        scan_markdown("list:\n\n  ```ruby\n  class UserResource < IronAdmin::Resource\n  end\n  ```\n")
      end

      it "reports the class" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.md:4 UserResource"])
      end
    end

    context "when two Ruby blocks follow each other" do
      subject(:result) do
        scan_markdown(<<~MARKDOWN)
          ```ruby
          class UserResource < IronAdmin::Resource
          end
          ```
          ```ruby
          class ReportTool < IronAdmin::Tool
          end
          ```
        MARKDOWN
      end

      it "reports both classes" do
        expect(result.offenses).to eq(
          ["tmp/shipped_ruby_example.md:2 UserResource", "tmp/shipped_ruby_example.md:6 ReportTool"]
        )
      end
    end

    context "when the fence uses tildes" do
      subject(:result) { scan_markdown("~~~ruby\nclass UserResource < IronAdmin::Resource\nend\n~~~\n") }

      it "checks the block" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.md:2 UserResource"])
      end
    end

    context "when the info string is Ruby" do
      subject(:result) { scan_markdown("```Ruby\nclass UserResource < IronAdmin::Resource\nend\n```\n") }

      it "checks the block" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.md:2 UserResource"])
      end
    end

    context "when the info string carries attributes" do
      subject(:result) { scan_markdown("```ruby key=value\nclass UserResource < IronAdmin::Resource\nend\n```\n") }

      it "checks the block" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.md:2 UserResource"])
      end
    end

    context "when the fence is longer than three characters" do
      subject(:result) { scan_markdown("````ruby\nclass UserResource < IronAdmin::Resource\nend\n````\n") }

      it "checks the block" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.md:2 UserResource"])
      end
    end

    context "when the info string is rb" do
      subject(:result) { scan_markdown("```rb\nclass UserResource < IronAdmin::Resource\nend\n```\n") }

      it "checks the block" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.md:2 UserResource"])
      end
    end

    context "when the fence is in a blockquote" do
      subject(:result) { scan_markdown("> ```ruby\n> class UserResource < IronAdmin::Resource\n> end\n> ```\n") }

      it "reports the class" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.md:2 UserResource"])
      end

      it "counts the fence with its own pattern" do
        expect(result.checked + result.partial + result.skipped).to eq(result.fences)
      end
    end

    context "when the info string is a kramdown class" do
      subject(:result) { scan_markdown("```{.ruby}\nclass UserResource < IronAdmin::Resource\nend\n```\n") }

      it "checks the block" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.md:2 UserResource"])
      end
    end

    context "when an example documents a tool" do
      subject(:result) do
        scan_ruby(<<~RUBY)
          # @example
          #   class ReportTool < IronAdmin::Tool
          #   end
          class Carrier
          end
        RUBY
      end

      it "reports the tool" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.rb:2 ReportTool"])
      end
    end

    context "when an example assigns an indented ivar" do
      subject(:result) do
        scan_ruby(<<~RUBY)
          # @example
          #   @tool = nil
          #   class ReportTool < IronAdmin::Tool
          #   end
          class Carrier
          end
        RUBY
      end

      it "keeps the class that follows the ivar" do
        expect(result.offenses).to eq(["tmp/shipped_ruby_example.rb:3 ReportTool"])
      end
    end

    context "when the fence is not Ruby" do
      subject(:result) { scan_markdown("```haml\n.class\n```\n") }

      it "does not count the fence" do
        expect(result).to have_attributes(fences: 0, checked: 0, partial: 0, skipped: 0)
      end
    end

    context "when one block is only partly parsed" do
      subject(:result) do
        scan_markdown(<<~MARKDOWN)
          ```ruby
          class UserResource < IronAdmin::Resource
          end
          ```
          ```ruby
          class OrderResource < IronAdmin::Resource
            ...
          end
          ```
        MARKDOWN
      end

      it "counts every fence" do
        expect(result.checked + result.partial + result.skipped).to eq(result.fences)
      end
    end

    context "when scanning the shipped files" do
      subject(:result) { described_class.scan(described_class.files) }

      it "reports no offenses" do
        expect(result.offenses).to be_empty, result.offenses.join("\n")
      end

      it "classifies every Ruby fence and YARD example" do
        expect(result.checked + result.partial + result.skipped).to eq(result.fences + result.yard_blocks)
      end

      it "checks at least one block" do
        expect(result.checked).to be_positive
      end
    end
  end

  describe ".files" do
    subject(:files) do
      described_class.files.map { |path| Pathname.new(path).relative_path_from(described_class.root).to_s }
    end

    it "includes the tracked guides and the upgrade guide" do
      expect(files).to include("README.md", "UPGRADING.md", "docs/guides/extending.md")
    end

    it "includes the engine entry file" do
      expect(files).to include("lib/iron_admin.rb")
    end

    it "leaves out git-ignored plans" do
      expect(files.grep(%r{docs/plans/})).to be_empty
    end

    context "when git lists a path that is not a file" do
      let(:status) { instance_double(Process::Status, success?: true) }

      before do
        allow(Open3).to receive(:capture3).and_return(
          ["README.md\0docs/no-such-shipped-example.md\0", "", status]
        )
      end

      it "drops that path" do
        expect(files).to eq(["README.md"])
      end
    end

    context "with an ignored plan that defines a resource" do
      around do |example|
        directory = described_class.root.join("docs/plans")
        created_directory = !directory.exist?
        FileUtils.mkdir_p(directory)
        File.write(directory.join("zz_shipped_examples_fixture.md"), <<~MARKDOWN)
          ```ruby
          class UserResource < IronAdmin::Resource
          end
          ```
        MARKDOWN
        example.run
      ensure
        directory = described_class.root.join("docs/plans")
        FileUtils.rm_f(directory.join("zz_shipped_examples_fixture.md"))
        Dir.rmdir(directory) if created_directory && directory.exist? && Dir.empty?(directory)
      end

      it "leaves the plan out of the file list" do
        expect(files.grep(/zz_shipped_examples_fixture/)).to be_empty
      end

      it "reports no offenses for the shipped files" do
        result = described_class.scan(described_class.files)
        expect(result.offenses).to be_empty, result.offenses.join("\n")
      end

      context "when git is not available" do
        before { allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT) }

        it "includes the engine entry file" do
          expect(files).to include("lib/iron_admin.rb")
        end

        it "leaves the plan out of the file list" do
          expect(files.grep(/zz_shipped_examples_fixture/)).to be_empty
        end
      end
    end
  end

  describe ".filter_ignored" do
    subject(:kept) { described_class.filter_ignored([described_class.root.join("docs/plans/old.md").to_s]) }

    it "drops a path the root gitignore lists" do
      expect(kept).to be_empty
    end
  end
end
