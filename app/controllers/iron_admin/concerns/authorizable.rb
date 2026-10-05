# frozen_string_literal: true

module IronAdmin
  module Concerns
    # Applies deny_actions and the resource policy to CRUD requests.
    module Authorizable
      extend ActiveSupport::Concern

      private

      def check_action_allowed
        return if performed? || @resource_class.nil?

        head(:forbidden) unless @resource_class.crud_allowed?(crud_action_name, iron_admin_current_user)
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
