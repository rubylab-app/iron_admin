# frozen_string_literal: true

module IronAdmin
  # Base error class for all IronAdmin errors.
  class Error < StandardError; end

  # Raised when a record cannot be found by ID.
  # Adapter-agnostic replacement for ActiveRecord::RecordNotFound.
  class RecordNotFound < Error; end

  # Raised inside a transaction block to trigger a rollback.
  # Adapter-agnostic replacement for ActiveRecord::Rollback.
  class Rollback < Error; end
end
