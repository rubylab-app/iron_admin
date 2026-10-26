# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Provides action execution with arity-based dispatch for form params.
    #
    # Supports both legacy 1-arg blocks (backward compat) and 2-arg blocks
    # that receive collected action_form params as the second argument.
    module ActionExecutable
      extend ActiveSupport::Concern

      private

      # Dispatches an action block with the correct number of arguments.
      #
      # 1-arg blocks receive only the subject (record or records).
      # 2-arg blocks receive the subject and collected form params.
      #
      # @param block [Proc] The action block
      # @param subject [Object] The record or records
      # @param collected_params [Hash] Collected form params
      # @return [Object] The block's return value
      def call_action_block(block, subject, collected_params)
        if block.arity.in?([1, -1])
          block.call(subject)
        else
          block.call(subject, collected_params)
        end
      end

      # Runs the block in the adapter's transaction. A flag reports the
      # outcome, since adapters whose transaction just yields return nothing.
      #
      # @yield The action; raises IronAdmin::Rollback to roll back
      # @return [Boolean] false when the block rolled back
      def action_transaction_completed?
        completed = false
        adapter = @resource_class.adapter
        adapter.transaction do
          adapter.wrap_rollback do
            yield
            completed = true
          end
        end
        completed
      end

      # A notice when the member action completed, otherwise an alert with
      # the record's errors, if any.
      #
      # @param completed [Boolean]
      # @param record [Object] The record the action ran on
      # @return [Hash] +{ notice: String }+ or +{ alert: String }+
      def member_action_flash(completed, record)
        return { notice: I18n.t("iron_admin.resources.action.success") } if completed

        errors = record.try(:errors).try(:full_messages).presence
        return { alert: I18n.t("iron_admin.resources.action.not_completed") } unless errors

        { alert: I18n.t("iron_admin.resources.action.not_completed_with_errors", errors: errors.to_sentence) }
      end

      # Extracts and permits action form params based on declared form_fields.
      #
      # @param action [Hash] The action definition with :form_fields key
      # @return [Hash] Permitted params with symbolized keys, or empty hash
      def action_form_params(action)
        fields = action[:form_fields] || []
        return {} if fields.empty?

        permitted_keys = fields.map(&:name)
        params.fetch(:action_form, {}).permit(*permitted_keys).to_h.symbolize_keys
      end
    end
  end
end
