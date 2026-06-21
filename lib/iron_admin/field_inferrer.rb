# frozen_string_literal: true

module IronAdmin
  # Infers field configurations from an ActiveRecord model's database schema.
  #
  # This is the core of IronAdmin's convention-over-configuration approach.
  # It analyzes the model's columns and associations to automatically generate
  # appropriate field configurations without requiring explicit definitions.
  #
  # The inferrer handles:
  # - Column type to field type mapping
  # - Enum column detection (generates select fields)
  # - belongs_to association detection (generates association fields)
  # - has_many/has_one shadowing (excludes columns named after associations)
  #
  # @example Basic usage
  #   fields = IronAdmin::FieldInferrer.call(User)
  #   fields.map(&:name)  #=> [:id, :name, :email, :role, :organization, :created_at, ...]
  #
  # @see IronAdmin::Field
  # @see IronAdmin::Resource.resolved_fields
  class FieldInferrer
    # Column name patterns that indicate a URL field.
    # @return [Regexp]
    URL_PATTERN = /\A(website|homepage|.*_url|.*_link)\z/

    # Column name patterns that indicate an email field.
    # @return [Regexp]
    EMAIL_PATTERN = /\A(email|.*_email)\z/

    # Maps database column types to field types.
    # @return [Hash{Symbol => Symbol}]
    TYPE_MAP = {
      string: :text,
      text: :textarea,
      integer: :number,
      float: :number,
      decimal: :number,
      boolean: :boolean,
      date: :date,
      datetime: :datetime,
      time: :time,
      json: :json,
      jsonb: :json,
    }.freeze

    # Infers fields for a model or adapter.
    #
    # @param model_or_adapter [Class, IronAdmin::Adapters::Base] An ActiveRecord model class or adapter instance
    # @return [Array<IronAdmin::Field>] Inferred field objects
    #
    # @example With a model (backward compatible)
    #   fields = IronAdmin::FieldInferrer.call(User)
    #
    # @example With an adapter (preferred)
    #   fields = IronAdmin::FieldInferrer.call(resource.adapter)
    def self.call(model_or_adapter)
      adapter = if model_or_adapter.is_a?(IronAdmin::Adapters::Base)
                  model_or_adapter
                else
                  IronAdmin::Adapters::ActiveRecord.new(model_or_adapter)
                end
      new(adapter).call
    end

    # Creates a new FieldInferrer for the given adapter.
    #
    # @param adapter [IronAdmin::Adapters::Base] An adapter instance
    def initialize(adapter)
      @adapter = adapter
      @polymorphic_map = adapter.associations(:belongs_to)
        .select(&:polymorphic?)
        .index_by { |a| a.name.to_s }
      @polymorphic_columns = @polymorphic_map.values
        .flat_map { |a| [a.foreign_type, a.foreign_key.to_s] }.to_set
      @belongs_to_map = adapter.associations(:belongs_to)
        .reject(&:polymorphic?)
        .index_by { |a| a.foreign_key.to_s }
      @shadowed_columns = adapter.associations(:has_many)
        .concat(adapter.associations(:has_one))
        .to_set { |a| a.name.to_s }
      @polymorphic_types_map = build_polymorphic_types_map
    end

    # Infers fields from the model's columns, associations, attachments,
    # and rich text attributes.
    #
    # Foreign key columns (e.g., organization_id) are replaced with their
    # corresponding belongs_to associations (e.g., organization).
    # Columns named after has_many/has_one associations are excluded.
    # ActiveStorage attachments and ActionText rich text attributes are
    # automatically detected and added as :file, :files, or :rich_text fields.
    #
    # @return [Array<IronAdmin::Field>] Inferred field objects
    def call
      fields = @adapter.columns.filter_map do |column|
        next if @shadowed_columns.include?(column.name)
        next if @polymorphic_columns.include?(column.name)

        assoc = @belongs_to_map[column.name]
        if assoc
          build_belongs_to_field(assoc)
        else
          build_field(column)
        end
      end

      fields.concat(polymorphic_fields)
      fields.concat(attachment_fields)
      fields.concat(rich_text_fields)
      fields
    end

    private

    # @api private
    # Builds a field from a database column.
    def build_field(column)
      name = column.name.to_sym

      if enum_column?(name)
        Field.new(name, type: :select, choices: @adapter.enums[name.to_s].keys)
      else
        type = infer_type(column)
        Field.new(name, type: type)
      end
    end

    # @api private
    # Infers a more specific type for string columns based on naming conventions.
    def infer_type(column)
      base_type = TYPE_MAP.fetch(column.type, :text)
      return base_type unless base_type == :text

      name = column.name
      if name.match?(URL_PATTERN)
        :url
      elsif name.match?(EMAIL_PATTERN)
        :email
      else
        :text
      end
    end

    # @api private
    # Builds fields for polymorphic belongs_to associations. Auto-infers the
    # valid target types by scanning all `ApplicationRecord` descendants for
    # `has_many :<name>, as: :<polymorphic_name>` and
    # `has_one :<name>, as: :<polymorphic_name>` declarations. Without this,
    # the form's type `<select>` is empty and the polymorphic association is
    # unusable in the admin (see #79).
    def polymorphic_fields
      @polymorphic_map.map do |name, assoc|
        Field.new(
          name.to_sym,
          type: :polymorphic_belongs_to,
          association_name: name.to_sym,
          type_column: assoc.foreign_type.to_sym,
          id_column: assoc.foreign_key.to_sym,
          types: infer_polymorphic_types(name.to_sym)
        )
      end
    end

    # @api private
    # Returns the model classes that declare `has_many` / `has_one` with
    # `as: <polymorphic_name>` — i.e. the valid targets for a polymorphic
    # `belongs_to :<polymorphic_name>`.
    #
    # @param polymorphic_name [Symbol] e.g. `:notable`
    # @return [Array<Class>]
    def infer_polymorphic_types(polymorphic_name)
      @polymorphic_types_map[polymorphic_name] || []
    end

    # @api private
    # Builds `{ polymorphic_name => [target_classes] }` once per inferrer.
    # Each adapter owns model discovery because ActiveRecord and Mongoid load
    # model classes differently.
    def build_polymorphic_types_map
      return {} if @polymorphic_map.empty?

      needed = @polymorphic_map.keys.to_set(&:to_sym)
      needed.index_with { |name| @adapter.polymorphic_inverse_classes(name) }
    end

    # @api private
    # Builds a belongs_to field from an association reflection.
    def build_belongs_to_field(association)
      Field.new(
        association.name.to_sym,
        type: :belongs_to,
        association_name: association.name.to_sym,
        association_class: association.klass,
        foreign_key: association.foreign_key.to_sym
      )
    end

    # @api private
    # Checks if a column is backed by an enum.
    def enum_column?(name)
      @adapter.enums.key?(name.to_s)
    end

    # @api private
    # Builds fields for ActiveStorage attachments (has_one_attached / has_many_attached).
    def attachment_fields
      attachments = @adapter.attachments
      return [] if attachments.empty?

      attachments.map do |name, reflection|
        type = reflection.macro == :has_one_attached ? :file : :files
        Field.new(name.to_sym, type: type)
      end
    end

    # @api private
    # Builds fields for ActionText rich text attributes (has_rich_text).
    def rich_text_fields
      rich_text_attrs = @adapter.rich_text_attributes
      return [] if rich_text_attrs.empty?

      rich_text_attrs.map do |assoc_name|
        # ActionText associations are named like "rich_text_body" — strip the prefix
        attr_name = assoc_name.to_s.delete_prefix("rich_text_").to_sym
        Field.new(attr_name, type: :rich_text)
      end
    end
  end
end
