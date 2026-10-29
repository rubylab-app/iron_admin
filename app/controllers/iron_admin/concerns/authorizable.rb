# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Applies deny_actions and the resource policy to CRUD requests.
    module Authorizable
      extend ActiveSupport::Concern

      private

      def check_action_allowed
        return if performed? || @resource_class.nil?

        render_forbidden unless @resource_class.crud_allowed?(crud_action_name, iron_admin_current_user)
      end

      # The index lists a bulk action only when its policy condition allows it.
      # A condition that raises (for example `user.admin?` when the current
      # user is nil) hides that action and is logged. Posting the action does
      # not use this method, so it still runs the condition.
      def listed_bulk_action?(action)
        action_authorized?(action[:name])
      rescue StandardError => e
        log_iron_admin_error(e)
        false
      end

      def crud_action_name
        case action_name.to_sym
        when :index, :show, :autocomplete then :read
        when :new, :create then :create
        when :edit, :update then :update
        when :destroy then :destroy
        end
      end
    end
  end
end
