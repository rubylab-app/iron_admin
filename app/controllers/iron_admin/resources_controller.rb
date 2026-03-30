# frozen_string_literal: true

require "ostruct"

module IronAdmin
  # Main controller handling CRUD operations for all admin resources.
  #
  # This controller dynamically handles requests for any registered resource,
  # providing index, show, new, create, edit, update, and destroy actions.
  # It also handles custom actions, bulk actions, and autocomplete.
  #
  # Routes are structured as:
  # - GET    /admin/:resource_name          -> index
  # - GET    /admin/:resource_name/new      -> new
  # - POST   /admin/:resource_name          -> create
  # - GET    /admin/:resource_name/:id      -> show
  # - GET    /admin/:resource_name/:id/edit -> edit
  # - PATCH  /admin/:resource_name/:id      -> update
  # - DELETE /admin/:resource_name/:id      -> destroy
  #
  # @see IronAdmin::Resource
  class ResourcesController < ApplicationController
    include Concerns::Searchable

    before_action :set_resource_class
    before_action :check_action_allowed, only: %i[show new create edit update destroy]

    # Lists all records for the resource with filtering, sorting, and pagination.
    #
    # @return [void]
    def index
      scope = apply_scopes(apply_filters(base_scope))
      scope = apply_search(scope)
      scope = apply_sorting(scope)
      scope = apply_preloading(scope)

      @pagy, @records = pagy(scope, limit: IronAdmin.configuration.per_page)
      @fields = index_fields
      @current_scope = current_scope_name
    end

    # Shows a single record.
    #
    # @return [void]
    # @raise [ActiveRecord::RecordNotFound] if record doesn't exist
    def show
      @record = record_scope.find(params[:id])
      @fields = @resource_class.resolved_fields
    end

    # Renders the new record form.
    #
    # @return [void]
    def new
      @record = adapter.build
      @fields = form_fields
    end

    # Renders the edit form for an existing record.
    #
    # @return [void]
    # @raise [ActiveRecord::RecordNotFound] if record doesn't exist
    def edit
      @record = record_scope.find(params[:id])
      @fields = form_fields
    end

    # Creates a new record.
    #
    # @return [void]
    def create
      @record = adapter.build(resource_params)

      if adapter.save(@record)
        emit_event(:create, @record)
        redirect_to resource_path(@resource_class.resource_name, @record),
                    notice: I18n.t("iron_admin.resources.create.success", model: adapter.human_name)
      else
        @fields = form_fields
        render :new, status: :unprocessable_content
      end
    end

    # Updates an existing record.
    #
    # @return [void]
    # @raise [ActiveRecord::RecordNotFound] if record doesn't exist
    def update
      @record = record_scope.find(params[:id])
      purge_attachments(@record)

      if adapter.update(@record, resource_params)
        emit_event(:update, @record)
        redirect_to resource_path(@resource_class.resource_name, @record),
                    notice: I18n.t("iron_admin.resources.update.success", model: adapter.human_name)
      else
        @fields = form_fields
        render :edit, status: :unprocessable_content
      end
    end

    # Deletes a record.
    #
    # @return [void]
    # @raise [ActiveRecord::RecordNotFound] if record doesn't exist
    def destroy
      @record = record_scope.find(params[:id])
      adapter.destroy!(@record)
      emit_event(:destroy, @record)
      redirect_to resources_path(@resource_class.resource_name),
                  notice: I18n.t("iron_admin.resources.destroy.success", model: adapter.human_name)
    end

    # Executes a custom action on a single record.
    #
    # @return [void]
    def execute_action
      action = @resource_class.defined_actions.find { |a| a[:name].to_s == params[:action_name] }
      return head(:not_found) unless action
      return head(:forbidden) unless action_authorized?(action[:name])

      @record = record_scope.find(params[:id])

      adapter.transaction do
        result = action[:block].call(@record)
        emit_event(params[:action_name], @record)
        raise ActiveRecord::Rollback if result == false
      end

      redirect_to resource_path(@resource_class.resource_name, @record),
                  notice: I18n.t("iron_admin.resources.action.success")
    rescue ActiveRecord::RecordNotFound
      head(:not_found)
    rescue StandardError => e
      redirect_to resources_path(@resource_class.resource_name),
                  alert: I18n.t("iron_admin.resources.action.failure", error: e.message)
    end

    # Executes a bulk action on multiple selected records.
    #
    # All records are processed within a database transaction.
    # If the action block returns false, the transaction is rolled back.
    #
    # @return [void]
    def execute_bulk_action
      ids = bulk_action_ids
      return redirect_bulk(:alert, I18n.t("iron_admin.resources.bulk_action.no_records")) if ids.empty?

      records = adapter.filter(base_scope, :id, ids)
      action = find_bulk_action

      return head(:not_found) unless action
      return head(:forbidden) unless action_authorized?(action[:name])
      unless all_records_accessible?(records, ids)
        return redirect_bulk(:alert, I18n.t("iron_admin.resources.bulk_action.inaccessible"))
      end

      run_bulk_action_in_transaction(action, records)
      redirect_bulk(:notice, I18n.t("iron_admin.resources.bulk_action.success"))
    rescue StandardError => e
      redirect_bulk(:alert, I18n.t("iron_admin.resources.bulk_action.failure", error: e.message))
    end

    # Returns autocomplete results for belongs_to fields.
    #
    # @return [void] Renders JSON array of {id, label} objects
    def autocomplete
      query = params[:q].to_s.strip
      return render json: [] if query.blank?

      display = @resource_class.display_attribute
      scope = adapter.search_column(base_scope, display, query)
      records = adapter.limit(scope, 20)
        .map { |r| { id: r.id, label: r.public_send(display) } }

      render json: records
    end

    private

    def adapter
      @resource_class.adapter
    end

    def base_scope
      scope = adapter.all
      scope = IronAdmin.configuration.tenant_scope_block.call(scope) if IronAdmin.configuration.tenant_scope_block
      scope
    end

    def record_scope
      scope = base_scope
      scope = adapter.unscope_column(scope, @resource_class.soft_delete_column) if @resource_class.soft_delete?
      scope
    end

    def set_resource_class
      @resource_class = ResourceRegistry.find(params[:resource_name])
      head(:not_found) and return unless @resource_class
    end

    def resource_policy
      @resource_class.resource_policy
    end

    def check_action_allowed
      crud_action = case action_name.to_sym
                    when :show then :read
                    when :new, :create then :create
                    when :edit, :update then :update
                    when :destroy then :destroy
                    end

      # Check global action permissions (deny_actions DSL)
      head(:forbidden) and return unless @resource_class.action_allowed?(crud_action)

      # Check policy-based authorization if a policy is defined
      return unless resource_policy

      head(:forbidden) and return unless resource_policy.allowed?(crud_action, iron_admin_current_user)
    end

    def action_authorized?(action_name)
      return true unless resource_policy

      resource_policy.action_allowed?(action_name, iron_admin_current_user)
    end

    def bulk_action_ids
      Array(params[:ids]).map(&:to_i).reject(&:zero?)
    end

    def find_bulk_action
      @resource_class.defined_bulk_actions.find { |a| a[:name].to_s == params[:action_name] }
    end

    def all_records_accessible?(records, ids)
      records.count == ids.size
    end

    def redirect_bulk(type, message)
      redirect_to resources_path(@resource_class.resource_name), type => message
    end

    def run_bulk_action_in_transaction(action, records)
      adapter.transaction do
        result = action[:block].call(records)
        raise ActiveRecord::Rollback if result == false
      end
    end

    def index_fields
      base_fields = if @resource_class.index_field_names
                      fields_by_name = @resource_class.resolved_fields.index_by(&:name)
                      @resource_class.index_field_names.filter_map { |name| fields_by_name[name] }
                    else
                      @resource_class.resolved_fields
                    end

      base_fields.select { |f| f.visible?(iron_admin_current_user) }
    end

    def form_fields
      base_fields = if @resource_class.form_field_names
                      @resource_class.resolved_fields.select { |f| f.name.in?(@resource_class.form_field_names) }
                    else
                      @resource_class.resolved_fields.reject { |f| f.name.in?(%i[id created_at updated_at]) }
                    end

      base_fields.select { |f| f.visible?(iron_admin_current_user) }
    end

    def purge_attachments(record)
      form_fields.select { |f| f.type == :file }.each do |field|
        next unless params.dig(:record, :"#{field.name}_purge") == "1" && record.respond_to?(field.name)

        record.public_send(field.name).then { |a| a.purge if a.attached? }
      end
    end

    def resource_params
      permitted = form_fields.flat_map do |field|
        case field.type
        when :belongs_to then field.options[:foreign_key]
        when :polymorphic_belongs_to then [field.options[:type_column], field.options[:id_column]]
        when :files then { field.name => [] }
        else field.name
        end
      end

      @resource_class.habtm_associations.each { |a| permitted << { "#{a[:name].to_s.singularize}_ids": [] } }
      params.require(:record).permit(*permitted) # rubocop:disable Rails/StrongParametersExpect
    end

    def apply_filters(scope)
      @resource_class.all_filters.each do |filter|
        if filter[:type] == :date_range
          from = params.dig(:filters, "#{filter[:name]}_from")
          to = params.dig(:filters, "#{filter[:name]}_to")
          scope = scope.where(filter[:name] => parse_date(from)..) if from.present? && parse_date(from)
          scope = scope.where(filter[:name] => ..parse_date(to)&.end_of_day) if to.present? && parse_date(to)
          next
        end

        value = params.dig(:filters, filter[:name])
        next if value.blank?
        next unless value.is_a?(String)

        value = ActiveModel::Type::Boolean.new.cast(value) if filter[:type] == :boolean

        scope = if filter[:scope]
                  filter[:scope].call(value, scope)
                else
                  adapter.filter(scope, filter[:name], value)
                end
      end
      scope
    end

    def parse_date(value)
      return nil if value.blank?

      Date.parse(value)
    rescue ArgumentError, TypeError
      nil
    end

    def current_scope_name
      scope_name = params[:scope]
      defined_scope = @resource_class.all_scopes.find { |s| s[:name].to_s == scope_name }
      defined_scope ||= @resource_class.all_scopes.find { |s| s[:default] }
      defined_scope&.dig(:name)&.to_s
    end

    def apply_scopes(scope)
      defined_scope = @resource_class.all_scopes.find { |s| s[:name].to_s == params[:scope] }
      defined_scope ||= @resource_class.all_scopes.find { |s| s[:default] }

      return scope unless defined_scope

      scope.merge(defined_scope[:scope])
    end

    def apply_sorting(scope)
      sort_col = params[:sort].to_s
      sort_col = IronAdmin.configuration.default_sort.to_s unless adapter.has_column?(sort_col)
      valid_dir = %w[asc desc].include?(params[:direction].to_s.downcase)
      sort_dir = valid_dir ? params[:direction] : IronAdmin.configuration.default_sort_direction
      adapter.order_by(scope, sort_col, sort_dir)
    end

    def apply_preloading(scope)
      preloads = @resource_class.preload_associations
      preloads.any? ? adapter.preload(scope, preloads) : scope
    end

    def emit_event(action, record)
      event = OpenStruct.new(
        user: iron_admin_current_user,
        action: action,
        resource: @resource_class.name,
        record_id: record.id,
        changes: record.saved_changes,
        ip_address: request.remote_ip
      )

      # Log to audit log if enabled
      IronAdmin::AuditLog.log(event)

      # Call on_action callback if configured
      IronAdmin.configuration.on_action_block&.call(event)
    end
  end
end
