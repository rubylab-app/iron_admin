# frozen_string_literal: true

module IronAdmin
  # Main application helper for IronAdmin views.
  module ApplicationHelper
    include Heroicon::ApplicationHelper
    include IronAdmin::ThemeHelper
    include IronAdmin::FieldDisplayHelper
    include IronAdmin::ComponentOverridesHelper

    # Methods checked when displaying a record's label.
    # @return [Array<Symbol>]
    DISPLAY_METHODS = %i[name title email label slug].freeze

    # Default max characters for text truncation on index pages.
    INDEX_TRUNCATION_LENGTH = 50

    # Field types that should be truncated on index pages.
    TRUNCATABLE_TYPES = %i[text textarea].freeze

    # Field types that show compact summaries on index pages.
    INDEX_COMPACT_TYPES = %i[key_value boolean_group].freeze

    # Maps field types to their display method names.
    # @return [Hash{Symbol => Symbol}]
    FIELD_DISPLAY_METHODS = {
      belongs_to: :display_belongs_to,
      badge: :display_badge,
      password: :display_password,
      file: :display_file,
      files: :display_files,
      rich_text: :display_rich_text,
      tags: :display_tags,
      markdown: :display_markdown,
      url: :display_url,
      email: :display_email,
      color: :display_color,
      currency: :display_currency,
      boolean: :display_boolean,
      date: :display_date,
      datetime: :display_datetime,
      polymorphic_belongs_to: :display_polymorphic_belongs_to,
      hidden: :display_hidden,
      radio: :display_radio,
      code: :display_code,
      progress_bar: :display_progress_bar,
      external_image: :display_external_image,
      boolean_group: :display_boolean_group,
      key_value: :display_key_value,
    }.freeze

    # Displays a field value with appropriate formatting.
    #
    # @param record [ActiveRecord::Base] The record
    # @param field [IronAdmin::Field] Field configuration
    # @return [String, nil] Formatted value
    def display_field_value(record, field)
      method_name = FIELD_DISPLAY_METHODS[field.type]
      if method_name
        method_name == :display_password ? display_password : send(method_name, record, field)
      elsif (custom = IronAdmin::FieldTypeRegistry.find(field.type))
        custom.render_display(record, field)
      else
        record.public_send(field.name)
      end
    end

    # Displays a field value for index pages with text truncation. Rich text
    # shows as truncated plain text, never as HTML.
    #
    # @param record [ActiveRecord::Base] The record
    # @param field [IronAdmin::Field] Field configuration
    # @return [String, nil] Formatted value (truncated for text and rich text fields)
    def display_index_field_value(record, field)
      if TRUNCATABLE_TYPES.include?(field.type)
        display_truncated_index_value(record, field)
      elsif field.type == :rich_text
        display_index_rich_text(record, field)
      elsif INDEX_COMPACT_TYPES.include?(field.type)
        display_compact_field_value(record, field)
      elsif (custom = IronAdmin::FieldTypeRegistry.find(field.type))
        custom.render_index_display(record, field)
      else
        display_field_value(record, field)
      end
    end

    # Returns a display label for a record.
    #
    # @param record [ActiveRecord::Base] The record
    # @param display_method [Symbol, Proc, nil] Custom display method
    # @return [String] Display label
    def display_record_label(record, display_method = nil)
      return display_method.call(record) if display_method.is_a?(Proc)

      return record.public_send(display_method) if display_method.is_a?(Symbol) || display_method.is_a?(String)

      DISPLAY_METHODS.each do |method|
        return record.public_send(method) if record.respond_to?(method) && record.public_send(method).present?
      end

      "#{record.class.model_name.human} ##{record.id}"
    end

    # Returns options for a filter select dropdown, evaluated when the page renders.
    #
    # A +:select+ filter offers, in order of precedence: its +options+ (an Array,
    # or a callable that takes no arguments and returns one), the enum values of
    # its column, the records of the +belongs_to+ association whose foreign key
    # it filters (labelled and scoped like the form's belongs_to select, valued by
    # the key the foreign key stores), or the column's distinct values. A foreign
    # key filter keeps the column's distinct values when the +belongs_to+ field
    # is not visible to the current user or is declared +autocomplete: true+.
    #
    # @param resource_class [Class] The resource class
    # @param filter [Hash] Filter configuration
    # @return [Array<Array(String, Object)>] [label, value] pairs for the select tag
    def filter_options_for(resource_class, filter)
      case filter[:type]
      when :select
        select_filter_options(resource_class, filter)
      when :boolean
        [[I18n.t("iron_admin.filters.true"), "true"], [I18n.t("iron_admin.filters.false"), "false"]]
      else
        []
      end
    end

    # @param options [Array, nil] Labels with values, or bare values labelled by humanizing them
    # @return [Array<Array(String, Object)>] [label, value] pairs
    def normalize_filter_options(options)
      Array(options).map do |option|
        option.is_a?(Array) ? option : [option.to_s.humanize, option]
      end
    end

    def association_resource_for(field, association_class)
      resource = field.options[:resource]
      return resource.constantize if resource.is_a?(String)
      return resource if resource

      IronAdmin::ResourceRegistry.find(association_class.model_name.plural)
    end

    private

    def select_filter_options(resource_class, filter)
      options = filter[:options]
      return normalize_filter_options(options.respond_to?(:call) ? options.call : options) if options

      column_name = filter[:name].to_s
      enum_values = resource_class.adapter.enums[column_name]
      return enum_values.keys.map { |key| [key.humanize, key] } if enum_values

      belongs_to_filter_options(resource_class, column_name) ||
        resource_class.adapter.distinct_values(column_name).map { |value| [value.to_s.humanize, value] }
    end

    # The records a belongs_to select offers on the form, when +column_name+ is
    # the foreign key of a (non-polymorphic) belongs_to association; nil otherwise.
    def belongs_to_filter_options(resource_class, column_name)
      association = resource_class.adapter.associations(:belongs_to).find do |candidate|
        !candidate.polymorphic? && candidate.foreign_key.to_s == column_name
      end
      association_class = association&.klass
      return unless association_class

      field = belongs_to_filter_field(resource_class, column_name)
      return unless labels_foreign_key_filter?(field)

      scope = association_class.all
      tenant_scope = IronAdmin.configuration.tenant_scope_block
      scope = tenant_scope.call(scope) if tenant_scope
      value_key = foreign_key_target(association)
      scope.map { |record| [display_record_label(record, field&.options&.dig(:display)), record.public_send(value_key)] }
    end

    def belongs_to_filter_field(resource_class, column_name)
      resource_class.resolved_fields.find do |candidate|
        candidate.type == :belongs_to && candidate.options[:foreign_key].to_s == column_name
      end
    end

    # Whether a foreign key filter lists the associated records. It keeps the
    # column's distinct values, as in 0.7.0, when the viewer cannot see the
    # belongs_to field, or when the field is +autocomplete+ (a table too large to list).
    def labels_foreign_key_filter?(field)
      return true unless field

      field.visible?(filter_options_viewer) && !field.options[:autocomplete]
    end

    # The current admin user, or nil where the view has no IronAdmin controller
    # behind it (such as a component or helper rendered in isolation).
    def filter_options_viewer
      iron_admin_current_user if respond_to?(:iron_admin_current_user)
    end

    # The attribute of the associated record that the foreign key stores: the
    # belongs_to +primary_key:+ option or the associated model's primary key,
    # falling back to +id+ (Mongoid, or a composite key).
    def foreign_key_target(association)
      key = association.try(:association_primary_key)
      key.is_a?(String) || key.is_a?(Symbol) ? key : :id
    end
  end
end
