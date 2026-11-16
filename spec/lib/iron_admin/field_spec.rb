require "rails_helper"

RSpec.describe IronAdmin::Field do
  describe "#initialize" do
    it "stores name and options" do
      field = described_class.new(:email, type: :text, readonly: true)

      expect(field.name).to eq(:email)
      expect(field.type).to eq(:text)
      expect(field.readonly).to be(true)
    end

    it "defaults visible to true" do
      field = described_class.new(:name)
      expect(field.visible).to be(true)
    end

    it "defaults readonly to false" do
      field = described_class.new(:name)
      expect(field.readonly).to be(false)
    end
  end

  describe "#visible?" do
    it "returns true when visible" do
      field = described_class.new(:name, visible: true)
      expect(field.visible?(nil)).to be(true)
    end

    it "evaluates proc with user" do
      field = described_class.new(:name, visible: ->(user) { user == :admin })
      expect(field.visible?(:admin)).to be(true)
      expect(field.visible?(:user)).to be(false)
    end
  end

  describe "#secret?" do
    it "is true for a :password field" do
      expect(described_class.new(:api_token, type: :password).secret?).to be(true)
    end

    it "is true for a :hidden field" do
      expect(described_class.new(:secret_token, type: :hidden).secret?).to be(true)
    end

    it "is false for other types" do
      expect(described_class.new(:name, type: :string).secret?).to be(false)
    end
  end

  describe "#readonly?" do
    it "evaluates proc with user" do
      field = described_class.new(:name, readonly: ->(user) { user != :admin })
      expect(field.readonly?(:admin)).to be(false)
      expect(field.readonly?(:user)).to be(true)
    end
  end

  describe "#merge" do
    it "keeps visible and readonly when overriding only the label" do
      field = described_class.new(:secret_code, type: :text, visible: false, readonly: true, label: "Secret", format: "%Y")

      merged = field.merge(label: "Code")

      expect(merged).not_to equal(field)
      expect(merged.name).to eq(:secret_code)
      expect(merged.type).to eq(:text)
      expect(merged.visible).to be(false)
      expect(merged.readonly).to be(true)
      expect(merged.options).to include(label: "Code", format: "%Y")
      expect(field.visible).to be(false)
      expect(field.options[:label]).to eq("Secret")
    end

    it "lets an explicit visible override win" do
      field = described_class.new(:secret_code, type: :text, visible: false, readonly: true)

      merged = field.merge(visible: true)

      expect(merged.visible).to be(true)
      expect(merged.readonly).to be(true)
      expect(field.visible).to be(false)
    end

    it "overrides the type and keeps the other raw values" do
      field = described_class.new(:secret_code, type: :text, visible: false)

      merged = field.merge(type: :textarea)

      expect(merged.type).to eq(:textarea)
      expect(merged.visible).to be(false)
      expect(merged.name).to eq(:secret_code)
    end

    it "keeps visible and readonly procs" do
      visible_check = ->(user) { user.nil? }
      readonly_check = ->(user) { !user.nil? }
      field = described_class.new(:role, type: :text, visible: visible_check, readonly: readonly_check)

      merged = field.merge(label: "Role")

      expect(merged.visible).to equal(visible_check)
      expect(merged.readonly).to equal(readonly_check)
      expect(field.visible).to equal(visible_check)
    end
  end

  describe "#concealed_from?" do
    it "is true for a secret type" do
      field = described_class.new(:password, type: :password)

      expect(field.concealed_from?(nil)).to be(true)
    end

    it "is true when visible is false" do
      field = described_class.new(:role, type: :text, visible: false)

      expect(field.concealed_from?(nil)).to be(true)
    end

    it "is true when the visibility proc returns false for the user" do
      user = Object.new
      field = described_class.new(:role, type: :text, visible: ->(candidate) { candidate != user })

      expect(field.concealed_from?(user)).to be(true)
    end

    it "is false for a visible field" do
      field = described_class.new(:title, type: :text)

      expect(field.concealed_from?(nil)).to be(false)
    end
  end

  describe "#always_concealed?" do
    it "is true when visible is false" do
      field = described_class.new(:role, type: :text, visible: false)

      expect(field.always_concealed?).to be(true)
    end

    it "is true for a password field" do
      field = described_class.new(:password, type: :password)

      expect(field.always_concealed?).to be(true)
    end

    it "is false when visibility is a proc" do
      field = described_class.new(:role, type: :text, visible: ->(_user) { false })

      expect(field.always_concealed?).to be(false)
    end
  end
end
