require "rails_helper"

RSpec.describe IronAdmin::ApplicationHelper, type: :helper do
  before do
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::UserResource)
    IronAdmin::ResourceRegistry.register(IronAdmin::Resources::LicenseResource)
  end

  describe "#display_field_value" do
    let(:user) { create(:user, name: "John Doe", email: "john@example.com") }

    context "with regular field" do
      let(:field) { IronAdmin::Field.new(:name, type: :text) }

      it "returns field value" do
        expect(helper.display_field_value(user, field)).to eq("John Doe")
      end
    end

    context "with belongs_to field" do
      let(:license) { create(:license, user: user) }
      let(:field) { IronAdmin::Field.new(:user, type: :belongs_to, display: :email) }

      it "displays associated record" do
        result = helper.display_field_value(license, field)

        expect(result).to include("john@example.com")
      end
    end

    context "with badge field" do
      let(:license) { create(:license, user: user, status: :active) }
      let(:field) { IronAdmin::Field.new(:status, type: :badge, colors: { active: :green }) }

      it "returns badge html" do
        result = helper.display_field_value(license, field)

        expect(result).to include("Active")
        expect(result).to include("rounded-full")
      end
    end

    context "with password field" do
      let(:field) { IronAdmin::Field.new(:password_hash, type: :password) }

      it "returns masked dots" do
        result = helper.display_field_value(user, field)

        expect(result).to include("\u2022" * 8)
        expect(result).not_to include(user.name)
      end

      it "never reveals the actual value" do
        document = create(:document, password_hash: "secret123")
        result = helper.display_field_value(document, field)

        expect(result).not_to include("secret123")
      end
    end

    context "with file field" do
      let(:document) { create(:document) }
      let(:field) { IronAdmin::Field.new(:cover_image, type: :file) }

      it "returns nil when no attachment" do
        expect(helper.display_field_value(document, field)).to be_nil
      end

      it "returns filename when file is attached" do
        document.cover_image.attach(
          io: StringIO.new("test"),
          filename: "test.pdf",
          content_type: "application/pdf"
        )

        result = helper.display_field_value(document, field)

        expect(result).to include("test.pdf")
      end
    end

    context "with files field" do
      let(:document) { create(:document) }
      let(:field) { IronAdmin::Field.new(:attachments, type: :files) }

      it "returns nil when no attachments" do
        expect(helper.display_field_value(document, field)).to be_nil
      end

      it "returns filenames when files are attached" do
        document.attachments.attach(
          io: StringIO.new("doc1"),
          filename: "first.pdf",
          content_type: "application/pdf"
        )
        document.attachments.attach(
          io: StringIO.new("doc2"),
          filename: "second.pdf",
          content_type: "application/pdf"
        )

        result = helper.display_field_value(document, field)

        expect(result).to include("first.pdf")
        expect(result).to include("second.pdf")
      end
    end

    context "with hidden field" do
      let(:widget) { create(:widget, secret_token: "abc123") }
      let(:field) { IronAdmin::Field.new(:secret_token, type: :hidden) }

      it "returns nil" do
        expect(helper.display_field_value(widget, field)).to be_nil
      end
    end

    context "with radio field" do
      let(:widget) { create(:widget, status: "active") }
      let(:field) { IronAdmin::Field.new(:status, type: :radio, choices: %w[active inactive draft]) }

      it "returns humanized value" do
        result = helper.display_field_value(widget, field)

        expect(result).to include("Active")
      end

      it "returns nil when value is blank" do
        widget.status = nil
        expect(helper.display_field_value(widget, field)).to be_nil
      end
    end

    context "with code field" do
      let(:widget) { create(:widget, source_code: "puts 'hello'") }
      let(:field) { IronAdmin::Field.new(:source_code, type: :code, language: "ruby") }

      it "renders code in pre/code block" do
        result = helper.display_field_value(widget, field)

        expect(result).to include("<pre")
        expect(result).to include("<code")
        expect(result).to include("puts &#39;hello&#39;")
        expect(result).to include("font-mono")
      end

      it "includes language class" do
        result = helper.display_field_value(widget, field)

        expect(result).to include("language-ruby")
      end

      it "returns nil when value is blank" do
        widget.source_code = nil
        expect(helper.display_field_value(widget, field)).to be_nil
      end
    end

    context "with progress_bar field" do
      let(:widget) { create(:widget, completion: 75) }
      let(:field) { IronAdmin::Field.new(:completion, type: :progress_bar, color: "bg-green-500") }

      it "renders a progress bar with percentage" do
        result = helper.display_field_value(widget, field)

        expect(result).to include("75%")
        expect(result).to include("bg-green-500")
        expect(result).to include("width: 75.0%")
      end

      it "clamps percentage between 0 and 100" do
        widget.completion = 150
        result = helper.display_field_value(widget, field)

        expect(result).to include("width: 100.0%")
      end

      it "returns nil when value is nil" do
        widget.completion = nil
        expect(helper.display_field_value(widget, field)).to be_nil
      end

      it "uses default color when none specified" do
        default_field = IronAdmin::Field.new(:completion, type: :progress_bar)
        result = helper.display_field_value(widget, default_field)

        expect(result).to include("bg-indigo-600")
      end
    end

    context "with key_value field" do
      let(:widget) { create(:widget, config_json: '{"host":"localhost","port":"5432"}') }
      let(:field) { IronAdmin::Field.new(:config_json, type: :key_value) }

      it "renders a definition list with key-value pairs" do
        result = helper.display_field_value(widget, field)

        expect(result).to include("<dl")
        expect(result).to include("host")
        expect(result).to include("localhost")
        expect(result).to include("port")
        expect(result).to include("5432")
      end

      it "returns nil when value is blank" do
        widget.config_json = nil
        expect(helper.display_field_value(widget, field)).to be_nil
      end

      it "returns nil when JSON parses to empty hash" do
        widget.config_json = "{}"
        expect(helper.display_field_value(widget, field)).to be_nil
      end
    end

    context "with boolean_group field" do
      let(:widget) { create(:widget, permissions: "read,write,delete") }
      let(:field) { IronAdmin::Field.new(:permissions, type: :boolean_group, choices: %w[read write delete admin]) }

      it "renders each value as a pill badge" do
        result = helper.display_field_value(widget, field)

        expect(result).to include("Read")
        expect(result).to include("Write")
        expect(result).to include("Delete")
        expect(result).to include("rounded-full")
        expect(result).to include("bg-indigo-50")
      end

      it "does not render unselected values" do
        result = helper.display_field_value(widget, field)

        expect(result).not_to include("Admin")
      end

      it "returns nil when value results in empty array" do
        widget.permissions = ""
        expect(helper.display_field_value(widget, field)).to be_nil
      end
    end

    context "with external_image field" do
      let(:widget) { create(:widget, image_url: "https://example.com/photo.jpg") }
      let(:field) { IronAdmin::Field.new(:image_url, type: :external_image, height: "h-32") }

      it "renders an img tag with the URL" do
        result = helper.display_field_value(widget, field)

        expect(result).to include("<img")
        expect(result).to include("https://example.com/photo.jpg")
        expect(result).to include("h-32")
        expect(result).to include('loading="lazy"')
      end

      it "returns nil when URL is blank" do
        widget.image_url = nil
        expect(helper.display_field_value(widget, field)).to be_nil
      end

      it "rejects javascript: URIs for XSS prevention" do
        widget.image_url = "javascript:alert(1)"
        expect(helper.display_field_value(widget, field)).to be_nil
      end

      it "rejects case-insensitive javascript: URIs" do
        widget.image_url = "JavaScript:alert(1)"
        expect(helper.display_field_value(widget, field)).to be_nil
      end

      it "uses default height when none specified" do
        default_field = IronAdmin::Field.new(:image_url, type: :external_image)
        result = helper.display_field_value(widget, default_field)

        expect(result).to include("h-32")
      end
    end

    context "with rich_text field" do
      let(:document) { create(:document) }
      let(:field) { IronAdmin::Field.new(:content, type: :rich_text) }

      it "returns nil when content is blank" do
        expect(helper.display_field_value(document, field)).to be_nil
      end

      it "renders rich text content" do
        document.update!(content: "Hello <strong>world</strong>")

        result = helper.display_field_value(document, field)

        expect(result).to include("prose")
      end
    end
  end

  describe "#display_record_label" do
    let(:user) { create(:user, name: "John Doe", email: "john@example.com") }

    context "with proc display method" do
      it "calls the proc with record" do
        display = ->(r) { "Custom: #{r.name}" }

        expect(helper.display_record_label(user, display)).to eq("Custom: John Doe")
      end
    end

    context "with symbol display method" do
      it "calls the method on record" do
        expect(helper.display_record_label(user, :email)).to eq("john@example.com")
      end
    end

    context "with string display method" do
      it "calls the method on record" do
        expect(helper.display_record_label(user, "name")).to eq("John Doe")
      end
    end

    context "without display method" do
      it "finds first available display method" do
        expect(helper.display_record_label(user)).to eq("John Doe")
      end
    end

    context "when no display method found" do
      let(:minimal_record_class) do
        model_name = Struct.new(:human).new("Item")
        Struct.new(:id, :model_name, keyword_init: true) do
          define_method(:class) { Struct.new(:model_name).new(model_name) }
        end
      end
      let(:minimal_record) { minimal_record_class.new(id: 123) }

      it "returns fallback label" do
        expect(helper.display_record_label(minimal_record)).to eq("Item #123")
      end
    end
  end

  describe "#display_index_field_value" do
    context "with boolean_group field (compact display)" do
      let(:widget) { create(:widget, permissions: "read,write,delete") }
      let(:field) { IronAdmin::Field.new(:permissions, type: :boolean_group, choices: %w[read write delete admin]) }

      it "shows compact summary on index" do
        result = helper.display_index_field_value(widget, field)

        expect(result).to include("3 selected")
      end
    end

    context "with key_value field (compact display)" do
      let(:widget) { create(:widget, config_json: '{"host":"localhost","port":"5432"}') }
      let(:field) { IronAdmin::Field.new(:config_json, type: :key_value) }

      it "shows compact summary on index" do
        result = helper.display_index_field_value(widget, field)

        expect(result).to include("2 keys")
      end
    end
  end

  describe "#parse_hash_value (private)" do
    it "returns hash as-is" do
      expect(helper.send(:parse_hash_value, { "a" => 1 })).to eq({ "a" => 1 })
    end

    it "parses JSON object string" do
      expect(helper.send(:parse_hash_value, '{"key":"val"}')).to eq({ "key" => "val" })
    end

    it "returns empty hash for invalid JSON" do
      expect(helper.send(:parse_hash_value, "not json")).to eq({})
    end

    it "returns empty hash for nil" do
      expect(helper.send(:parse_hash_value, nil)).to eq({})
    end
  end

  describe "#parse_array_value (private)" do
    it "returns array as-is" do
      expect(helper.send(:parse_array_value, %w[a b c])).to eq(%w[a b c])
    end

    it "parses JSON array string" do
      expect(helper.send(:parse_array_value, '["read","write"]')).to eq(%w[read write])
    end

    it "splits CSV string" do
      expect(helper.send(:parse_array_value, "read, write, delete")).to eq(%w[read write delete])
    end

    it "returns empty array for nil" do
      expect(helper.send(:parse_array_value, nil)).to eq([])
    end

    it "returns empty array for non-string non-array" do
      expect(helper.send(:parse_array_value, 42)).to eq([])
    end

    it "rejects blank entries from CSV" do
      expect(helper.send(:parse_array_value, "read,,write, ")).to eq(%w[read write])
    end
  end

  describe "#filter_options_for" do
    context "with select filter on enum column" do
      let(:filter) { { name: :status, type: :select } }

      it "returns enum options" do
        options = helper.filter_options_for(IronAdmin::Resources::LicenseResource, filter)

        expect(options).to include(%w[Active active])
        expect(options).to include(%w[Expired expired])
      end
    end

    context "with select filter with custom options" do
      let(:filter) { { name: :role, type: :select, options: [%w[Admin admin], %w[User user]] } }

      it "returns custom options" do
        options = helper.filter_options_for(IronAdmin::Resources::UserResource, filter)

        expect(options).to eq([%w[Admin admin], %w[User user]])
      end
    end

    context "with select filter with scalar string options" do
      let(:filter) { { name: :role, type: :select, options: %w[enterprise standard] } }

      it "normalizes options into label-value pairs" do
        options = helper.filter_options_for(IronAdmin::Resources::UserResource, filter)

        expect(options).to eq([%w[Enterprise enterprise], %w[Standard standard]])
      end
    end

    context "with select filter on regular column" do
      before do
        create(:user, role: "admin")
        create(:user, role: "user")
      end

      let(:filter) { { name: :role, type: :select } }

      it "returns distinct values" do
        options = helper.filter_options_for(IronAdmin::Resources::UserResource, filter)

        expect(options).to include(%w[Admin admin])
        expect(options).to include(%w[User user])
      end
    end

    context "with boolean filter" do
      let(:filter) { { name: :active, type: :boolean } }

      it "returns yes/no options" do
        options = helper.filter_options_for(IronAdmin::Resources::UserResource, filter)

        expect(options).to eq([%w[Yes true], %w[No false]])
      end
    end

    context "with unknown filter type" do
      let(:filter) { { name: :name, type: :unknown } }

      it "returns empty array" do
        expect(helper.filter_options_for(IronAdmin::Resources::UserResource, filter)).to eq([])
      end
    end
  end

  describe "#badge_color_classes" do
    it "returns color classes for known color" do
      result = helper.send(:badge_color_classes, :green)

      expect(result).to include("bg-green")
    end

    it "returns gray classes for unknown color" do
      result = helper.send(:badge_color_classes, :nonexistent)

      expect(result).to include("bg-gray")
    end
  end
end
