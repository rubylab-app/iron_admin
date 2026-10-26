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
end
