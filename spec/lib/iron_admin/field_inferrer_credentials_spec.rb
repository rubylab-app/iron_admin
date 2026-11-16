# frozen_string_literal: true

require "rails_helper"

RSpec.describe IronAdmin::FieldInferrer do
  describe "CREDENTIAL_COLUMNS" do
    it "lists the credential names in a frozen array and an exact pattern" do
      expect(described_class::CREDENTIAL_COLUMNS).to eq(
        %w[
          encrypted_password
          password_digest
          reset_password_token
          confirmation_token
          unlock_token
          remember_token
          invitation_token
          authentication_token
          otp_secret
          encrypted_otp_secret
          encrypted_otp_secret_iv
          encrypted_otp_secret_salt
          otp_backup_codes
        ]
      )
      expect(described_class::CREDENTIAL_COLUMNS).to be_frozen
      expect(described_class::CREDENTIAL_PATTERN).to eq(/\A\w+_password_digest\z/)
    end
  end

  describe ".credential_column?" do
    it "is true for listed names and a custom password digest" do
      expect(described_class.credential_column?("encrypted_password")).to be(true)
      expect(described_class.credential_column?(:password_digest)).to be(true)
      expect(described_class.credential_column?("otp_backup_codes")).to be(true)
      expect(described_class.credential_column?("recovery_password_digest")).to be(true)
    end

    it "is false for ordinary columns that merely look similar" do
      expect(described_class.credential_column?("variation_digest")).to be(false)
      expect(described_class.credential_column?("token_count")).to be(false)
      expect(described_class.credential_column?("api_token_expires_at")).to be(false)
      expect(described_class.credential_column?("password_hash")).to be(false)
    end
  end

  describe ".call" do
    subject(:fields) do
      described_class.call(IronAdmin::Adapters::ActiveRecord.new(Account)).index_by(&:name)
    end

    it "hides encrypted_password and password_digest and keeps them readonly" do
      expect(fields.fetch(:encrypted_password).visible?(nil)).to be(false)
      expect(fields.fetch(:encrypted_password).readonly?(nil)).to be(true)
      expect(fields.fetch(:password_digest).visible?(nil)).to be(false)
      expect(fields.fetch(:password_digest).readonly?(nil)).to be(true)
    end

    it "hides reset_password_token and otp_secret and keeps them readonly" do
      expect(fields.fetch(:reset_password_token).visible?(nil)).to be(false)
      expect(fields.fetch(:reset_password_token).readonly?(nil)).to be(true)
      expect(fields.fetch(:otp_secret).visible?(nil)).to be(false)
      expect(fields.fetch(:otp_secret).readonly?(nil)).to be(true)
    end

    it "keeps the inferred text type on credential columns" do
      expect(fields.fetch(:encrypted_password).type).to eq(:text)
      expect(fields.fetch(:reset_password_token).type).to eq(:text)
      expect(fields.fetch(:password_digest).type).to eq(:text)
      expect(fields.fetch(:otp_secret).type).to eq(:text)
    end

    it "leaves name, email, and variation_digest visible" do
      expect(fields.fetch(:name).visible?(nil)).to be(true)
      expect(fields.fetch(:email).visible?(nil)).to be(true)
      expect(fields.fetch(:email).type).to eq(:email)
      expect(fields.fetch(:variation_digest).visible?(nil)).to be(true)
    end
  end
end
