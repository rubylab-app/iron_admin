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
    include Concerns::ActionExecutable
    include Concerns::Filterable
    include Concerns::JsonParamsCoercion
    include Concerns::NestedPermittable
    include Concerns::Scopeable
    include Concerns::Searchable

    before_action :set_resource_class
    before_action :check_action_allowed, only: %i[show new create edit update destroy]

    # Lists all records for the resource with filtering, sorting, and pagination.
    #
    # @return [void]
    def index
      @pagy, @records = pagy(collection_scope, limit: IronAdmin.configuration.per_page)
      @fields = index_fields
      @current_scope = current_scope_name
    end

    # Shows a single record.
    #
    # @return [void]
    # @raise [IronAdmin::RecordNotFound] if record doesn't exist
    def show
      @record = find_record(record_scope, params[:id])
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
    # @raise [IronAdmin::RecordNotFound] if record doesn't exist
    def edit
      @record = find_record(record_scope, params[:id])
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
    # @raise [IronAdmin::RecordNotFound] if record doesn't exist
    def update
      @record = find_record(record_scope, params[:id])
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
    # @raise [IronAdmin::RecordNotFound] if record doesn't exist
    def destroy
      @record = find_record(record_scope, params[:id])
      adapter.destroy!(@record)
      emit_event(:destroy, @record)
      redirect_to resources_path(@resource_class.resource_name),
                  notice: I18n.t("iron_admin.resources.destroy.success", model: adapter.human_name)
    end

    # Renders the action form for a single record action with form_fields.
    #
    # @return [void]
    def action_form
      @action = find_single_record_action
      return unless @action

      return unless prepare_action_record?(@action)

      @form_fields = @action[:form_fields]
      @form_url = resource_action_path(@resource_class.resource_name, @record, @action[:name])
    end

    # Renders the action form for a bulk action with form_fields.
    #
    # @return [void]
    def bulk_action_form
      action = find_bulk_action
      return head(:not_found) unless action
      return head(:forbidden) unless action_authorized?(action[:name])

      @action = action
      @form_fields = action[:form_fields]
      @form_url = resource_bulk_action_path(@resource_class.resource_name, action[:name])
    end

    # Executes a custom action on a single record.
    #
    # @return [void]
    def execute_action
      action = find_single_record_action
      return unless action

      return unless prepare_action_record?(action)

      collected = action_form_params(action)

      adapter.transaction do
        adapter.wrap_rollback do
          result = call_action_block(action[:block], @record, collected)
          emit_event(params[:action_name], @record)
          raise IronAdmin::Rollback if result == false
        end
      end

      redirect_to resource_path(@resource_class.resource_name, @record),
                  notice: I18n.t("iron_admin.resources.action.success")
    rescue IronAdmin::RecordNotFound
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
      display = searchable_display_attribute unless adapter.has_column?(display)
      return render json: [] unless display

      scope = adapter.search_column(base_scope, display, query)
      records = adapter.limit(scope, 20)
        .map { |record| { id: record.to_param.to_s, label: record.public_send(display).to_s } }

      render json: records
    end

    private

    def adapter
      @resource_class.adapter
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
      Array(params[:ids]).compact_blank
    end

    def find_single_record_action
      action = @resource_class.defined_actions.find { |defined| defined[:name].to_s == params[:action_name] }
      unless action
        head(:not_found)
        return nil
      end
      unless action_authorized?(action[:name])
        head(:forbidden)
        return nil
      end

      action
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
      collected = action_form_params(action)
      adapter.transaction do
        adapter.wrap_rollback do
          result = call_action_block(action[:block], records, collected)
          raise IronAdmin::Rollback if result == false
        end
      end
    end

    def searchable_display_attribute
      @resource_class.searchable_columns.find { |column| adapter.has_column?(column) }
    end

    def action_condition_met?(action, record)
      condition = action[:condition]
      return true unless condition

      condition.call(record)
    end

    def prepare_action_record?(action)
      @record = find_record(record_scope, params[:id])
      return true if action_condition_met?(action, @record)

      head(:forbidden)
      false
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
        next unless iron_admin_param_dig(params[:record], :"#{field.name}_purge") == "1" && record.respond_to?(field.name)

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

      @resource_class.nested_associations.each do |nested|
        permitted << { "#{nested.name}_attributes": build_nested_permit_list(nested) }
      end

      record_params = params.require(:record)
      raise ActionController::ParameterMissing, :record unless record_params.respond_to?(:permit)

      parsed = record_params.permit(*permitted)
      coerce_json_field_params!(parsed)
      parsed
    end

    def emit_event(action, record)
      event = OpenStruct.new(
        user: iron_admin_current_user,
        action: action,
        resource: @resource_class.name,
        record_id: record.id.to_s,
        changes: adapter.record_changes(record),
        ip_address: request.remote_ip
      )

      # Log to audit log if enabled
      IronAdmin::AuditLog.log(event)

      # Call on_action callback if configured
      IronAdmin.configuration.on_action_block&.call(event)
    end
  end
end
