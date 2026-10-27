# frozen_string_literal: true

module IronAdmin
  module Resources
    # Renders a single field value on the show page.
    class ShowFieldComponent < ViewComponent::Base
      # @return [IronAdmin::Field] The field configuration
      attr_reader :field

      # @return [ActiveRecord::Base] The record
      attr_reader :record

      # @return [Object, nil] Current user
      attr_reader :current_user

      # @param field [IronAdmin::Field] Field config
      # @param record [ActiveRecord::Base] The record
      # @param current_user [Object, nil] Current user
      def initialize(field:, record:, current_user: nil)
        @field = field
        @record = record
        @current_user = current_user
      end

      def render?
        return false if field.type == :hidden

        field.visible?(@current_user)
      end

      # @api private
      # @return [IronAdmin::Configuration::Theme] Theme of the current request
      def theme
        IronAdmin.current_theme
      end

      # @api private
      # @return [String] CSS classes of the label and value row
      def row_classes
        Styles::DETAIL_ROW
      end

      # @api private
      # @return [String] Humanized field label
      def label
        field.name.to_s.humanize
      end

      # @api private
      # @return [String, nil] Formatted field value
      def value
        helpers.display_field_value(record, field)
      end
    end
  end
end
