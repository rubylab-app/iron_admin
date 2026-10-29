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
    include Concerns::Nestable
    include Concerns::SoftDeletable
    include Concerns::Importable
    include Concerns::LiveUpdatable
    include Concerns::ComponentOverridable
    include Concerns::FilterDefinable

    class_attribute :field_overrides, default: {}
    class_attribute :_searchable_columns, default: nil
    class_attribute :_unsearchable_columns, default: []
    class_attribute :defined_scopes, default: []
    class_attribute :defined_actions, default: []
    class_attribute :defined_bulk_actions, default: []
    class_attribute :index_field_names, default: nil
    class_attribute :form_field_names, default: nil
    class_attribute :menu_options, default: {}
    class_attribute :_policy_block, default: nil
    class_attribute :export_formats, default: %i[csv json]
    class_attribute :export_field_names, default: nil
    class_attribute :denied_crud_actions, default: []
    class_attribute :defined_associations, default: {}

    # Model this resource manages when the class name does not name it.
    #
    # The URL segment is {.resource_name}. An override of a different model
    # comes from the class path under `IronAdmin::Resources`
    # (`AutoNoteResource` is `auto_notes`, `Shop::NoteResource` is
    # `shop_notes`), not from the model's plural. An override of the model the
    # class name already implies keeps that model's plural. Define
    # `self.resource_name` to choose another name. There is no writer.
    #
    # @return [Class, nil]
    class_attribute :model_class_override, default: nil
    class_attribute :adapter_class, default: :active_record
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
      # Defensively re-resolves when the cached `@adapter` doesn't match
      # the currently configured `adapter_class`. This catches the case
      # where the eager `Resource.inherited` flow memoized an
      # `Adapters::ActiveRecord` built before the subclass body's
      # `self.adapter_class = :mongoid` (or `:http`) took effect.
      #
      # @return [IronAdmin::Adapters::Base] The adapter instance
      def adapter
        wanted = resolve_adapter_class
        @adapter = nil if @adapter && !@adapter.instance_of?(wanted)
        @adapter ||= wanted.new(model)
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
      #
      # @example HTTP adapter — no Ruby model required
      #   class ProductResource < IronAdmin::Resource
      #     self.adapter_class = :http
      #     # `model` returns `Adapters::Http::ModelProxy.new(self)` — no
      #     # `Product` constant required; fields come from the API
      #     # response on first access.
      #   end
      def model
        return model_class_override if model_class_override
        return Adapters::Http::ModelProxy.new(self) if adapter_class == :http

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
      # Actions appear on the show page. They execute arbitrary code when triggered.
      # An action with form_fields opens its form first: the show page links to it,
      # the form posts to the action, and the action does not run while a required
      # field is blank.
      #
      # @param name [Symbol] The action name
      # @param form_fields [Array<IronAdmin::ActionField, Hash>] Inputs of the action's form
      # @param options [Hash] Configuration options
      # @option options [String] :icon Heroicon name (e.g., "lock-closed", "trash")
      # @option options [Boolean] :confirm Whether to show a confirmation dialog (on the form's
      #   submit when the action has form_fields)
      # @option options [String] :confirm_message Custom confirmation message
      # @option options [Symbol] :method HTTP method (:post, :patch, :delete)
      # @yield [record, params] Block executed when action is triggered
      # @yieldparam record [ActiveRecord::Base] The record to act upon
      # @yieldparam params [Hash{Symbol => String}] The form's values (two-argument blocks only)
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
      def action(name, form_fields: [], **options, &block)
        coerced = coerce_action_fields(form_fields)
        self.defined_actions = defined_actions + [{ name: name, block: block, form_fields: coerced, **options }]
      end

      # Defines a bulk action for multiple selected records.
      #
      # Bulk actions appear in the bulk actions bar when records
      # are selected on the index page. All records are processed in
      # a single database transaction. A bulk action with form_fields
      # takes the selection to its form, which posts to the action.
      #
      # @param name [Symbol] The action name
      # @param form_fields [Array<IronAdmin::ActionField, Hash>] Inputs of the action's form
      # @param options [Hash] Configuration options
      # @option options [String] :icon Heroicon name
      # @option options [Boolean] :confirm Whether to show a confirmation dialog (on the form's
      #   submit when the action has form_fields)
      # @option options [String] :confirm_message Custom confirmation message
      # @yield [records, params] Block executed when action is triggered
      # @yieldparam records [ActiveRecord::Relation] The selected records
      # @yieldparam params [Hash{Symbol => String}] The form's values (two-argument blocks only)
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
      def bulk_action(name, form_fields: [], **options, &block)
        coerced = coerce_action_fields(form_fields)
        self.defined_bulk_actions = defined_bulk_actions + [{ name: name, block: block, form_fields: coerced, **options }]
      end

      # Convenience constructor for ActionField instances.
      #
      # @param name [Symbol] The field name
      # @param opts [Hash] Options passed to ActionField.new
      # @return [IronAdmin::ActionField]
      #
      # @example
      #   action :suspend,
      #     form_fields: [
      #       action_field(:reason, type: :textarea, required: true),
      #       action_field(:notify, type: :boolean)
      #     ] do |record, params|
      #     # ...
      #   end
      def action_field(name, **)
        ActionField.new(name: name, **)
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
      # @option options [String] :group Group name for the sidebar section
      #   (sibling resources sharing the same `:group` are listed together;
      #   resources without a `:group` fall under "Resources"). `:section`
      #   is also accepted as an alias for `:group` for backward
      #   compatibility with earlier docs.
      #
      # @example
      #   menu icon: "users", label: "Team Members", priority: 10, group: "People"
      #
      # @return [void]
      def menu(**options)
        if options.key?(:section)
          legacy = options.delete(:section)
          # Preserve `:group` precedence based on key presence so that
          # explicitly passing `group: nil` (or `group: false`) still
          # wins over `section:`. Using `||=` would clobber falsey
          # explicit values.
          options[:group] = legacy unless options.key?(:group)
        end
        self.menu_options = options
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
        self.denied_crud_actions = actions.map { |action| Policy.canonical_action(action) }.uniq
      end

      # Checks if a CRUD action is allowed (not denied via deny_actions).
      #
      # Controller names such as :delete, :index, and :new are compared
      # against their canonical CRUD action.
      #
      # @param action_name [Symbol] The action to check
      # @return [Boolean] True if the action is allowed
      def action_allowed?(action_name)
        denied_crud_actions.exclude?(Policy.canonical_action(action_name))
      end

      # Checks deny_actions and the resource policy together.
      #
      # @param action [Symbol] CRUD or controller action name
      # @param user [Object, nil] Current user passed to policy conditions
      # @return [Boolean]
      def crud_allowed?(action, user)
        return false unless action_allowed?(action)

        policy = resource_policy
        return true unless policy

        policy.allowed?(action, user)
      end

      # Searchable columns the user is allowed to see. Secret fields
      # ({Field::SECRET_TYPES}) are left out, even when {.searchable} lists them.
      #
      # @param user [Object, nil]
      # @return [Array<Symbol>]
      def visible_searchable_columns(user)
        visible_names = resolved_fields.select { |field| field.visible?(user) && !field.secret? }.map(&:name)
        searchable_columns.select { |column| visible_names.include?(column.to_sym) }
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
      # By default, exports include all visible fields except :password and
      # :hidden ones. A :hidden field listed here exports its value; a
      # :password field listed here exports as "[FILTERED]".
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
      # has_many and has_one are defined in Concerns::Nestable

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

          resource = resolve_association_resource(config, reflection)
          next unless resource

          { name: assoc_name, reflection: reflection, resource: resource, **config.except(:kind, :resource) }
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

          resource = resolve_association_resource(config, reflection)
          next unless resource

          { name: assoc_name, reflection: reflection, resource: resource, **config.except(:kind, :resource) }
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

          resource = resolve_association_resource(config, reflection)

          { name: assoc_name, reflection: reflection, resource: resource, **config.except(:kind, :resource) }
        end
      end

      # Returns the URL segment for this resource.
      #
      # A resource whose model is the one its class name implies
      # (`UserResource` → `User`, `Billing::InvoiceResource` →
      # `Billing::Invoice`) uses the model's plural, so those names and URLs
      # stay. A {.model_class_override} of that same model is the same case,
      # including when the model has a custom `model_name`. A
      # {.model_class_override} of a different model, an overridden
      # `self.model`, or a class name that implies no model derives the
      # segment from the full class path under `IronAdmin::Resources`
      # (`AutoNoteResource` is "auto_notes", `Shop::NoteResource` is
      # "shop_notes", `Archive::NoteResource` is "archive_notes"). An HTTP
      # adapter resource without an override keeps the adapter's name.
      # An anonymous class, which has no name to derive from, uses the model's
      # plural. A subclass that defines `self.resource_name` keeps that name.
      # There is no writer.
      #
      # @example Choose a name
      #   module IronAdmin
      #     module Resources
      #       class ArchivedNoteResource < IronAdmin::Resource
      #         self.model_class_override = ::Note
      #         def self.resource_name = "archived_notes"
      #       end
      #     end
      #   end
      #
      # @return [String] The resource name (e.g., "users", "auto_notes", "shop_notes")
      def resource_name
        return adapter.resource_name if uses_model_resource_name?

        class_derived_resource_name
      end

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

      private

      # True when the segment is the model's plural rather than the class path.
      def uses_model_resource_name?
        return true if name.nil?
        return true if adapter_class == :http && !model_class_override && !model_method_overridden?
        return false if (model_class_override && model_class_override != implied_model_class) || model_method_overridden?

        !implied_model_class.nil?
      end

      def model_method_overridden?
        method(:model).owner != IronAdmin::Resource.singleton_class
      end

      # The constant named by this resource class, or nil when there is none.
      def implied_model_class
        name.sub(/Resource\z/, "").sub(/\AIronAdmin::Resources::/, "").constantize
      rescue NameError
        nil
      end

      def class_derived_resource_name
        name.delete_prefix("IronAdmin::Resources::").delete_suffix("Resource").underscore.tr("/", "_").pluralize
      end

      # Resolves the adapter class from a symbol or class.
      # Symbols are resolved via the Adapters::Registry (lazy loading).
      # Classes are used directly (for custom adapters).
      def resolve_adapter_class
        return adapter_class unless adapter_class.is_a?(Symbol)

        Adapters::Registry.resolve(adapter_class)
      end

      # Resolves the resource class for an association configuration.
      # Accepts Class, String, or falls back to ResourceRegistry lookup.
      def resolve_association_resource(config, reflection)
        resource = config[:resource]
        return resource.constantize if resource.is_a?(String)
        return resource if resource

        ResourceRegistry.find(reflection.klass.model_name.plural)
      end

      def coerce_action_fields(fields)
        Array(fields).map do |f|
          f.is_a?(ActionField) ? f : ActionField.new(**f)
        end
      end

      # @api private
      def infer_preload_associations
        resolved_fields.select { |f| f.type == :belongs_to }.map(&:name)
      end
    end
  end
end
