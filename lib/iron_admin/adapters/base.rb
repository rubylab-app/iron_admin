# frozen_string_literal: true

module IronAdmin
  module Adapters
    # Abstract base class defining the interface every data source adapter must implement.
    #
    # IronAdmin uses this interface to introspect schemas, build queries, perform CRUD
    # operations, and search records. The default {ActiveRecord} adapter wraps Rails'
    # ActiveRecord ORM. Future adapters (Mongoid, HTTP, etc.) implement this same interface.
    #
    # @abstract Subclass and implement all methods to create a custom adapter.
    class Base
      # @return [Class] The underlying model/data class this adapter wraps
      attr_reader :model_class

      # @param model_class [Class] The model class to wrap
      def initialize(model_class)
        @model_class = model_class
      end

      # --- Schema Introspection ---

      # Returns column descriptors for the model.
      # @return [Array<#name, #type>] Objects responding to .name (String) and .type (Symbol)
      def columns
        raise NotImplementedError
      end

      # Returns column name strings.
      # @return [Array<String>]
      def column_names
        raise NotImplementedError
      end

      # Checks if a column exists.
      # @param name [Symbol, String] Column name
      # @return [Boolean]
      def has_column?(_name) # rubocop:disable Naming/PredicatePrefix
        raise NotImplementedError
      end

      # Returns enum definitions.
      # @return [Hash{String => Hash}] Enum name to values mapping
      def enums
        raise NotImplementedError
      end

      # Returns association descriptors.
      # @param kind [Symbol, nil] Filter by :belongs_to, :has_many, :has_one, :has_and_belongs_to_many
      # @return [Array<#name, #klass, #foreign_key, #polymorphic?>]
      def associations(_kind = nil)
        raise NotImplementedError
      end

      # Returns a single association descriptor by name.
      # @param name [Symbol] Association name
      # @return [#name, #klass, #foreign_key, nil]
      def association(_name)
        raise NotImplementedError
      end

      # Returns ActiveStorage attachment descriptors.
      # @return [Hash] Attachment name to reflection mapping
      def attachments
        raise NotImplementedError
      end

      # Returns ActionText rich text attribute names.
      # @return [Array<Symbol>]
      def rich_text_attributes
        raise NotImplementedError
      end

      # --- Naming ---

      # URL-friendly plural resource name (e.g., "users").
      # Uses ActiveModel::Naming (available on both AR and Mongoid models).
      # @return [String]
      def resource_name
        model_class.model_name.plural
      end

      # Human-readable model name (e.g., "User").
      # Uses ActiveModel::Naming (available on both AR and Mongoid models).
      # @return [String]
      def human_name
        model_class.model_name.human
      end

      # Database table name (or nil for non-SQL backends).
      # @return [String, nil]
      def table_name
        raise NotImplementedError
      end

      # --- Query Building ---

      # Returns a base scope/collection of all records.
      # @return [Object] A chainable query object
      def all
        raise NotImplementedError
      end

      # Finds a record by primary key.
      # @param id [Integer, String] The record ID
      # @return [Object] The record
      def find(_id)
        raise NotImplementedError
      end

      # Finds a record by attributes.
      # @param attrs [Hash] Attribute conditions
      # @return [Object, nil] The record or nil
      def find_by(_attrs)
        raise NotImplementedError
      end

      # Filters a scope by a column value.
      # @param scope [Object] The current query scope
      # @param column [Symbol] Column name
      # @param value [Object] Filter value
      # @return [Object] Filtered scope
      def filter(_scope, _column, _value)
        raise NotImplementedError
      end

      # Orders a scope by column and direction.
      # @param scope [Object] The current query scope
      # @param column [Symbol, String] Column name
      # @param direction [Symbol] :asc or :desc
      # @return [Object] Ordered scope
      def order_by(_scope, _column, _direction)
        raise NotImplementedError
      end

      # Limits a scope to N records.
      # @param scope [Object] The current query scope
      # @param max [Integer] Max records
      # @return [Object] Limited scope
      def limit(_scope, _max)
        raise NotImplementedError
      end

      # Eager loads associations on a scope.
      # @param scope [Object] The current query scope
      # @param association_names [Array<Symbol>] Associations to preload
      # @return [Object] Scope with preloading
      def preload(_scope, _association_names)
        raise NotImplementedError
      end

      # Returns distinct values for a column.
      # @param column [Symbol, String] Column name
      # @return [Array] Sorted unique values
      def distinct_values(_column)
        raise NotImplementedError
      end

      # Extracts a single column from a scope.
      # @param scope [Object] The current query scope
      # @param column [Symbol] Column name
      # @return [Array] Column values
      def pluck(_scope, _column)
        raise NotImplementedError
      end

      # Returns record count for a scope.
      # @return [Integer]
      def count(_scope = nil)
        raise NotImplementedError
      end

      # --- Search ---

      # Searches a single column with LIKE/ILIKE.
      # @param scope [Object] The current query scope
      # @param column [Symbol, String] Column to search
      # @param query [String] Search term
      # @return [Object] Filtered scope
      def search_column(_scope, _column, _query)
        raise NotImplementedError
      end

      # Searches multiple columns with OR logic.
      # @param scope [Object] The current query scope
      # @param columns [Array<Symbol>] Columns to search
      # @param query [String] Search term
      # @return [Object] Filtered scope
      def search_columns(_scope, _columns, _query)
        raise NotImplementedError
      end

      # --- CRUD ---

      # Builds a new unsaved record.
      # @param attrs [Hash] Initial attributes
      # @return [Object] New record
      def build(_attrs = {})
        raise NotImplementedError
      end

      # Persists a record.
      # @param record [Object] The record to save
      # @return [Boolean] Success
      def save(_record)
        raise NotImplementedError
      end

      # Updates a record's attributes.
      # @param record [Object] The record
      # @param attrs [Hash] New attributes
      # @return [Boolean] Success
      def update(_record, _attrs)
        raise NotImplementedError
      end

      # Destroys a record.
      # @param record [Object] The record
      # @return [void]
      def destroy!(_record)
        raise NotImplementedError
      end

      # --- Transactions ---

      # Wraps a block in a transaction.
      # @yield The block to run atomically
      # @return [Object] Block return value
      def transaction(&)
        raise NotImplementedError
      end

      # --- Scope Manipulation ---

      # Removes a WHERE condition on a specific column from a scope.
      # @param scope [Object] The current query scope
      # @param column [Symbol] Column to unscope
      # @return [Object] Scope without the column condition
      def unscope_column(_scope, _column)
        raise NotImplementedError
      end

      # --- Batch ---

      # Iterates records in memory-efficient batches.
      # @param scope [Object] The current query scope
      # @yield [record] Each record
      # @return [void]
      def find_each(_scope, &)
        raise NotImplementedError
      end

      # --- Adapter-Agnostic Interface ---

      # Returns the changes hash after a save/update.
      # @param record [Object] The record
      # @return [Hash] Changed attributes
      def record_changes(_record)
        raise NotImplementedError
      end

      # Executes a block, converting IronAdmin::Rollback to the adapter-native rollback.
      # @yield The block to run
      # @return [void]
      def wrap_rollback(&)
        raise NotImplementedError
      end

      # Returns the query builder class for operator-based filters.
      # @return [Class] A QueryBuilder subclass
      def query_builder_class
        raise NotImplementedError
      end

      # Returns the Pagy backend method name for this adapter.
      # @return [Symbol] :pagy or :pagy_mongoid
      def pagy_method
        raise NotImplementedError
      end

      # Casts a string value to a boolean.
      # Default implementation for non-AR adapters.
      # ActiveRecord overrides to use ActiveModel::Type::Boolean.
      # @param value [String] The value to cast
      # @return [Boolean]
      TRUTHY_VALUES = %w[true 1 yes].freeze

      def cast_boolean(value) # rubocop:disable Naming/PredicateMethod
        TRUTHY_VALUES.include?(value.to_s.downcase)
      end

      # Shared column descriptor for non-AR adapters.
      ColumnDescriptor = Struct.new(:name, :type) do
        def to_s
          name
        end
      end
    end
  end
end
