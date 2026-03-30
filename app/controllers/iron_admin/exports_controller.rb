# frozen_string_literal: true

module IronAdmin
  # Controller for exporting resource data to CSV and JSON formats.
  #
  # Exports respect field visibility settings and tenant scoping.
  # Access via /admin/:resource_name/export.csv or .json
  #
  # @see IronAdmin::Resource#exports
  # @see IronAdmin::Resource#export_fields
  class ExportsController < ApplicationController
    before_action :set_resource_class

    # Exports resource data in the requested format.
    #
    # @return [void] Sends CSV file or renders JSON
    def show
      records = base_scope
      fields = export_fields

      respond_to do |format|
        format.csv do
          csv_data = generate_csv(records, fields)
          send_data csv_data,
                    filename: "#{@resource_class.resource_name}_#{Date.current}.csv",
                    type: "text/csv"
        end

        format.json do
          data = records.map { |r| fields.each_with_object({}) { |f, h| h[f.name] = safe_field_value(r, f) } }
          render json: data
        end
      end
    end

    private

    def set_resource_class
      @resource_class = ResourceRegistry.find(params[:resource_name])
      head(:not_found) and return unless @resource_class
    end

    def adapter
      @resource_class.adapter
    end

    def base_scope
      scope = adapter.all
      scope = IronAdmin.configuration.tenant_scope_block.call(scope) if IronAdmin.configuration.tenant_scope_block
      scope
    end

    def export_fields
      fields = if @resource_class.export_field_names
                 @resource_class.resolved_fields.select { |f| f.name.in?(@resource_class.export_field_names) }
               else
                 @resource_class.resolved_fields
               end

      # Security: Filter out fields not visible to the current user
      fields.select { |f| f.visible?(iron_admin_current_user) }
    end

    def generate_csv(records, fields)
      require "csv"
      CSV.generate do |csv|
        csv << fields.map { |f| f.name.to_s.humanize }
        adapter.find_each(records) do |record|
          csv << fields.map { |f| safe_field_value(record, f) }
        end
      end
    end

    def safe_field_value(record, field)
      return "[Error: field not found]" unless record.respond_to?(field.name)

      value = record.public_send(field.name)
      format_for_export(value, field)
    rescue StandardError => e
      "[Error: #{e.message}]"
    end

    def format_for_export(value, field)
      return "" if value.nil?

      case field.type
      when :datetime, :date then value.iso8601
      when :boolean then value ? "Yes" : "No"
      when :belongs_to then format_belongs_to(value, field)
      else value.to_s
      end
    end

    def format_belongs_to(associated_record, field)
      return "" if associated_record.nil?

      display_method = field.options[:display]
      if display_method
        associated_record.public_send(display_method).to_s
      else
        display_label_for(associated_record)
      end
    end

    def display_label_for(record)
      %i[name title email label slug].each do |method|
        return record.public_send(method).to_s if record.respond_to?(method) && record.public_send(method).present?
      end
      "#{record.class.model_name.human} ##{record.id}"
    end
  end
end
