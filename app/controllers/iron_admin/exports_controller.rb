# frozen_string_literal: true

module IronAdmin
  # Controller for exporting resource data to CSV and JSON formats.
  #
  # Exports respect field visibility settings and tenant scoping. Secret
  # fields (:password and :hidden) are left out unless export_fields lists
  # them; a listed :password field is masked, a listed :hidden one is not.
  # Access via /admin/:resource_name/export.csv or .json
  #
  # @see IronAdmin::Resource#exports
  # @see IronAdmin::Resource#export_fields
  class ExportsController < ApplicationController
    include Concerns::Filterable
    include Concerns::Scopeable
    include Concerns::Searchable

    # What a listed :password field exports instead of its value.
    FILTERED_VALUE = "[FILTERED]"

    before_action :set_resource_class
    before_action :ensure_read_allowed
    before_action :ensure_format_enabled

    # Exports resource data in the requested format.
    #
    # @return [void] Sends CSV file or renders JSON
    def show
      records = collection_scope
      fields = export_fields

      respond_to do |format|
        format.csv do
          csv_data = generate_csv(records, fields)
          send_data csv_data,
                    filename: "#{@resource_class.resource_name}_#{Date.current}.csv",
                    type: "text/csv"
        end

        format.json do
          data = records.map { |r| fields.each_with_object({}) { |f, h| h[f.name] = safe_field_value(r, f, :json) } }
          render json: data
        end
      end
    end

    private

    def set_resource_class
      @resource_class = ResourceRegistry.find(params[:resource_name])
      render_not_found unless @resource_class
    end

    def ensure_read_allowed
      return if performed? || @resource_class.nil?

      render_forbidden unless @resource_class.crud_allowed?(:read, iron_admin_current_user)
    end

    # Formats left out of the resource's `exports` call are not served.
    def ensure_format_enabled
      return if performed?

      render_not_found unless @resource_class.export_formats.map(&:to_sym).include?(request.format.symbol)
    end

    def adapter
      @resource_class.adapter
    end

    def export_fields
      fields = if @resource_class.export_field_names
                 fields_by_name = @resource_class.resolved_fields.index_by(&:name)
                 @resource_class.export_field_names.filter_map { |name| fields_by_name[name.to_sym] }
               else
                 @resource_class.resolved_fields.reject(&:secret?)
               end

      # Security: Filter out fields not visible to the current user
      fields.select { |f| f.visible?(iron_admin_current_user) }
    end

    def generate_csv(records, fields)
      require "csv"
      CSV.generate do |csv|
        csv << fields.map { |f| f.name.to_s.humanize }
        adapter.find_each(records) do |record|
          csv << fields.map { |f| safe_field_value(record, f, :csv) }
        end
      end
    end

    def safe_field_value(record, field, format)
      return "[Error: field not found]" unless record.respond_to?(field.name)
      return FILTERED_VALUE if field.type == :password

      value = record.public_send(field.name)
      formatted = format_for_export(value, field, format)
      format == :csv ? neutralize_csv_formula(formatted) : formatted
    rescue StandardError => e
      "[Error: #{e.message}]"
    end

    def neutralize_csv_formula(value)
      text = value.to_s
      return text unless text.match?(/\A[=+\-@\t\r]/)

      "'#{text}"
    end

    def format_for_export(value, field, format)
      return "" if value.nil?
      return format_attachment(value, format) if value.respond_to?(:attached?)
      return value if format == :json && value.is_a?(Hash)
      return value if format == :json && value.is_a?(Array)

      case field.type
      when :datetime, :date then value.iso8601
      when :boolean then value ? "Yes" : "No"
      when :belongs_to then format_belongs_to(value, field)
      else value.to_s
      end
    end

    # ActiveStorage proxies are never nil and would otherwise export their inspect string.
    def format_attachment(value, format)
      filenames = attachment_filenames(value)
      return filenames.first.to_s unless value.is_a?(ActiveStorage::Attached::Many)

      format == :json ? filenames : filenames.join(", ")
    end

    def attachment_filenames(value)
      return [] unless value.attached?

      attachments = value.is_a?(ActiveStorage::Attached::Many) ? value.attachments : [value]
      attachments.map { |attachment| attachment.filename.to_s }
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
