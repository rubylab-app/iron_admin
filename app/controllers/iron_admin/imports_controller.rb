# frozen_string_literal: true

require "ostruct"

module IronAdmin
  class ImportsController < ApplicationController
    before_action :set_resource_class
    before_action :ensure_import_enabled
    before_action :ensure_create_allowed

    def new
      @formats = @resource_class.import_formats
      @fields = @resource_class.importable_fields(iron_admin_current_user)
    end

    def preview
      return redirect_missing_file unless uploaded_file

      @preview = importer.preview
      @resource_name = @resource_class.resource_name
      render :preview, formats: :html
    rescue StandardError => e
      redirect_to resource_import_path(@resource_class.resource_name), alert: e.message
    end

    def create
      return redirect_missing_file unless uploaded_file

      result = importer.execute!
      redirect_to resources_path(@resource_class.resource_name),
                  notice: I18n.t(
                    "iron_admin.imports.create.success",
                    created: result.created_count,
                    updated: result.updated_count,
                    failed: result.failed_count
                  )
    rescue StandardError => e
      redirect_to resource_import_path(@resource_class.resource_name), alert: e.message
    end

    private

    def set_resource_class
      @resource_class = ResourceRegistry.find(params[:resource_name])
      head(:not_found) and return unless @resource_class
    end

    def ensure_import_enabled
      head(:not_found) and return unless @resource_class&.import_enabled?
    end

    def ensure_create_allowed
      head(:forbidden) and return unless @resource_class.action_allowed?(:create)
    end

    def uploaded_file
      params[:file]
    end

    def importer
      Import::Importer.new(@resource_class, file: uploaded_file, format: import_format, context: import_context)
    end

    def import_format
      params[:import_format].presence || params[:format].presence || uploaded_file_extension
    end

    def uploaded_file_extension
      filename = uploaded_file&.original_filename
      return unless filename

      filename.split(".").last
    end

    def import_context
      OpenStruct.new(current_user: iron_admin_current_user, controller: self)
    end

    def redirect_missing_file
      redirect_to resource_import_path(@resource_class.resource_name), alert: I18n.t("iron_admin.imports.errors.missing_file")
    end
  end
end
