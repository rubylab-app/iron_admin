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
