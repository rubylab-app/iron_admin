# frozen_string_literal: true

module IronAdmin
  module Form
    # ViewComponent for rendering nested association forms inline within a parent form.
    #
    # Renders existing child records as editable rows and provides a hidden <template>
    # element that JavaScript clones to add new rows dynamically.
    class NestedFormComponent < ViewComponent::Base
      # @return [ActionView::Helpers::FormBuilder] The parent form builder
      attr_reader :form

      # @return [IronAdmin::NestedAssociation] The nested association configuration
      attr_reader :nested_association

      # @return [ActiveRecord::Base] The parent record
      attr_reader :record

      # @return [Object, nil] The current authenticated user
      attr_reader :current_user

      delegate :name, :kind, :fields, :allow_destroy, :position_field, to: :nested_association

      # @param form [ActionView::Helpers::FormBuilder] The parent form builder
      # @param nested_association [IronAdmin::NestedAssociation] Nested config
      # @param record [ActiveRecord::Base] The parent record
      # @param current_user [Object, nil] Current user for permission checks
      def initialize(form:, nested_association:, record:, current_user: nil)
        super()
        @form = form
        @nested_association = nested_association
        @record = record
        @current_user = current_user
      end

      # @return [IronAdmin::Configuration::Theme] Theme configuration
      def theme
        IronAdmin.configuration.theme
      end

      # @return [String] Human-readable title for the section header
      def title
        name.to_s.humanize
      end

      # @return [Boolean] Whether to show the "Add" button (has_many only)
      def show_add_button?
        kind == :has_many
      end

      # @return [Boolean] Whether drag-and-drop sorting is enabled
      def sortable?
        position_field.present?
      end

      # @return [String] The placeholder index used in template rows
      def template_index
        "NEW_RECORD_INDEX"
      end

      # Returns the child records for the nested association.
      #
      # For has_one, wraps the record in an array or builds a new instance.
      # For has_many with a position_field, sorts by that field ascending.
      # Returns in-memory objects so validation errors are preserved.
      #
      # @return [Array<ActiveRecord::Base>] Child records
      def child_records
        children = record.public_send(name)

        if kind == :has_one
          [children || nested_association.reflection.klass.new]
        elsif position_field
          children.to_a.sort_by { |c| c.public_send(position_field) || Float::INFINITY }
        else
          children.to_a
        end
      end
    end
  end
end
