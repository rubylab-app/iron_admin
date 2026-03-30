# frozen_string_literal: true

module IronAdmin
  # Base class for defining admin resources in IronAdmin.
  #
  # Resources are the primary way to configure how models appear in the admin panel.
  # Each resource corresponds to a model and provides a DSL for customizing fields,
  # filters, actions, search, and authorization.
  #
  # @example Basic resource definition
  #   class UserResource < IronAdmin::Resource
  #     field :email, readonly: true
  #     field :role, type: :select, options: %w[admin user guest]
  #     field :password_digest, visible: false
  #
  #     searchable :name, :email
  #     index_fields :id, :name, :email, :role, :created_at
  #
  #     filter :role, type: :select, options: %w[admin user guest]
  #
  #     action :suspend, icon: "pause", confirm: true do |record|
  #       record.update!(suspended_at: Time.current)
  #     end
  #
  #     policy do
  #       allow :read
  #       allow :update, if: ->(user) { user.admin? }
  #       deny :delete
  #     end
  #   end
  #
  # @example Resource with associations
  #   class OrderResource < IronAdmin::Resource
  #     belongs_to :customer
  #     has_many :line_items, resource: LineItemResource
  #
  #     preload :customer, :line_items
  #   end
  #
  # @see IronAdmin::Field For field configuration options
  # @see IronAdmin::Policy For authorization options
  class Resource
    class_attribute :field_overrides, default: {}
    class_attribute :_searchable_columns, default: nil
    class_attribute :_unsearchable_columns, default: []
    class_attribute :defined_filters, default: []
    class_attribute :defined_scopes, default: []
    class_attribute :defined_actions, default: []
    class_attribute :defined_bulk_actions, default: []
    class_attribute :index_field_names, default: nil
    class_attribute :form_field_names, default: nil
    class_attribute :menu_options, default: {}
    class_attribute :component_overrides, default: {}
    class_attribute :_policy_block, default: nil
    class_attribute :export_formats, default: %i[csv json]
    class_attribute :export_field_names, default: nil
    class_attribute :denied_crud_actions, default: []
    class_attribute :defined_associations, default: {}
    class_attribute :model_class_override, default: nil
    class_attribute :adapter_class, default: IronAdmin::Adapters::ActiveRecord
    class_attribute :_soft_delete_scopes, default: []

    class << self
      # @api private
      # Automatically registers subclasses with the ResourceRegistry.
      def inherited(subclass)
        super
        return if subclass.name.nil?

        begin
          IronAdmin::ResourceRegistry.register(subclass)
        rescue NameError
        end
      end

      # Returns the adapter instance for this resource's model.
      #
      # The adapter provides a uniform interface for schema introspection,
      # query building, and CRUD operations regardless of the underlying
      # data source (ActiveRecord, Mongoid, HTTP, etc.).
      #
      # @return [IronAdmin::Adapters::Base] The adapter instance
      def adapter
        @adapter ||= adapter_class.new(model)
      end

      # Returns the ActiveRecord model class for this resource.
      #
      # By default, infers the model from the resource class name
      # (e.g., UserResource -> User).
      #
      # @return [Class] The ActiveRecord model class
      #
      # @example Override with model_class_override
      #   class LegacyUserResource < IronAdmin::Resource
      #     self.model_class_override = OldUser
      #   end
      def model
        return model_class_override if model_class_override

        name.sub(/Resource\z/, "").sub(/\AIronAdmin::Resources::/, "").constantize
      end

      # Configures display and behavior options for a field.
      #
      # Fields are automatically inferred from the model's database schema.
      # Use this method to override the inferred configuration.
      #
      # @param name [Symbol] The field name (must match a database column or association)
      # @param options [Hash] Configuration options for the field
      # @option options [Symbol] :type Override the inferred field type
      #   (:string, :text, :integer, :boolean, :date, :datetime, :select, :belongs_to)
      # @option options [Boolean, Proc] :visible Whether the field is visible
      #   (Proc receives the current user)
      # @option options [Boolean, Proc] :readonly Whether the field is read-only
      #   (Proc receives the current user)
      # @option options [String] :label Custom label for the field
      # @option options [Array] :options For select fields, the available choices
      # @option options [Boolean] :autocomplete For belongs_to, force autocomplete mode
      # @option options [Proc] :format Custom formatting proc for display
      #
      # @example Basic field configuration
      #   field :email, readonly: true
      #   field :role, type: :select, options: %w[admin user guest]
      #
      # @example Conditional visibility
      #   field :salary, visible: ->(user) { user.admin? || user.hr? }
      #
      # @example Custom formatting
      #   field :price, format: ->(value) { number_to_currency(value) }
      #
      # @return [void]
      def field(name, **options)
        self.field_overrides = field_overrides.merge(name => options)
      end

      # Specifies which columns are searchable via the search box.
      #
      # By default, all string and text columns are searchable (except
      # those ending in _digest). Use this to explicitly define searchable columns.
      #
      # @param columns [Array<Symbol>] Column names to make searchable
      #
      # @example
      #   searchable :name, :email, :description
      #
      # @return [void]
      def searchable(*columns)
        self._searchable_columns = columns
      end

      # Excludes columns from the default searchable set.
      #
      # Use this when you want to keep most auto-inferred columns
      # but exclude specific ones.
      #
      # @param columns [Array<Symbol>] Column names to exclude from search
      #
      # @example
      #   unsearchable :internal_notes, :encrypted_data
      #
      # @return [void]
      def unsearchable(*columns)
        self._unsearchable_columns = _unsearchable_columns + columns.map(&:to_sym)
      end

      # Returns the list of searchable column names.
      #
      # If {.searchable} was called, returns those columns.
      # Otherwise, returns all string/text columns except those ending in _digest
      # and those excluded via {.unsearchable}.
      #
      # @return [Array<Symbol>] Searchable column names
      def searchable_columns
        return _searchable_columns if _searchable_columns

        adapter.columns.select { |c| c.type.in?(%i[string text]) }
          .map { |c| c.name.to_sym }
          .reject { |name| name.to_s.end_with?("_digest") }
          .reject { |name| _unsearchable_columns.include?(name) }
      end

      # Defines a filter for the resource index page.
      #
      # Filters appear in the filter bar and allow users to narrow
      # down the displayed records.
      #
      # @param name [Symbol] The column or attribute to filter by
      # @param options [Hash] Configuration options
      # @option options [Symbol] :type The filter type (:select, :date_range, :boolean)
      # @option options [Array] :options For select filters, the available choices
      # @option options [String] :label Custom label for the filter
      #
      # @example Select filter
      #   filter :status, type: :select, options: %w[pending active completed]
      #
      # @example Date range filter
      #   filter :created_at, type: :date_range
      #
      # @note Enum columns automatically get select filters generated.
      #   Use {.remove_filter} to remove auto-generated filters.
      #
      # @return [void]
      def filter(name, **options)
        self.defined_filters = defined_filters + [{ name: name, **options }]
      end

      # Removes a filter (useful for removing auto-generated enum filters).
      #
      # @param name [Symbol] The filter name to remove
      #
      # @example Remove auto-generated status filter
      #   remove_filter :status
      #
      # @return [void]
      def remove_filter(name)
        self.defined_filters = defined_filters.reject { |f| f[:name] == name }
      end

      # @api private
      # Returns filters automatically inferred from enum columns and database column types.
      #
      # String/text columns auto-infer as :string filters.
      # Integer/float/decimal columns auto-infer as :number filters.
      # Enum columns auto-infer as :select filters.
      #
      # @return [Array<Hash>] Auto-generated filter configurations
      def auto_inferred_filters
        enum_filters = enum_auto_filters
        enum_filters + infer_column_filters(enum_filters)
      end

      # Returns all filters (auto-inferred + manually defined).
      #
      # @return [Array<Hash>] All filter configurations
      def all_filters
        auto_inferred_filters + defined_filters
      end

      # Returns all scopes with user-defined scopes first, soft delete scopes last.
      #
      # @return [Array<Hash>] Combined scope definitions
      def all_scopes
        defined_scopes + _soft_delete_scopes
      end

      # Defines a named scope for filtering records on the index page.
      #
      # Scopes appear as tabs above the data table and allow quick
      # filtering to predefined subsets of records.
      #
      # @param name [Symbol] The scope name (displayed as tab label)
      # @param lambda [Proc] A lambda that receives and returns an ActiveRecord::Relation
      # @param default [Boolean] Whether this scope is selected by default
      #
      # @example Basic scopes
      #   scope :active, -> { where(active: true) }
      #   scope :recent, -> { where("created_at > ?", 1.week.ago) }, default: true
      #
      # @example Scope with complex query
      #   scope :high_value, -> { where("total > ?", 1000).order(total: :desc) }
      #
      # @return [void]
      def scope(name, lambda, default: false)
        self.defined_scopes = defined_scopes + [{ name: name, scope: lambda, default: default }]
      end

      # Defines a custom action for individual records.
      #
      # Actions appear in the actions dropdown on show and index pages.
      # They execute arbitrary code when triggered.
      #
      # @param name [Symbol] The action name
      # @param options [Hash] Configuration options
      # @option options [String] :icon Heroicon name (e.g., "lock-closed", "trash")
      # @option options [Boolean] :confirm Whether to show a confirmation dialog
      # @option options [String] :confirm_message Custom confirmation message
      # @option options [Symbol] :method HTTP method (:post, :patch, :delete)
      # @yield [record] Block executed when action is triggered
      # @yieldparam record [ActiveRecord::Base] The record to act upon
      #
      # @example Simple action
      #   action :publish do |record|
      #     record.update!(published_at: Time.current)
      #   end
      #
      # @example Action with confirmation
      #   action :suspend, icon: "pause", confirm: true do |record|
      #     record.update!(suspended_at: Time.current)
      #   end
      #
      # @return [void]
      def action(name, **options, &block)
        self.defined_actions = defined_actions + [{ name: name, block: block, **options }]
      end

      # Defines a bulk action for multiple selected records.
      #
      # Bulk actions appear in the bulk actions dropdown when records
      # are selected on the index page. All records are processed in
      # a single database transaction.
      #
      # @param name [Symbol] The action name
      # @param options [Hash] Configuration options
      # @option options [String] :icon Heroicon name
      # @option options [Boolean] :confirm Whether to show a confirmation dialog
      # @yield [records] Block executed when action is triggered
      # @yieldparam records [ActiveRecord::Relation] The selected records
      # @yieldreturn [Boolean, nil] Return false to rollback the transaction
      #
      # @example Bulk deactivate
      #   bulk_action :deactivate do |records|
      #     records.update_all(active: false)
      #   end
      #
      # @example Bulk action with rollback on failure
      #   bulk_action :process do |records|
      #     return false unless ExternalService.process(records)
      #   end
      #
      # @return [void]
      def bulk_action(name, **options, &block)
        self.defined_bulk_actions = defined_bulk_actions + [{ name: name, block: block, **options }]
      end

      # Specifies which fields appear on the index (list) page.
      #
      # By default, shows the first 6 fields. Use this to customize
      # which fields appear and in what order.
      #
      # @param fields [Array<Symbol>] Field names to display
      #
      # @example
      #   index_fields :id, :name, :email, :status, :created_at
      #
      # @return [void]
      def index_fields(*fields)
        self.index_field_names = fields
      end

      # Specifies which fields appear on create/edit forms.
      #
      # By default, shows all editable fields. Use this to customize
      # which fields appear and in what order.
      #
      # @param fields [Array<Symbol>] Field names to display
      #
      # @example
      #   form_fields :name, :email, :role, :bio
      #
      # @return [void]
      def form_fields(*fields)
        self.form_field_names = fields
      end

      # Configures the sidebar menu appearance for this resource.
      #
      # @param options [Hash] Menu configuration options
      # @option options [String] :icon Heroicon name for the menu item
      # @option options [String] :label Custom label (defaults to pluralized model name)
      # @option options [Integer] :priority Sort order (lower = higher in menu)
      # @option options [String] :section Group name for menu sections
      #
      # @example
      #   menu icon: "users", label: "Team Members", priority: 10
      #
      # @return [void]
      def menu(**options)
        self.menu_options = options
      end

      # Registers a custom component class to override default rendering.
      #
      # @param name [Symbol] The component type to override
      #   (:index, :show, :form, :row, etc.)
      # @param klass [Class] The component class to use
      #
      # @example Override the index table component
      #   component :index, CustomUserIndexComponent
      #
      # @return [void]
      def component(name, klass)
        self.component_overrides = component_overrides.merge(name => klass)
      end

      # Defines the authorization policy for this resource.
      #
      # Policies control which actions users can perform. Without a policy,
      # all actions are allowed by default.
      #
      # @yield Block that configures the policy using the Policy DSL
      #
      # @example Basic policy
      #   policy do
      #     allow :read
      #     allow :create, :update, if: ->(user) { user.admin? }
      #     deny :delete
      #   end
      #
      # @see IronAdmin::Policy For full policy DSL documentation
      #
      # @return [void]
      def policy(&block)
        self._policy_block = block
      end

      # Returns the Policy instance for this resource.
      #
      # @return [IronAdmin::Policy, nil] The policy, or nil if none defined
      def resource_policy
        return @resource_policy if defined?(@resource_policy)

        @resource_policy = Policy.new(&_policy_block) if _policy_block
      end

      # @api private
      # Clears the cached policy (used in testing).
      def reset_resource_policy!
        remove_instance_variable(:@resource_policy) if defined?(@resource_policy)
      end

      # Disables specific CRUD actions for this resource.
      #
      # This is a simpler alternative to policies when you want to
      # completely disable actions for all users.
      #
      # @param actions [Array<Symbol>] Actions to disable
      #   (:create, :update, :delete, :read)
      #
      # @example Read-only resource
      #   deny_actions :create, :update, :delete
      #
      # @return [void]
      def deny_actions(*actions)
        self.denied_crud_actions = actions.map(&:to_sym)
      end

      # Checks if a CRUD action is allowed (not denied via deny_actions).
      #
      # @param action_name [Symbol] The action to check
      # @return [Boolean] True if the action is allowed
      def action_allowed?(action_name)
        denied_crud_actions.exclude?(action_name.to_sym)
      end

      # Configures which export formats are available.
      #
      # By default, both :csv and :json exports are enabled.
      # Call with no arguments to disable all exports.
      #
      # @param formats [Array<Symbol>] Enabled export formats (:csv, :json)
      #
      # @example Enable only CSV
      #   exports :csv
      #
      # @example Disable all exports
      #   exports
      #
      # @return [void]
      def exports(*formats)
        self.export_formats = formats
      end

      # Specifies which fields appear in exports.
      #
      # By default, exports include all visible fields.
      #
      # @param fields [Array<Symbol>] Field names to export
      #
      # @example
      #   export_fields :id, :name, :email, :created_at
      #
      # @return [void]
      def export_fields(*fields)
        self.export_field_names = fields
      end

      # Declares a belongs_to association for this resource.
      #
      # Used to configure how the association is displayed and
      # which resource to link to.
      #
      # @param name [Symbol] The association name
      # @param options [Hash] Configuration options
      # @option options [Boolean] :autocomplete Force autocomplete mode for large associations
      # @option options [Class] :resource The associated resource class
      #
      # @example
      #   belongs_to :organization
      #   belongs_to :author, autocomplete: true
      #
      # @return [void]
      def belongs_to(name, **options)
        self.defined_associations = defined_associations.merge(name => { kind: :belongs_to, **options })
      end

      # Declares a has_many association for this resource.
      #
      # Has_many associations appear as related lists on the show page.
      #
      # @param name [Symbol] The association name
      # @param options [Hash] Configuration options
      # @option options [Class] :resource The associated resource class
      # @option options [Array<Symbol>] :fields Fields to display in the related list
      #
      # @example
      #   has_many :orders
      #   has_many :comments, fields: [:id, :body, :created_at]
      #
      # @return [void]
      def has_many(name, **options)
        self.defined_associations = defined_associations.merge(name => { kind: :has_many, **options })
      end

      # Declares a has_one association for this resource.
      #
      # @param name [Symbol] The association name
      # @param options [Hash] Configuration options
      # @option options [Class] :resource The associated resource class
      #
      # @example
      #   has_one :profile
      #
      # @return [void]
      def has_one(name, **options)
        self.defined_associations = defined_associations.merge(name => { kind: :has_one, **options })
      end

      # Declares a has_and_belongs_to_many association for this resource.
      #
      # HABTM associations appear as multi-select checkboxes on forms and
      # as badge lists on show pages.
      #
      # @param name [Symbol] The association name
      # @param options [Hash] Configuration options
      # @option options [Class] :resource The associated resource class
      #
      # @example
      #   has_and_belongs_to_many :tags
      #
      # @return [void]
      def has_and_belongs_to_many(name, **options) # rubocop:disable Naming/PredicatePrefix
        self.defined_associations = defined_associations.merge(name => { kind: :has_and_belongs_to_many, **options })
      end

      # Returns Field objects for all fields, with overrides applied.
      #
      # Merges auto-inferred fields from the database schema with
      # any customizations made via {.field} and association declarations.
      #
      # @return [Array<IronAdmin::Field>] Configured field objects
      def resolved_fields
        inferred = FieldInferrer.call(adapter)

        inferred.map do |field|
          overrides = field_overrides[field.name] || {}
          assoc_overrides = defined_associations[field.name] || {}
          merged = assoc_overrides.except(:kind).merge(overrides)

          if merged.any?
            Field.new(field.name, type: field.type, **field.options, **merged)
          else
            field
          end
        end
      end

      # Returns associations to preload for index/show queries.
      #
      # By default, preloads all belongs_to associations to avoid N+1 queries.
      # Use {.preload} to customize.
      #
      # @return [Array<Symbol>] Association names to preload
      def preload_associations
        @preload_associations || infer_preload_associations
      end

      # Specifies which associations to preload on queries.
      #
      # Use this to optimize queries by eager loading associations.
      #
      # @param associations [Array<Symbol>] Association names to preload
      #
      # @example
      #   preload :customer, :line_items, :shipping_address
      #
      # @return [void]
      def preload(*associations)
        @preload_associations = associations
      end

      # Returns has_many association configurations for related lists.
      #
      # @return [Array<Hash>] Association configs with :name, :reflection, :resource keys
      def has_many_associations
        defined_associations.filter_map do |assoc_name, config|
          next unless config[:kind] == :has_many

          reflection = adapter.association(assoc_name)
          next unless reflection

          resource = ResourceRegistry.find(reflection.klass.model_name.plural)
          next unless resource

          { name: assoc_name, reflection: reflection, resource: resource, **config.except(:kind) }
        end
      end

      # Returns has_one association configurations for display on show pages.
      #
      # @return [Array<Hash>] Association configs with :name, :reflection, :resource keys
      def has_one_associations # rubocop:disable Naming/PredicatePrefix
        defined_associations.filter_map do |assoc_name, config|
          next unless config[:kind] == :has_one

          reflection = adapter.association(assoc_name)
          next unless reflection

          resource = ResourceRegistry.find(reflection.klass.model_name.plural)
          next unless resource

          { name: assoc_name, reflection: reflection, resource: resource, **config.except(:kind) }
        end
      end

      # Returns HABTM association configurations for multi-select on forms and badge display.
      #
      # @return [Array<Hash>] Association configs with :name, :reflection, :resource keys
      def habtm_associations
        defined_associations.filter_map do |assoc_name, config|
          next unless config[:kind] == :has_and_belongs_to_many

          reflection = adapter.association(assoc_name)
          next unless reflection

          resource = ResourceRegistry.find(reflection.klass.model_name.plural)

          { name: assoc_name, reflection: reflection, resource: resource, **config.except(:kind) }
        end
      end

      # Returns the URL-friendly resource name (pluralized model name).
      #
      # @return [String] The resource name (e.g., "users", "orders")
      delegate :resource_name, to: :adapter

      # Returns the human-readable label for this resource.
      #
      # @return [String] Pluralized, humanized model name
      def label
        adapter.human_name.pluralize
      end

      # Returns the attribute used to display individual records.
      #
      # Checks for common display methods (name, title, email, etc.)
      # and falls back to :id if none found.
      #
      # @return [Symbol] The display attribute name
      def display_attribute
        ApplicationHelper::DISPLAY_METHODS.find do |method|
          adapter.has_column?(method)
        end || :id
      end

      # Checks if the model supports soft delete.
      #
      # @return [Boolean] True if model has a deleted_at column
      def soft_delete?
        adapter.has_column?(soft_delete_column)
      end

      # Returns the column name used for soft delete tracking.
      #
      # @return [String] Column name (default: "deleted_at")
      def soft_delete_column
        "deleted_at"
      end

      # Registers soft delete scopes and restore action if model supports it.
      #
      # Automatically called during resource initialization when
      # a deleted_at column is detected.
      #
      # Registers:
      # - :with_deleted scope - Show all records including soft-deleted
      # - :only_deleted scope - Show only soft-deleted records
      # - :restore action - Restore a soft-deleted record
      #
      # @return [void]
      def register_soft_delete_features
        return unless soft_delete?

        # Capture the column name for use in lambdas
        column = soft_delete_column
        column_sym = column.to_sym

        # Store soft delete scopes separately so they always appear after user-defined scopes
        self._soft_delete_scopes = [
          { name: :with_deleted, scope: -> { unscope(where: column_sym) }, default: false },
          { name: :only_deleted, scope: -> { unscope(where: column_sym).where.not(column => nil) }, default: false },
        ]

        # Register restore action (only visible on soft-deleted records)
        action :restore, icon: "arrow-path", condition: ->(record) { record.public_send(column).present? } do |record|
          record.update(column => nil)
        end
      rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
        nil
      end

      SKIP_FILTER_COLUMNS = %w[id created_at updated_at].freeze
      private_constant :SKIP_FILTER_COLUMNS

      private

      def enum_auto_filters
        adapter.enums.map do |name, values|
          {
            name: name.to_sym,
            type: :select,
            options: values.keys,
          }
        end
      end

      def infer_column_filters(enum_filters)
        already_defined = (defined_filters + enum_filters).map { |f| f[:name].to_sym }

        adapter.columns.filter_map do |col|
          next if already_defined.include?(col.name.to_sym)
          next if SKIP_FILTER_COLUMNS.include?(col.name)

          infer_filter_from_column(col)
        end
      end

      def infer_filter_from_column(col)
        case col.type
        when :string, :text
          { name: col.name.to_sym, type: :string, label: col.name.humanize }
        when :integer, :float, :decimal
          return nil if col.name.end_with?("_id")

          { name: col.name.to_sym, type: :number, label: col.name.humanize }
        end
      end

      # @api private
      def infer_preload_associations
        resolved_fields.select { |f| f.type == :belongs_to }.map(&:name)
      end
    end
  end
end
